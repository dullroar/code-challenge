;;;; DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
;;;; XDG_DATA_HOME. Nothing here touches a real time-reporting system.
;;;;
;;;; Run:  sbcl --script timecards.lisp
;;;;
;;;; The challenge: add cards of 10-19 hours until the running total passes 40.
;;;;
;;;; THE STUNT.  There is no loop and no conditional anywhere below the line
;;;; marked RUN TIME.  Each card is a METHOD of the generic function PUNCH, and
;;;; the cards are chained through the class precedence list:
;;;;
;;;;     card-1 -> card-2 -> card-3 -> card-4 -> card-5 -> ledger
;;;;
;;;; PUNCH uses the built-in OR method combination.  Calling it on a CARD-1
;;;; instance runs the applicable methods most-specific-first, which is card 1,
;;;; then card 2, and so on, and stops at the first method that returns true.
;;;; Each method deals one card and answers "is the total over 40 now?".  The
;;;; class hierarchy is the loop counter, and OR's short-circuit is the stop rule.

(defpackage #:timecards-weird
  (:use #:cl))

(in-package #:timecards-weird)

;;; ------------------------------------------------------------------ compile time
;;; Macros run while the file is being compiled, so the loops in them never
;;; touch a timecard.  Everything they produce is straight-line code.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun card-class (number)
    "The name of the class that stands for card NUMBER: CARD-1, CARD-2, ..."
    (intern (format nil "CARD-~D" number))))

(defmacro defcard (number next)
  "Define card NUMBER: a class that inherits from NEXT (the card after it) and
a PUNCH method, qualified with OR, specialized on that class."
  `(progn
     (defclass ,(card-class number) (,next) ())
     (defmethod punch or ((ledger ,(card-class number)))
       (deal ledger ,number))))

;;; ------------------------------------------------------------------ the state

(defparameter *week*
  '#1=("Meetings" "Coding" "Debugging" "Learning" . #1#)
  "The categories as a circular list, written with the reader's #1= / #1# syntax.
(NTH 4 *WEEK*) is \"Meetings\" again, so no MOD is needed to make them repeat.")

(defvar *sql* nil
  "While PUNCH runs, the stream that collects the SQL script (a dynamic binding).")

(defclass ledger ()
  ((total :initform 0 :accessor total)
   (entries :initform 0 :accessor entries)
   (state :initform (make-random-state t) :reader state)
   (run-id :initarg :run-id :reader run-id)
   (week :initarg :week :reader week))
  (:documentation "The running state of one run: the end of the card chain."))

(defgeneric punch (ledger)
  (:method-combination or)
  (:documentation "Deal cards until one pushes the total over 40."))

;;; ------------------------------------------------------------------ RUN TIME
;;; From here on nothing iterates and nothing branches.

(defun sql-quote (text)
  "A string literal. No escaping: every value is a number or a fixed word we chose."
  (format nil "'~A'" text))

(defun deal (ledger number)
  "Deal card NUMBER: write its row and its INSERT; true once the total is over 40."
  (let ((hours (+ 10 (random 10 (state ledger))))
        (category (nth (1- number) *week*)))
    (incf (entries ledger))
    (incf (total ledger) hours)                     ; an accessor is a SETF place
    (format *sql* "INSERT INTO demo_timecards~
                   (run_id,category,hours,running_total,iso_week,created_at) ~
                   VALUES(~A,~A,~D,~D,~A,datetime('now'));~%"
            (sql-quote (run-id ledger)) (sql-quote category) hours
            (total ledger) (sql-quote (week ledger)))
    (format t "~A~C~D~C~D~C~A~CDEMO ONLY~%"
            category #\Tab hours #\Tab (total ledger) #\Tab (week ledger) #\Tab)
    (> (total ledger) 40)))

;;; Tail first: a class must exist before another can inherit from it.
(defcard 5 ledger)
(defcard 4 card-5)
(defcard 3 card-4)
(defcard 2 card-3)
(defcard 1 card-2)

(defmethod punch :around ((ledger ledger))
  "Wrap the whole chain in one SQLite transaction: BEGIN, the cards, COMMIT."
  (let ((*sql* (make-string-output-stream)))
    (format *sql* "BEGIN;~%CREATE TABLE IF NOT EXISTS demo_timecards(~
                   id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,~
                   running_total INTEGER,iso_week TEXT,created_at TEXT,~
                   demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));~%")
    (prog1 (call-next-method)
      (format *sql* "COMMIT;~%")
      (assert (zerop (sb-ext:process-exit-code
                      (sb-ext:run-program "sqlite3" (list (database-path))
                                          :search t :output nil :error *error-output*
                                          :input (make-string-input-stream
                                                  (get-output-stream-string *sql*)))))
              () "sqlite3 reported an error"))))

(defun database-path ()
  (let ((directory (format nil "~A/LispWeird/"
                           (or (sb-ext:posix-getenv "XDG_DATA_HOME")
                               (format nil "~A/.local/share"
                                       (sb-ext:posix-getenv "HOME"))))))
    (ensure-directories-exist directory)
    (format nil "~Ademo-timecards.db" directory)))

(defun unix-time ()
  (- (get-universal-time) (encode-universal-time 0 0 0 1 1 1970 0)))

(defun date-week ()
  (string-trim '(#\Newline)
               (with-output-to-string (text)
                 (sb-ext:run-program "date" '("+%G-W%V") :search t :output text))))

(let* ((ledger (make-instance 'card-1
                              :week (date-week)
                              :run-id (format nil "~D-~36R" (unix-time)
                                              (random (expt 36 6) (make-random-state t)))))
       (chain (sb-mop:compute-applicable-methods #'punch (list ledger))))
  (format t "# DEMO ONLY run ~A~%" (run-id ledger))
  (punch ledger)
  (format t "# committed total=~D entries=~D DEMO ONLY~%" (total ledger) (entries ledger))
  (format t "# PUNCH had ~D OR methods and ~D ran: the class precedence list ~
             is the loop, and OR is the stop rule~%"
          (count '(or) chain :key #'method-qualifiers :test #'equal) (entries ledger)))
