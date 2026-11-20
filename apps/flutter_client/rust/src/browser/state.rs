//! Tabs of the built-in browser (NAV-02), free of platform code so it is
//! tested on every host. Same rules as the Tauri app
//! (`apps/client/src-tauri/src/browser/desktop.rs`): at most `MAX_TABS`
//! open, `MAX_LIVE` with a live page (least recently used background tabs
//! go to sleep and reload when selected), open tabs saved for the next
//! start in the same setting (`browser.tabs`).

use media_core::detect::Detections;
use serde::{Deserialize, Serialize};

use crate::api::browser::{BrowserSnapshot, BrowserTab, DetectedMediaInfo};

/// Open tabs at most.
pub const MAX_TABS: usize = 12;
/// Tabs with a live page at most (memory budget).
pub const MAX_LIVE: usize = 4;
/// Open tabs, saved for the next start (shared with the Tauri app).
pub const KEY_TABS: &str = "browser.tabs";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TabKind {
    /// No page yet: the start page.
    Start,
    Web,
    /// The history and favorites tab.
    History,
}

impl TabKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Start => "start",
            Self::Web => "web",
            Self::History => "history",
        }
    }
}

pub struct Tab {
    pub id: u32,
    pub kind: TabKind,
    /// Has a page (false while asleep or never loaded).
    pub live: bool,
    pub url: String,
    pub title: String,
    pub loading: bool,
    pub can_go_back: bool,
    pub can_go_forward: bool,
    pub detections: Detections,
    /// Last time it was selected (least recently used goes to sleep).
    pub used: u64,
}

impl Tab {
    fn new(id: u32, kind: TabKind) -> Self {
        Self {
            id,
            kind,
            live: false,
            url: String::new(),
            title: String::new(),
            loading: false,
            can_go_back: false,
            can_go_forward: false,
            detections: Detections::default(),
            used: 0,
        }
    }

    pub fn reset_page(&mut self) {
        self.loading = false;
        self.can_go_back = false;
        self.can_go_forward = false;
        self.detections.clear();
    }
}

#[derive(Serialize, Deserialize)]
pub struct SavedTab {
    pub kind: TabKind,
    pub url: String,
    #[serde(default)]
    pub title: String,
}

#[derive(Serialize, Deserialize)]
pub struct SavedTabs {
    pub tabs: Vec<SavedTab>,
    pub active: usize,
}

#[derive(Default)]
pub struct Inner {
    pub tabs: Vec<Tab>,
    pub active: u32,
    next_id: u32,
    tick: u64,
    /// Page area in physical pixels of the window's client area, or `None`
    /// while the browser screen is not shown (or something covers it).
    pub frame: Option<(i32, i32, i32, i32)>,
    /// Last saved tab list (avoids rewriting the same value).
    pub saved: Option<String>,
}

impl Inner {
    pub fn active(&self) -> Option<&Tab> {
        self.tabs.iter().find(|t| t.id == self.active)
    }

    pub fn tab_mut(&mut self, id: u32) -> Option<&mut Tab> {
        self.tabs.iter_mut().find(|t| t.id == id)
    }

    pub fn add(&mut self, kind: TabKind) -> u32 {
        self.next_id += 1;
        let id = self.next_id;
        self.tabs.push(Tab::new(id, kind));
        id
    }

    /// Selects `id` and marks it used now.
    pub fn select(&mut self, id: u32) {
        self.tick += 1;
        let tick = self.tick;
        if let Some(t) = self.tab_mut(id) {
            t.used = tick;
            self.active = id;
        }
    }

    /// Live background tabs beyond the budget, least recently used first.
    pub fn to_sleep(&self) -> Vec<u32> {
        let mut live: Vec<&Tab> = self
            .tabs
            .iter()
            .filter(|t| t.live && t.id != self.active)
            .collect();
        let keep = MAX_LIVE.saturating_sub(1);
        if live.len() <= keep {
            return Vec::new();
        }
        live.sort_by_key(|t| t.used);
        live[..live.len() - keep].iter().map(|t| t.id).collect()
    }

    /// Removes a tab; another one is selected (a new start tab if it was
    /// the last).
    pub fn remove(&mut self, id: u32) {
        let Some(pos) = self.tabs.iter().position(|t| t.id == id) else {
            return;
        };
        self.tabs.remove(pos);
        if self.tabs.is_empty() {
            let start = self.add(TabKind::Start);
            self.select(start);
        } else if self.active == id {
            let next = self.tabs[pos.min(self.tabs.len() - 1)].id;
            self.select(next);
        }
    }

    /// The next (or previous) tab id, wrapping around.
    pub fn neighbour(&self, step: isize) -> Option<u32> {
        let pos = self.tabs.iter().position(|t| t.id == self.active)? as isize;
        let n = self.tabs.len() as isize;
        Some(self.tabs[((pos + step).rem_euclid(n)) as usize].id)
    }

