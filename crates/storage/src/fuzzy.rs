//! Typo-tolerant search (2026-11-28, decision 0013 proposal 6): when the
//! full-text index finds little, the library's titles, artists and albums
//! are compared word by word with an edit distance, so « Njakatina » still
//! finds « NJAKATIANA » and « marre haute » finds « Marée haute ».

use crate::{MediaRecord, Result, Storage};

/// Lower case, accents removed, only letters and digits kept as words.
pub fn fold_words(text: &str) -> Vec<String> {
    let mut words = Vec::new();
    let mut word = String::new();
    for c in text.chars() {
        let folded = fold_char(c);
        match folded {
            Some(f) => word.push(f),
            None if c.is_alphanumeric() => word.extend(c.to_lowercase()),
            None => {
                if !word.is_empty() {
                    words.push(std::mem::take(&mut word));
                }
            }
        }
    }
    if !word.is_empty() {
        words.push(word);
    }
    words
}

fn fold_char(c: char) -> Option<char> {
    Some(match c {
        'a'..='z' | '0'..='9' => c,
        'A'..='Z' => c.to_ascii_lowercase(),
        'à' | 'â' | 'ä' | 'á' | 'ã' | 'å' | 'À' | 'Â' | 'Ä' | 'Á' | 'Ã' | 'Å' => 'a',
        'ç' | 'Ç' => 'c',
        'é' | 'è' | 'ê' | 'ë' | 'É' | 'È' | 'Ê' | 'Ë' => 'e',
        'î' | 'ï' | 'í' | 'ì' | 'Î' | 'Ï' | 'Í' | 'Ì' => 'i',
        'ô' | 'ö' | 'ó' | 'ò' | 'õ' | 'Ô' | 'Ö' | 'Ó' | 'Ò' | 'Õ' => 'o',
        'ù' | 'û' | 'ü' | 'ú' | 'Ù' | 'Û' | 'Ü' | 'Ú' => 'u',
        'ñ' | 'Ñ' => 'n',
        'ÿ' | 'ý' | 'Ý' => 'y',
        _ => return None,
    })
}

/// Edits allowed for a typed word of this length: none under 3 letters,
/// one up to 5, two beyond.
fn allowed(len: usize) -> usize {
    match len {
        0..=2 => 0,
        3..=5 => 1,
        _ => 2,
    }
}

/// Optimal string alignment distance (insert, delete, replace, swap two
/// neighbours), stopping early past `max`.
pub fn distance(a: &[char], b: &[char], max: usize) -> Option<usize> {
    if a.len().abs_diff(b.len()) > max {
        return None;
    }
    let (n, m) = (a.len(), b.len());
    let mut prev2 = vec![0usize; m + 1];
    let mut prev: Vec<usize> = (0..=m).collect();
    let mut cur = vec![0usize; m + 1];
    for i in 1..=n {
        cur[0] = i;
        let mut row_min = cur[0];
        for j in 1..=m {
            let cost = usize::from(a[i - 1] != b[j - 1]);
            let mut v = (prev[j] + 1).min(cur[j - 1] + 1).min(prev[j - 1] + cost);
            if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] {
                v = v.min(prev2[j - 2] + 1);
            }
            cur[j] = v;
            row_min = row_min.min(v);
        }
        if row_min > max {
            return None;
        }
        std::mem::swap(&mut prev2, &mut prev);
        std::mem::swap(&mut prev, &mut cur);
    }
    (prev[m] <= max).then_some(prev[m])
}

/// How far a typed word is from one of `words`: exact or prefix 0, else
/// the edit distance to the word, or to its start (a word still being
/// typed); None when too far.
fn word_cost(typed: &[char], words: &[Vec<char>]) -> Option<usize> {
    let max = allowed(typed.len());
    let mut best: Option<usize> = None;
    for w in words {
        if w.starts_with(typed) {
            return Some(0);
        }
        let whole = distance(typed, w, max);
        let start = (w.len() > typed.len())
            .then(|| distance(typed, &w[..typed.len()], max))
            .flatten()
            .map(|d| d + 1);
        for d in [whole, start].into_iter().flatten() {
            best = Some(best.map_or(d, |b| b.min(d)));
        }
    }
    best
}

