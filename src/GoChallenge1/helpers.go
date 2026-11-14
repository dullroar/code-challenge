package main

import (
	"database/sql"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

// DemoTimeCard is the entity. Every card is flagged as demo data.
type DemoTimeCard struct {
	ID       int64
	Category string
	Hours    float64
	UserID   string
	Year     int
	Week     int
	IsDemo   bool
}

// DemoTimeCardRepository is the data access type: SaveAll inserts the cards that have no ID yet.
type DemoTimeCardRepository struct {
	db *sql.DB
}

func OpenRepository(path string) (*DemoTimeCardRepository, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS time_cards (
		id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT, hours REAL,
		user_id TEXT, year INTEGER, week INTEGER, is_demo INTEGER)`)
	return &DemoTimeCardRepository{db: db}, err
}

// SaveAll is invoked by name through reflect, so it must stay exported.
func (r *DemoTimeCardRepository) SaveAll(cards *[]*DemoTimeCard) {
	for _, card := range *cards {
		if card.ID == 0 {
			result := Must(r.db.Exec(
				`INSERT INTO time_cards (category, hours, user_id, year, week, is_demo) VALUES (?, ?, ?, ?, ?, ?)`,
				card.Category, card.Hours, card.UserID, card.Year, card.Week, card.IsDemo))
			card.ID = Must(result.LastInsertId())
		}
	}
}

// The helpers below exist because Go has no statements inside expressions. Each returns a value
// so it can sit in an argument list, where calls run left to right.

// Seq runs its arguments, which have already been evaluated in order, and reports true.
func Seq(_ ...bool) bool { return true }

// After yields result once its arguments have been evaluated, left to right.
func After(result bool, _ ...bool) bool { return result }

func Must[T any](value T, err error) T {
	if err != nil {
		panic(err)
	}
	return value
}

func Lock(m *sync.Mutex) bool   { m.Lock(); return true }
func Unlock(m *sync.Mutex) bool { m.Unlock(); return true }

func Append[T any](items *[]T, item T) bool { *items = append(*items, item); return true }

// Pop removes and returns the first element.
func Pop[T any](items *[]T) T {
	first := (*items)[0]
	*items = (*items)[1:]
	return first
}

func Last[T any](items *[]T) T { return (*items)[len(*items)-1] }

func Sum(values []float64) float64 {
	total := 0.0
	for _, v := range values {
		total += v
	}
	return total
}

func ISOWeek(t time.Time) int {
	_, week := t.ISOWeek()
	return week
}

var saves sync.WaitGroup

// Spawn starts the function in a goroutine and tracks it, as a non-daemon thread would be.
func Spawn(f func()) bool {
	saves.Add(1)
	go func() {
		defer saves.Done()
		f()
	}()
	return true
}

func WaitForSaves() bool { saves.Wait(); return true }

// CallByName is the reflection stand-in: it finds a method by name and invokes it.
func CallByName(target any, method string, args ...any) bool {
	values := make([]reflect.Value, len(args))
	for n, arg := range args {
		values[n] = reflect.ValueOf(arg)
	}
	reflect.ValueOf(target).MethodByName(method).Call(values)
	return true
}

// ShowDialog serves the page on a loopback port, opens it in the default browser and blocks until
// the page reports it was closed, as a modal dialog (or Application.Run) would.
func ShowDialog(page string) bool {
	listener := Must(net.Listen("tcp", "127.0.0.1:0"))
	closed := make(chan struct{})
	var once sync.Once
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = io.WriteString(w, page)
	})
	mux.HandleFunc("/closed", func(w http.ResponseWriter, r *http.Request) {
		once.Do(func() { close(closed) })
	})
	server := &http.Server{Handler: mux}
	go func() { _ = server.Serve(listener) }()

	url := "http://" + listener.Addr().String() + "/"
	fmt.Println("Demo window (close the tab or press Close to finish):", url)
	openBrowser(url)
	<-closed
	_ = server.Close()
	return true
}

func openBrowser(url string) {
	switch runtime.GOOS {
	case "windows":
		_ = exec.Command("rundll32", "url.dll,FileProtocolHandler", url).Start()
	case "darwin":
		_ = exec.Command("open", url).Start()
	default:
		_ = exec.Command("xdg-open", url).Start()
	}
}