    pub fn snapshot(&self) -> BrowserSnapshot {
        let empty = Tab::new(0, TabKind::Start);
        let tab = self.active().unwrap_or(&empty);
        BrowserSnapshot {
            kind: tab.kind.as_str().into(),
            url: tab.url.clone(),
            title: tab.title.clone(),
            loading: tab.loading,
            can_go_back: tab.can_go_back,
            can_go_forward: tab.can_go_forward,
            media: tab
                .detections
                .items()
                .iter()
                .map(|m| DetectedMediaInfo {
                    kind: serde_json::to_value(m.kind)
                        .ok()
                        .and_then(|v| v.as_str().map(str::to_owned))
                        .unwrap_or_default(),
                    url: m.url.clone(),
                    host: m.host.clone(),
                    name: m.name.clone(),
                    size_bytes: m.size_bytes,
                })
                .collect(),
            stream_player: tab.detections.stream_player,
            tabs: self
                .tabs
                .iter()
                .map(|t| BrowserTab {
                    id: t.id,
                    kind: t.kind.as_str().into(),
                    title: t.title.clone(),
                    url: t.url.clone(),
                    media: t.detections.items().len() as u32,
                    loading: t.loading,
                    active: t.id == self.active,
                })
                .collect(),
        }
    }

    pub fn saved(&self) -> SavedTabs {
        SavedTabs {
            tabs: self
                .tabs
                .iter()
                .map(|t| SavedTab {
                    kind: t.kind,
                    url: if t.kind == TabKind::Web {
                        t.url.clone()
                    } else {
                        String::new()
                    },
                    title: t.title.chars().take(300).collect(),
                })
                .collect(),
            active: self
                .tabs
                .iter()
                .position(|t| t.id == self.active)
                .unwrap_or(0),
        }
    }

    /// Tabs of the last run (web addresses only; at most `MAX_TABS`), or
    /// one start tab.
    pub fn restore(&mut self, saved: Option<SavedTabs>) {
        self.tabs.clear();
        if let Some(saved) = saved {
            for s in saved.tabs.into_iter().take(MAX_TABS) {
                let web = s.kind == TabKind::Web && super::address::is_web(&s.url);
                // A web tab whose address is not a web page reopens empty.
                let kind = match s.kind {
                    TabKind::Web if web => TabKind::Web,
                    TabKind::Web => TabKind::Start,
                    other => other,
                };
                let id = self.add(kind);
                if let Some(t) = self.tab_mut(id)
                    && web
                {
                    t.url = s.url;
                    t.title = s.title;
                }
            }
            let active = self.tabs.get(saved.active).map(|t| t.id);
            if let Some(id) = active {
                self.select(id);
            }
        }
        if self.tabs.is_empty() {
            let id = self.add(TabKind::Start);
            self.select(id);
        } else if self.active().is_none() {
            let id = self.tabs[0].id;
            self.select(id);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn saved_tabs_keep_web_addresses_only() {
        let mut s = Inner::default();
        let web = s.add(TabKind::Web);
        s.tab_mut(web).unwrap().url = "https://archive.org/details/x".into();
        let history = s.add(TabKind::History);
        s.tab_mut(history).unwrap().url = "ignored".into();
        s.select(history);
        let saved = s.saved();
        assert_eq!(saved.active, 1);
        assert_eq!(saved.tabs[0].url, "https://archive.org/details/x");
        assert_eq!(saved.tabs[1].url, "");

        // Same format as the Tauri app: restored the same way.
        let json = serde_json::to_string(&saved).unwrap();
        assert!(json.contains(r#""kind":"web""#));
        let mut back = Inner::default();
        back.restore(serde_json::from_str(&json).ok());
        assert_eq!(back.tabs.len(), 2);
        assert_eq!(back.active().unwrap().kind, TabKind::History);
    }

    #[test]
    fn a_saved_non_web_address_is_not_reopened() {
        let saved = SavedTabs {
            tabs: vec![SavedTab {
                kind: TabKind::Web,
                url: "file:///C:/secret".into(),
                title: String::new(),
            }],
            active: 0,
        };
        let mut s = Inner::default();
        s.restore(Some(saved));
        assert_eq!(s.tabs[0].kind, TabKind::Start);
        assert!(s.tabs[0].url.is_empty());
    }

    #[test]
    fn background_tabs_sleep_beyond_the_budget() {
        let mut s = Inner::default();
        let ids: Vec<u32> = (0..6).map(|_| s.add(TabKind::Web)).collect();
        for id in &ids {
            s.select(*id);
            s.tab_mut(*id).unwrap().live = true;
        }
        // The active tab plus the 3 most recent stay live.
        assert_eq!(s.to_sleep(), vec![ids[0], ids[1]]);
    }

    #[test]
    fn closing_tabs_selects_a_neighbour_or_a_new_start_tab() {
        let mut s = Inner::default();
        let a = s.add(TabKind::Web);
        let b = s.add(TabKind::Web);
        s.select(b);
        assert_eq!(s.neighbour(1), Some(a));
        s.remove(b);
        assert_eq!(s.active, a);
        s.remove(a);
        assert_eq!(s.tabs.len(), 1);
        assert_eq!(s.active().unwrap().kind, TabKind::Start);
        let snap = s.snapshot();
        assert_eq!(snap.kind, "start");
        assert!(snap.tabs[0].active);
    }
}
