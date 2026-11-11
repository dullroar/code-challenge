//! Supporting types for the deliberately eccentric one-statement demo.
//!
//! Like the C# original's `DemoTimeCardContext`, these live outside `main`; the
//! challenge constrains `main`, not the helpers it calls.
use chrono::{Datelike, Local};
use rusqlite::{params, Connection};
use std::ffi::OsString;
use std::path::{Path, PathBuf};

const CATEGORIES: [&str; 4] = ["Meetings", "Coding", "Debugging", "Learning"];
const HOURS: std::ops::RangeInclusive<i32> = 10..=19;

#[derive(Debug, Clone)]
pub struct DemoTimeCard {
    pub category: String,
    pub hours: i32,
    pub user: String,
    pub year: i32,
    pub week: u32,
    pub is_demo: bool,
}

/// An immutable batch of demo time cards.
///
/// Adding a card returns a *new* batch, which is what lets `main` drive it with
/// `std::iter::successors` (whose closure only sees `&state`) without `RefCell`.
#[derive(Debug, Clone)]
pub struct DemoBatch {
    cards: Vec<DemoTimeCard>,
    user: String,
    year: i32,
    week: u32,
}

impl DemoBatch {
    pub fn new(user: String, year: i32, week: u32) -> Self {
        Self {
            cards: Vec::new(),
            user,
            year,
            week,
        }
    }

    /// A batch for the current user and the current ISO week.
    pub fn local() -> Self {
        let now = Local::now();
        Self::new(
            user_name(std::env::var("USER").ok(), std::env::var("LOGNAME").ok()),
            now.year(),
            now.iso_week().week(),
        )
    }

    pub fn cards(&self) -> &[DemoTimeCard] {
        &self.cards
    }

    pub fn total(&self) -> i32 {
        self.cards.iter().map(|card| card.hours).sum()
    }

    /// The original's loop test: at most 40 hours so far, and categories remain.
    pub fn can_continue(&self) -> bool {
        self.total() <= 40 && self.cards.len() < CATEGORIES.len()
    }

    /// The batch with one more card for the next category, or `None` once the
    /// batch is finished. `hours` is clamped to the demo's 10-19 hour range, so
    /// no input can break the batch's invariants.
    pub fn extended(&self, hours: i32) -> Option<Self> {
        self.can_continue().then(|| Self {
            cards: self
                .cards
                .iter()
                .cloned()
                .chain(std::iter::once(DemoTimeCard {
                    category: CATEGORIES[self.cards.len()].into(),
                    hours: hours.clamp(*HOURS.start(), *HOURS.end()),
                    user: self.user.clone(),
                    year: self.year,
                    week: self.week,
                    is_demo: true,
                }))
                .collect(),
            ..self.clone()
        })
    }
}

/// `$USER`, then `$LOGNAME`, ignoring empty values; "unknown" if neither is set.
fn user_name(user: Option<String>, logname: Option<String>) -> String {
    user.filter(|name| !name.is_empty())
        .or(logname.filter(|name| !name.is_empty()))
        .unwrap_or_else(|| "unknown".into())
}

/// Where the demo database lives: the per-user XDG data directory, the Linux
/// counterpart of the original's `%LOCALAPPDATA%\ModernChallenge1`.
pub fn database_path() -> Option<PathBuf> {
    database_path_from(std::env::var_os("XDG_DATA_HOME"), std::env::var_os("HOME"))
}

fn database_path_from(xdg_data_home: Option<OsString>, home: Option<OsString>) -> Option<PathBuf> {
    xdg_data_home
        .map(PathBuf::from)
        .filter(|dir| dir.is_absolute())
        .or_else(|| {
            home.map(PathBuf::from)
                .filter(|dir| dir.is_absolute())
                .map(|dir| dir.join(".local/share"))
        })
        .map(|dir| dir.join("RustChallenge1/demo-timecards.db"))
}

