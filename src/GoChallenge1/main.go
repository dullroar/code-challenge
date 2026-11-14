// A Go port of Jim Lehmer's 2008 C# 3.0 "one statement" challenge.
//
// Same objective as the Java, Kotlin and Python versions in this repository: a small desktop-style
// program whose main contains exactly one statement, a `for` statement with an empty body.
//
// Go is the strictest of the four. A `for` clause allows only simple statements, and Go has no
// ternary operator, no comma expression and no statements inside expressions. So:
//
//   - The initializer declares one variable holding a pointer to an anonymous struct, the
//     counterpart of the C# anonymous object and the Java anonymous class.
//   - The condition is a boolean expression. `a && b || After(false, ...)` plays the part of the
//     ternary: when the loop should end, the window is shown first and the result is false.
//   - The post statement is a single call whose arguments run in order, left to right. Go
//     evaluates function calls in argument lists in lexical order, so Seq(...) stands in for the
//     comma list.
//   - Everything with a statement inside it (Lock, Append, ShowDialog and so on) is a small
//     value-returning helper in helpers.go, because Go cannot put a statement in an expression.
//     That file is the cost of the Go version.
//
// Substitutions from the other versions:
//   - modernc.org/sqlite (pure Go, no C compiler) rather than Spring Data JPA or sqlite3.
//   - The "window" is a page served on a loopback port and opened in the default browser, because
//     Go has no standard-library GUI. The pulse is a CSS animation fragment, as the Java version
//     had a Swing timer bean and the C# version a DoubleAnimation.
//   - reflect rather than Spring's ReflectionUtils or MethodInfo.Invoke.
//
// The program only writes clearly identified *demo* time cards to data/demo-timecards.db in the
// working directory. It is not connected to, and must not be used for, a real time-reporting system.
package main

import (
	"cmp"
	"fmt"
	"math/rand/v2"
	"os"
	"path/filepath"
	"sync"
	"time"
)

func main() {
	for i := &struct {
		// The CSS fragment is deliberately gratuitous: it becomes part of the page below, as the
		// XElement became part of the XAML in the C# version.
		animCSS    string
		hours      []float64
		user       string
		repo       *DemoTimeCardRepository
		pending    []*DemoTimeCard
		categories []string
		mu         sync.Mutex
	}{
		animCSS: `<style>
  @keyframes pulse { from { opacity: 1 } to { opacity: .45 } }
  h1, h2, h3 { animation: pulse 1.2s ease-in-out infinite alternate }
</style>`,
		user:       cmp.Or(os.Getenv("USERNAME"), os.Getenv("USER")),
		repo:       Must(OpenRepository(filepath.Join("data", "demo-timecards.db"))),
		categories: []string{"Meetings", "Coding", "Debugging", "Learning"},
	}; //   *
	//  *
	// **************** FIRST SEMICOLON ****************
	//  *
	//   *
	// While the hours total 40 or less and a category remains, continue. Otherwise show the
	// window, wait for it to close, wait for the saves to land, and report false.
	Sum(i.hours) <= 40 && len(i.categories) > 0 ||
		After(false,
			ShowDialog(fmt.Sprintf(`<!doctype html>
<meta charset="utf-8">
<title>Only One STATEMENT (Go demo)</title>
%s
<body style="background:#172033;color:#fff;font-family:sans-serif;text-align:center;padding:48px">
  <h2 style="color:#FFCE56">DEMO ONLY - no real time system is involved</h2>
  <h1>Total simulated hours: %.1f</h1>
  <h3>Saved locally for the modernization exercise.</h3>
  <button onclick="done()">Close</button>
</body>
<script>
  function done() {
    navigator.sendBeacon('/closed');
    document.body.innerHTML = '<h2>Done - you can close this tab.</h2>';
  }
  addEventListener('pagehide', () => navigator.sendBeacon('/closed'));
</script>
`, i.animCSS, Sum(i.hours))),
			WaitForSaves()); //   *
	//  *
	// **************** LAST SEMICOLON ****************
	//  *
	//   *
	// Each pass locks, adds 10 to 19 random hours, stages a card, unlocks, and starts a
	// background goroutine that saves the staged cards, calling SaveAll through reflection.
	Seq(
		Lock(&i.mu),
		Append(&i.hours, float64(10+rand.IntN(10))),
		Append(&i.pending, &DemoTimeCard{
			Category: Pop(&i.categories),
			Hours:    Last(&i.hours),
			UserID:   i.user,
			Year:     time.Now().Year(),
			Week:     ISOWeek(time.Now()),
			IsDemo:   true,
		}),
		Unlock(&i.mu),
		Spawn(func() {
			Seq(
				Lock(&i.mu),
				CallByName(i.repo, "SaveAll", &i.pending),
				Unlock(&i.mu))
		}),
	) {
		// Intentionally empty.
	}
}
