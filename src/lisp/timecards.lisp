;;;; DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
;;;; XDG_DATA_HOME. Nothing here touches a real time-reporting system.
;;;;
;;;; Run:  sbcl --script timecards.lisp [YYYY-MM-DD]
;;;;
;;;; The challenge: add cards of 10-19 hours (Meetings, Coding, Debugging,
;;;; Learning, round and round) until the running total passes 40.  In Common
;;;; Lisp that is one LOOP form, DRAW-CARDS.  Everything else is small
;;;; functions that each do one thing.  The optional date argument pins the ISO
;;;; week, which is what lets the calendar arithmetic be tested.

(defpackage #:timecards
  (:use #:cl)
  (:export #:main))

(in-package #:timecards)

;;; ------------------------------------------------------------------ rules

(defparameter *categories* #("Meetings" "Coding" "Debugging" "Learning")
  "Card categories, in the order they repeat.")

(defconstant +min-hours+ 10)
(defconstant +max-hours+ 19)
(defconstant +limit+ 40
  "Stop as soon as the running total is greater than this.")

(defstruct (card (:constructor make-card (number category hours running-total)))
  "One fictional timecard entry."
  (number 1 :type (integer 1))
  (category "" :type string)
  (hours +min-hours+ :type (integer #.+min-hours+ #.+max-hours+))
  (running-total +min-hours+ :type (integer #.+min-hours+)))

(defun category-for (number)
  "The category of card NUMBER (counting from 1): the four names repeat."
  (aref *categories* (mod (1- number) (length *categories*))))

(defun draw-cards (state)
  "Draw cards until the running total passes the limit; return them in order.
The card that crosses the line is kept, which is why UNTIL comes after COLLECT."
  (loop for number from 1
        for hours = (+ +min-hours+ (random (1+ (- +max-hours+ +min-hours+)) state))
        sum hours into total
        collect (make-card number (category-for number) hours total)
        until (> total +limit+)))

;;; ------------------------------------------------------------------ the calendar

(defun weeks-in-year (year)
  "52 or 53: a year has 53 ISO weeks when it starts or ends on a Thursday."
  (flet ((p (y) (mod (+ y (floor y 4) (- (floor y 100)) (floor y 400)) 7)))
    (if (or (= (p year) 4) (= (p (1- year)) 3)) 53 52)))

(defun days-before-month (month year)
  "Days from January 1 of YEAR up to the first of MONTH."
  (let ((leap (and (zerop (mod year 4))
                   (or (plusp (mod year 100)) (zerop (mod year 400))))))
    (reduce #'+ (subseq (if leap
                            #(31 29 31 30 31 30 31 31 30 31 30 31)
                            #(31 28 31 30 31 30 31 31 30 31 30 31))
                        0 (1- month)))))

(defun iso-week (universal-time)
  "The ISO-8601 week of UNIVERSAL-TIME as text such as \"2026-W46\".
Week 1 is the week containing the year's first Thursday, so the first days of
January can belong to the previous year's last week and vice versa."
  (multiple-value-bind (second minute hour day month year day-of-week)
      (decode-universal-time universal-time)
    (declare (ignore second minute hour))
    (let* ((ordinal (+ day (days-before-month month year)))
           (week (floor (+ (- ordinal (1+ day-of-week)) 10) 7)))
      (cond ((< week 1)
             (format nil "~D-W~2,'0D" (1- year) (weeks-in-year (1- year))))
            ((> week (weeks-in-year year))
             (format nil "~D-W01" (1+ year)))
            (t (format nil "~D-W~2,'0D" year week))))))

(defun parse-date (text)
  "Universal time for the date TEXT, \"YYYY-MM-DD\"; noon, so the zone cannot matter."
  (destructuring-bind (year month day)
      (mapcar #'parse-integer
              (loop for start = 0 then (1+ end)
                    for end = (position #\- text :start start)
                    collect (subseq text start end)
                    while end))
    (encode-universal-time 0 0 12 day month year)))

;;; ------------------------------------------------------------------ SQLite

(defun sql-quote (text)
  "TEXT as an SQL string literal: doubling the quotes is the whole rule."
  (with-output-to-string (out)
    (write-char #\' out)
    (loop for char across text
          do (when (char= char #\') (write-char #\' out))
             (write-char char out))
    (write-char #\' out)))

(defparameter *schema*
  "CREATE TABLE IF NOT EXISTS demo_timecards(
  id INTEGER PRIMARY KEY, run_id TEXT, category TEXT, hours INTEGER,
  running_total INTEGER, iso_week TEXT, created_at TEXT,
  demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));"
  "The DEMO ONLY rule lives in the table: a non-demo row cannot be stored.")

(defun sql-script (run-id week cards)
  "One transaction: the schema, then an INSERT per card."
  (with-output-to-string (sql)
    (format sql "BEGIN;~%~A~%" *schema*)
    (dolist (card cards)
      (format sql "INSERT INTO demo_timecards~
                   (run_id,category,hours,running_total,iso_week,created_at) ~
                   VALUES(~A,~A,~D,~D,~A,datetime('now'));~%"
              (sql-quote run-id) (sql-quote (card-category card))
              (card-hours card) (card-running-total card) (sql-quote week)))
    (format sql "COMMIT;~%")))

(defun xdg-data-home ()
  (or (sb-ext:posix-getenv "XDG_DATA_HOME")
      (format nil "~A/.local/share" (sb-ext:posix-getenv "HOME"))))

(defun database-path ()
  "Where the scratch database lives; the directory is created if it is missing."
  (let ((directory (sb-ext:parse-native-namestring
                    (format nil "~A/Lisp/" (xdg-data-home))
                    nil *default-pathname-defaults* :as-directory t)))
    (ensure-directories-exist directory)
    (sb-ext:native-namestring (merge-pathnames "demo-timecards.db" directory))))

(defun run-sqlite (database script)
  "Feed SCRIPT to the sqlite3 command line tool; signal an error if it complains."
  (let ((process (sb-ext:run-program "sqlite3" (list database)
                                     :search t
                                     :input (make-string-input-stream script)
                                     :output nil
                                     :error *error-output*)))
    (unless (zerop (sb-ext:process-exit-code process))
      (error "sqlite3 failed with exit code ~D" (sb-ext:process-exit-code process)))))

;;; ------------------------------------------------------------------ display

(defun print-card (card week stream)
  "One tab-separated row: category, hours, running total, ISO week, the marker."
  (format stream "~A~C~D~C~D~C~A~CDEMO ONLY~%"
          (card-category card) #\Tab (card-hours card) #\Tab
          (card-running-total card) #\Tab week #\Tab))

;;; ------------------------------------------------------------------ main

(defun unix-time ()
  (- (get-universal-time) (encode-universal-time 0 0 0 1 1 1970 0)))

(defun main (&optional date)
  (let* ((state (make-random-state t))              ; T: seed from the OS
         (week (iso-week (if date (parse-date date) (get-universal-time))))
         (run-id (format nil "~D-~36R" (unix-time) (random (expt 36 6) state)))
         (cards (draw-cards state)))
    (run-sqlite (database-path) (sql-script run-id week cards))
    (format t "# DEMO ONLY run ~A~%" run-id)
    (dolist (card cards)
      (print-card card week *standard-output*))
    (format t "# committed total=~D entries=~D DEMO ONLY~%"
            (card-running-total (car (last cards))) (length cards))
    (format t "# one LOOP form with SUM, COLLECT and UNTIL is the whole challenge~%")))

(main (second sb-ext:*posix-argv*))
