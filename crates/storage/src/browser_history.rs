//! Built-in browser history (CDC NAV-03): the pages visited, on this device
//! only. Clearing it never touches downloads, the library or favorites.

use rusqlite::{OptionalExtension, params};
use serde::Serialize;

use crate::{Result, Storage, now_ms};

/// Visits kept at most: the oldest go first.
pub const VISITS_MAX: usize = 10_000;
/// Longest URL and title stored (page data, untrusted).
pub const VISIT_URL_MAX: usize = 2048;
pub const VISIT_TITLE_MAX: usize = 300;
/// Coming back to the same page within this delay updates the last visit
/// instead of adding one (reloads, back and forth).
const SAME_VISIT_MS: i64 = 30 * 60 * 1000;
/// Rows returned by one search.
pub const VISITS_PAGE_MAX: u32 = 500;

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Visit {
    pub id: i64,
    pub url: String,
    pub title: String,
    pub visited_at: i64,
}

fn clean_title(title: &str) -> String {
    title
        .trim()
        .chars()
        .filter(|c| !c.is_control())
        .take(VISIT_TITLE_MAX)
        .collect()
}

impl Storage {
    /// Notes a visit to `url` (http(s) pages only; checked by the caller).
    /// Returns `None` when the URL is too long to be kept.
    pub fn note_visit(&self, url: &str, title: &str) -> Result<Option<i64>> {
        if url.is_empty() || url.len() > VISIT_URL_MAX {
            return Ok(None);
        }
        let now = now_ms();
        let title = clean_title(title);
        let last: Option<(i64, String, i64)> = self
            .conn
            .query_row(
                "SELECT id, url, visited_at FROM browser_history \
                 ORDER BY visited_at DESC, id DESC LIMIT 1",
                [],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )
            .optional()?;
        if let Some((id, last_url, at)) = last
            && last_url == url
            && now - at < SAME_VISIT_MS
        {
            self.conn.execute(
                "UPDATE browser_history SET visited_at = ?2, \
                 title = CASE WHEN ?3 = '' THEN title ELSE ?3 END WHERE id = ?1",
                params![id, now, title],
            )?;
            return Ok(Some(id));
        }
        self.conn.execute(
            "INSERT INTO browser_history (url, title, visited_at) VALUES (?1, ?2, ?3)",
            params![url, title, now],
        )?;
        let id = self.conn.last_insert_rowid();
        self.conn.execute(
            "DELETE FROM browser_history WHERE id NOT IN \
             (SELECT id FROM browser_history ORDER BY visited_at DESC, id DESC LIMIT ?1)",
            [VISITS_MAX as i64],
        )?;
        Ok(Some(id))
    }

    /// The page title arrives after the visit: set it on the latest visit
    /// of that URL.
    pub fn set_visit_title(&self, url: &str, title: &str) -> Result<()> {
        let title = clean_title(title);
        if title.is_empty() {
            return Ok(());
        }
        self.conn.execute(
            "UPDATE browser_history SET title = ?2 WHERE id = \
             (SELECT id FROM browser_history WHERE url = ?1 \
              ORDER BY visited_at DESC, id DESC LIMIT 1)",
            params![url, title],
        )?;
        Ok(())
    }

    /// Newest first; `query` matches the title or the address.
    pub fn visits(&self, query: &str, limit: u32) -> Result<Vec<Visit>> {
        let pattern = format!(
            "%{}%",
            query
                .trim()
                .replace('\\', "\\\\")
                .replace('%', "\\%")
                .replace('_', "\\_")
        );
        let mut stmt = self.conn.prepare(
            "SELECT id, url, title, visited_at FROM browser_history \
             WHERE title LIKE ?1 ESCAPE '\\' OR url LIKE ?1 ESCAPE '\\' \
             ORDER BY visited_at DESC, id DESC LIMIT ?2",
        )?;
        let rows = stmt.query_map(params![pattern, limit.min(VISITS_PAGE_MAX)], |r| {
            Ok(Visit {
                id: r.get(0)?,
                url: r.get(1)?,
                title: r.get(2)?,
                visited_at: r.get(3)?,
            })
        })?;
        Ok(rows.collect::<std::result::Result<_, _>>()?)
    }

    pub fn delete_visit(&self, id: i64) -> Result<()> {
        self.conn
            .execute("DELETE FROM browser_history WHERE id = ?1", [id])?;
        Ok(())
    }

    /// Returns how many visits were removed.
    pub fn clear_visits(&self) -> Result<usize> {
        Ok(self.conn.execute("DELETE FROM browser_history", [])?)
    }
}

#[cfg(test)]
mod tests {
    use crate::Storage;

    #[test]
    fn visits_are_kept_searched_and_cleared() {
        let s = Storage::open_in_memory().unwrap();
        s.note_visit("https://commons.wikimedia.org/wiki/Sintel", "Sintel")
            .unwrap();
        s.note_visit("https://archive.org/details/concerts", "")
            .unwrap();
        s.set_visit_title("https://archive.org/details/concerts", "Concerts\u{7}")
            .unwrap();
        // Coming back at once updates the same visit.
        s.note_visit("https://archive.org/details/concerts", "")
            .unwrap();
        let all = s.visits("", 50).unwrap();
        assert_eq!(all.len(), 2);
        assert_eq!(all[0].title, "Concerts", "control characters dropped");

        assert_eq!(s.visits("sintel", 50).unwrap().len(), 1);
        assert_eq!(s.visits("archive.org", 50).unwrap().len(), 1);
        assert!(s.visits("100%", 50).unwrap().is_empty(), "% is literal");

        s.delete_visit(all[0].id).unwrap();
        assert_eq!(s.visits("", 50).unwrap().len(), 1);
        assert_eq!(s.clear_visits().unwrap(), 1);
        assert!(s.visits("", 50).unwrap().is_empty());
    }

    #[test]
    fn overlong_urls_are_not_kept() {
        let s = Storage::open_in_memory().unwrap();
        let url = format!("https://example.org/{}", "a".repeat(3000));
        assert_eq!(s.note_visit(&url, "x").unwrap(), None);
        assert!(s.visits("", 10).unwrap().is_empty());
    }
}
