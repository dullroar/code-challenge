"""A Python port of Jim Lehmer's 2008 C# 3.0 "one statement" challenge, standard library only.

Same objective as the Java and Kotlin versions in this repository: a small desktop program whose
main() contains exactly one statement, a `for` statement. Python has no three-part `for`, no comma
expressions and no ternary-with-statements, so the pieces are mapped like this:

  - The `for` iterates `iter(step, False)`. Calling `step` again and again is the loop; the
    iterator stops when `step` returns the sentinel `False`.
  - The initializer is the state object passed to the lambda that builds `step`.
  - The condition and the update are the two branches of one conditional expression. A tuple
    evaluates several expressions in order and `[-1]` picks the result, standing in for the comma
    list. Walrus-free, statement-free, one expression.
  - The loop body is `...`, Python's closest thing to an empty body (a `pass` would be a second
    statement; `...` is only a constant expression).

Substitutions from the other versions:
  - sqlite3 and tkinter from the standard library, rather than Spring Data JPA and Swing.
  - The window is described by an XML string parsed at runtime with ElementTree, rather than by Spring
    XML bean definitions or runtime XAML. `getattr(tkinter, tag)` is the reflection.

The program only writes clearly identified *demo* time cards to data/demo-timecards.db beside this
file. It is not connected to, and must not be used for, a real time-reporting system.
"""

import datetime
import functools
import getpass
import random
import sqlite3
import threading
import time
import tkinter as tk
import xml.etree.ElementTree as ET
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from types import SimpleNamespace


@dataclass
class DemoTimeCard:
    category: str
    hours: float
    user_id: str
    year: int
    week: int
    is_demo: bool
    id: int | None = None


class DemoTimeCardRepository:
    """The data access type: creates the table, then save_all inserts cards that have no id yet."""

    def __init__(self, path: Path) -> None:
        self.path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as connection:
            connection.execute(
                "CREATE TABLE IF NOT EXISTS time_cards ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT, hours REAL, "
                "user_id TEXT, year INTEGER, week INTEGER, is_demo INTEGER)")

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self.path)

    def save_all(self, cards) -> None:
        connection = self._connect()
        try:
            with connection:
                for card in list(cards):
                    if card.id is None:
                        card.id = connection.execute(
                            "INSERT INTO time_cards (category, hours, user_id, year, week, is_demo) "
                            "VALUES (?, ?, ?, ?, ?, ?)",
                            (card.category, card.hours, card.user_id, card.year, card.week,
                             int(card.is_demo))).lastrowid
        finally:
            connection.close()


def main() -> None:
    for _ in iter(
        # The initializer: one object holds the loop's state. It is handed to the lambda that
        # builds `step`, as the for-initializer hands its variable to the condition and update.
        (lambda i: lambda:
            # The condition: while the hours total 40 or less and a category remains, continue.
            (
                # The update: lock, add 10-19 hours, stage a card, unlock, then save in a
                # background thread, via getattr as a stand-in for reflection.
                i.mutex.acquire(),
                i.total_hours.append(float(i.rnd.randint(10, 19))),
                i.pending.append(
                    DemoTimeCard(
                        i.categories.popleft(),
                        i.total_hours[-1],
                        i.user,
                        datetime.date.today().isocalendar().year,
                        datetime.date.today().isocalendar().week,
                        True)),
                i.mutex.release(),
                threading.Thread(
                    target=lambda: (
                        getattr(i.mutex, "acquire")(),
                        getattr(i.repo, "save_all")(i.pending),
                        getattr(i.mutex, "release")())).start(),
                True,
            )[-1]
            if sum(i.total_hours) <= 40 and i.categories
            # Otherwise: build the window from a runtime XML string, show it, wait for it to
            # close (mainloop blocks, as a modal dialog does) and report False to end the loop.
            else (lambda elements: (lambda widgets: (lambda win, labels, interval: (
                setattr(i, "tick", lambda: (
                    # The pulse: every label fades to 45% of its color and back, 1.2 s each way.
                    [label.configure(fg=(lambda amount, fore, back: "#%02x%02x%02x" % tuple(
                        int(b + (f - b) * amount) for f, b in zip(fore, back)))(
                            0.45 + 0.55 * abs(time.monotonic() % 2.4 / 1.2 - 1),
                            [c // 256 for c in win.winfo_rgb(base)],
                            [c // 256 for c in win.winfo_rgb(win.cget("bg"))]))
                     for label, base in labels],
                    win.after(interval, i.tick))),
                i.tick(),
                win.eval("tk::PlaceWindow . center"),
                win.mainloop(),
                False,
            )[-1])(
                widgets["window"],
                [(widgets[e.get("id")], e.get("fg")) for e in elements if e.tag == "Label"],
                int(ET.fromstring(i.xml_anim).get("interval"))))(
                    # One widget per XML element, in document order; each may name its parent.
                    functools.reduce(
                        lambda made, e: {**made, e.get("id"): (lambda w: (
                            w.configure(**{k: v for k, v in e.attrib.items()
                                           if k not in ("id", "parent", "title", "pack")}),
                            (w.title(e.get("title")), w.resizable(False, False))
                            if e.tag == "Tk" else None,
                            w.pack(**dict(pair.split("=") for pair in e.get("pack").split(",")))
                            if e.get("pack") else None,
                            w,
                        )[-1])(getattr(tk, e.tag)(*([made[e.get("parent")]] if e.get("parent") else [])))},
                        elements,
                        {})))(
                [e for e in ET.fromstring(
                    "<ui>"
                    '<Tk id="window" title="Only One STATEMENT (Python demo)" bg="#172033"/>'
                    '<Label id="banner" parent="window" text="DEMO ONLY - no real time system is involved" '
                    'fg="#FFCE56" bg="#172033" font="Helvetica 18 bold" pack="fill=x,padx=28,pady=24"/>'
                    f'<Label id="total" parent="window" text="Total simulated hours: {sum(i.total_hours):.1f}" '
                    'fg="#FFFFFF" bg="#172033" font="Helvetica 24 bold" pack="fill=x,padx=28,pady=12"/>'
                    '<Label id="saved" parent="window" text="Saved locally for the modernization exercise." '
                    'fg="#FFFFFF" bg="#172033" font="Helvetica 18 bold" pack="fill=x,padx=28,pady=24"/>'
                    + i.xml_anim +
                    "</ui>").iter() if hasattr(tk, e.tag)])
            # Still one statement. Only the time cards are saved beyond this point.
        )(SimpleNamespace(
            # The XML fragment is deliberately gratuitous: it becomes part of the window's XML.
            xml_anim='<timer interval="40"/>',
            total_hours=[],
            user=getpass.getuser(),
            repo=DemoTimeCardRepository(Path(__file__).parent / "data" / "demo-timecards.db"),
            pending=[],
            rnd=random.Random(),
            categories=deque(["Meetings", "Coding", "Debugging", "Learning"]),
            mutex=threading.RLock())),
        False):
        ...


if __name__ == "__main__":
    main()