/// Total cost of `query` against an entry's words, when every typed word
/// is close to one of them.
pub fn match_cost(query: &[Vec<char>], words: &[Vec<char>]) -> Option<usize> {
    let mut total = 0;
    for typed in query {
        total += word_cost(typed, words)?;
    }
    Some(total)
}

impl Storage {
    /// Entries (missing files excluded) whose title, artist or album is
    /// close to `query` despite typos, the closest first, at most `limit`.
    pub fn fuzzy_media(&self, query: &str, limit: usize) -> Result<Vec<MediaRecord>> {
        let typed: Vec<Vec<char>> = fold_words(query)
            .into_iter()
            .take(8)
            .map(|w| w.chars().collect())
            .collect();
        if typed.is_empty() || limit == 0 {
            return Ok(Vec::new());
        }
        let mut stmt = self.conn.prepare(
            "SELECT id, title, coalesce(artist, ''), coalesce(album, '') \
             FROM media WHERE missing = 0",
        )?;
        let rows = stmt.query_map([], |r| {
            Ok((
                r.get::<_, i64>(0)?,
                r.get::<_, String>(1)?,
                r.get::<_, String>(2)?,
                r.get::<_, String>(3)?,
            ))
        })?;
        let mut found: Vec<(usize, String, i64)> = Vec::new();
        for row in rows {
            let (id, title, artist, album) = row?;
            let words: Vec<Vec<char>> = fold_words(&format!("{title} {artist} {album}"))
                .into_iter()
                .map(|w| w.chars().collect())
                .collect();
            if let Some(cost) = match_cost(&typed, &words) {
                found.push((cost, title.to_lowercase(), id));
            }
        }
        found.sort();
        found
            .into_iter()
            .take(limit)
            .map(|(_, _, id)| self.media(id))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn chars(s: &str) -> Vec<char> {
        s.chars().collect()
    }

    fn words(s: &str) -> Vec<Vec<char>> {
        fold_words(s)
            .into_iter()
            .map(|w| w.chars().collect())
            .collect()
    }

    #[test]
    fn folds_accents_and_splits_words() {
        assert_eq!(fold_words("Marée haute — ÉTÉ!"), ["maree", "haute", "ete"]);
        assert_eq!(fold_words("NJAKATIANA"), ["njakatiana"]);
    }

    #[test]
    fn distance_counts_edits_and_swaps() {
        assert_eq!(distance(&chars("maree"), &chars("maree"), 2), Some(0));
        assert_eq!(distance(&chars("marre"), &chars("maree"), 2), Some(1));
        assert_eq!(distance(&chars("mraee"), &chars("maree"), 2), Some(1));
        assert_eq!(
            distance(&chars("njakatina"), &chars("njakatiana"), 2),
            Some(1)
        );
        assert_eq!(distance(&chars("abc"), &chars("xyz"), 1), None);
    }

    #[test]
    fn every_typed_word_must_be_close() {
        let entry = words("Marée haute Nafy Rakoto Rivages");
        assert_eq!(match_cost(&words("marre haute"), &entry), Some(1));
        assert_eq!(match_cost(&words("rakto"), &entry), Some(1));
        // A word still being typed, with a typo.
        assert!(match_cost(&words("rivga"), &entry).is_some());
        assert_eq!(match_cost(&words("marre zzzz"), &entry), None);
        // Short words must be exact (or a prefix).
        assert_eq!(match_cost(&words("ha"), &entry), Some(0));
        assert_eq!(match_cost(&words("hx"), &entry), None);
    }
}
