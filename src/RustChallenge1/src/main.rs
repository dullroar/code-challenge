use gtk::prelude::*;
use rand::Rng;
use rust_challenge1::{database_path, save, DemoBatch};

// The rule for `main`: no `let`, no `;`, no `return`. Everything is an expression.
// (tests/one_statement.rs scans this file and fails if that ever stops being true.)
//
// Rust has no `;`-separated three-clause `for`, but `successors(first, next)` has the
// same three jobs:
//   - `first`       is the INITIALIZER.
//   - `next`        returns `None` to END the loop, which is the CONDITION...
//   - ...and         returns `Some(new state)` to continue, which is the UPDATE.
// As in the C# original, the window is launched from inside the condition.
//
// Two tricks stand in for statements:
//   - `match value { name => ... }` is a `let` that is an expression.
//   - `(a, b, c).2` is the comma operator: it evaluates a, b, c in order, yields c.
fn main() {
    for _ in std::iter::successors(
        // INITIALIZER: an immutable batch; "adding" a card produces the next batch.
        Some(DemoBatch::local()),
        |batch|
            // CONDITION + UPDATE: another card of 10-19 hours while the batch can
            // continue, otherwise save it, show it, and end the loop with `None`.
            batch
                .extended(rand::thread_rng().gen_range(10..=19))
                .or_else(|| {
                    (
                        // Persist: a scoped worker thread borrows the cards (no clone)
                        // and is joined before the window claims anything was saved.
                        match database_path().expect("neither XDG_DATA_HOME nor HOME is usable") {
                            path => std::thread::scope(|worker| {
                                worker.spawn(|| save(&path, batch.cards())).join()
                            })
                            .expect("database worker panicked")
                            .expect("could not save demo time cards"),
                        },
                        gtk::init().expect("GTK could not open a display (is WSLg running?)"),
                        match gtk::CssProvider::new() {
                            css => (
                                css.load_from_data("label { color: #f4f6fa; }"),
                                gtk::style_context_add_provider_for_display(
                                    &gtk::gdk::Display::default().expect("GTK display"),
                                    &css,
                                    gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
                                ),
                            ),
                        },
                        // Runtime UI from XML, the counterpart of XamlReader.Load.
                        match gtk::Builder::from_string(&format!(
                            r#"<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <object class="GtkWindow" id="window">
    <property name="title">Only One STATEMENT (Rust demo)</property>
    <property name="default-width">520</property><property name="default-height">320</property>
    <child><object class="GtkOverlay">
    <child><object class="GtkDrawingArea" id="shade"/></child>
    <child type="overlay"><object class="GtkBox"><property name="orientation">vertical</property>
      <property name="spacing">24</property><property name="halign">center</property><property name="valign">center</property>
      <child><object class="GtkLabel" id="banner"><property name="label">DEMO ONLY - no real time system is involved</property></object></child>
      <child><object class="GtkLabel"><property name="label">Total simulated hours: {}</property></object></child>
      <child><object class="GtkLabel"><property name="label">Saved locally for the Rust exercise.</property></object></child>
    </object></child>
  </object></child>
  </object>
</interface>"#,
                            batch.total()
                        )) {
                            builder => match (
                                builder.object::<gtk::Window>("window").expect("window in XML"),
                                builder.object::<gtk::DrawingArea>("shade").expect("shade in XML"),
                                std::time::Instant::now(),
                                gtk::glib::MainLoop::new(None, false),
                            ) {
                                (window, shade, started, event_loop) => (
                                    // Sweep a soft highlight from one edge to the other and back.
                                    // Cairo errors are ignored: this runs inside a C callback,
                                    // where a panic would abort the process.
                                    shade.set_draw_func(move |_, context, width, height| {
                                        match (width as f64, height as f64) {
                                            (w, h) => match w
                                                * (0.5
                                                    - 0.5
                                                        * (started.elapsed().as_secs_f64()
                                                            * std::f64::consts::TAU
                                                            / 8.0)
                                                            .cos())
                                            {
                                                centre => match gtk::cairo::LinearGradient::new(
                                                    centre - w * 0.65,
                                                    0.0,
                                                    centre + w * 0.65,
                                                    0.0,
                                                ) {
                                                    gradient => (
                                                        gradient.add_color_stop_rgb(0.0, 0.10, 0.13, 0.18),
                                                        gradient.add_color_stop_rgb(0.5, 0.22, 0.28, 0.36),
                                                        gradient.add_color_stop_rgb(1.0, 0.10, 0.13, 0.18),
                                                        context
                                                            .set_source(&gradient)
                                                            .and_then(|()| {
                                                                (
                                                                    context.rectangle(0.0, 0.0, w, h),
                                                                    context.fill(),
                                                                )
                                                                    .1
                                                            })
                                                            .unwrap_or_default(),
                                                    )
                                                        .3,
                                                },
                                            },
                                        }
                                    }),
                                    window.connect_close_request(match event_loop.clone() {
                                        close_loop => move |_: &gtk::Window| {
                                            (close_loop.quit(), gtk::glib::Propagation::Proceed).1
                                        },
                                    }),
                                    match gtk::glib::timeout_add_local(
                                        std::time::Duration::from_millis(40),
                                        move || (shade.queue_draw(), gtk::glib::ControlFlow::Continue).1,
                                    ) {
                                        timer => (window.present(), event_loop.run(), timer.remove()),
                                    },
                                ),
                            },
                        },
                        None,
                    )
                        .4
                }),
    ) {
        // Intentionally empty: the iterator does all the work.
    }
}
