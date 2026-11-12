//! Browser history commands (NAV-03): local, searchable, clearable. Clearing
//! it never touches downloads, the library or favorites.

use storage::Visit;
use tauri::State;

use crate::commands::CommandError;
use crate::state::AppState;

/// Longest search accepted.
const QUERY_MAX: usize = 200;

/// Newest first; `query` matches the title or the address.
#[tauri::command]
pub fn browser_history(
    state: State<'_, AppState>,
    query: String,
    limit: Option<u32>,
) -> Result<Vec<Visit>, CommandError> {
    let query: String = query.chars().take(QUERY_MAX).collect();
    Ok(state
        .storage()
        .visits(&query, limit.unwrap_or(storage::VISITS_PAGE_MAX))?)
}

#[tauri::command]
pub fn browser_history_delete(state: State<'_, AppState>, id: i64) -> Result<(), CommandError> {
    Ok(state.storage().delete_visit(id)?)
}

/// Returns how many visits were removed.
#[tauri::command]
pub fn browser_history_clear(state: State<'_, AppState>) -> Result<usize, CommandError> {
    Ok(state.storage().clear_visits()?)
}