/// Save the complete batch atomically; a caller decides which thread owns the connection.
pub fn save(
    path: &Path,
    cards: &[DemoTimeCard],
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if let Some(parent) = path.parent().filter(|p| !p.as_os_str().is_empty()) {
        std::fs::create_dir_all(parent)?;
    }
    let mut connection = Connection::open(path)?;
    let transaction = connection.transaction()?;
    transaction.execute_batch(
        "CREATE TABLE IF NOT EXISTS demo_timecards (
            id INTEGER PRIMARY KEY,
            category TEXT NOT NULL,
            hours INTEGER NOT NULL,
            user_id TEXT NOT NULL,
            year INTEGER NOT NULL,
            week INTEGER NOT NULL,
            is_demo INTEGER NOT NULL
        )",
    )?;
    {
        let mut insert = transaction.prepare(
            "INSERT INTO demo_timecards (category, hours, user_id, year, week, is_demo)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        )?;
        for card in cards {
            insert.execute(params![
                card.category,
                card.hours,
                card.user,
                card.year,
                card.week,
                card.is_demo
            ])?;
        }
    }
    transaction.commit()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};
    static NEXT: AtomicU64 = AtomicU64::new(0);
    fn temp_path() -> PathBuf {
        std::env::temp_dir().join(format!(
            "rust-challenge-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ))
    }
    fn batch_of(week: u32, hours: &[i32]) -> DemoBatch {
        hours
            .iter()
            .fold(DemoBatch::new("tester".into(), 2026, week), |batch, &h| {
                batch.extended(h).expect("batch should accept this card")
            })
    }
    #[test]
    fn threshold_is_inclusive_and_categories_end_the_batch() {
        assert!(batch_of(3, &[10, 10, 10]).can_continue());
        let full = batch_of(3, &[10, 10, 10, 10]);
        assert_eq!(full.total(), 40);
        assert!(!full.can_continue());
        let over = batch_of(3, &[19, 19, 19]);
        assert_eq!(over.total(), 57);
        assert!(!over.can_continue());
        assert!(batch_of(3, &[11, 10, 19]).can_continue());
        assert_eq!(batch_of(3, &[11, 10, 19, 10]).total(), 50);
    }
    #[test]
    fn extending_a_finished_batch_yields_none() {
        assert!(batch_of(3, &[10, 10, 10, 10]).extended(10).is_none());
        assert!(batch_of(3, &[19, 19, 19]).extended(10).is_none());
    }
    #[test]
    fn extending_leaves_the_original_untouched_and_clamps_hours() {
        let start = DemoBatch::new("tester".into(), 2026, 3);
        let one = start.extended(500).unwrap();
        assert!(start.cards().is_empty());
        assert_eq!(one.cards()[0].hours, 19);
        assert_eq!(one.extended(-5).unwrap().cards()[1].hours, 10);
    }
    #[test]
    fn user_name_skips_empty_values() {
        let some = |s: &str| Some(s.to_string());
        assert_eq!(user_name(some("jim"), some("other")), "jim");
        assert_eq!(user_name(some(""), some("other")), "other");
        assert_eq!(user_name(None, None), "unknown");
        assert_eq!(user_name(some(""), some("")), "unknown");
    }
    #[test]
    fn database_path_prefers_absolute_xdg_then_home() {
        let os = |s: &str| Some(OsString::from(s));
        let tail = "RustChallenge1/demo-timecards.db";
        assert_eq!(
            database_path_from(os("/xdg"), os("/home/u")),
            Some(PathBuf::from("/xdg").join(tail))
        );
        assert_eq!(
            database_path_from(os(""), os("/home/u")),
            Some(PathBuf::from("/home/u/.local/share").join(tail))
        );
        assert_eq!(
            database_path_from(os("relative"), os("/home/u")),
            Some(PathBuf::from("/home/u/.local/share").join(tail))
        );
        assert_eq!(database_path_from(None, None), None);
    }
    #[test]
    fn saves_all_fields_and_appends_batches() {
        let dir = temp_path();
        let path = dir.join("data.db");
        let batch = batch_of(53, &[10, 19]);
        save(&path, batch.cards()).unwrap();
        save(&path, batch.cards()).unwrap();
        let db = Connection::open(&path).unwrap();
        let row: (i64, i64, String, i64, i64, i64) = db
            .query_row(
                "SELECT count(*), sum(hours), min(user_id), min(year), min(week), min(is_demo)
                 FROM demo_timecards",
                [],
                |r| {
                    Ok((
                        r.get(0)?,
                        r.get(1)?,
                        r.get(2)?,
                        r.get(3)?,
                        r.get(4)?,
                        r.get(5)?,
                    ))
                },
            )
            .unwrap();
        assert_eq!(row, (4, 58, "tester".into(), 2026, 53, 1));
        let categories: String = db
            .query_row(
                "SELECT group_concat(category, ',') FROM demo_timecards WHERE id <= 2",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(categories, "Meetings,Coding");
        drop(db);
        std::fs::remove_dir_all(dir).unwrap();
    }
    #[test]
    fn reports_database_errors() {
        let dir = temp_path();
        std::fs::create_dir_all(&dir).unwrap();
        assert!(save(&dir, &[]).is_err());
        std::fs::remove_dir_all(dir).unwrap();
    }
}
