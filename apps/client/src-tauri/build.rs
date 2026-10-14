/// Application commands. Each one must be granted explicitly in
/// `capabilities/default.json` (least privilege).
const COMMANDS: &[&str] = &[
    "validate_media_url",
    "analyze_link",
    "downloads_list",
    "downloads_start",
    "downloads_pause",
    "downloads_resume",
    "downloads_cancel",
    "downloads_retry",
    "downloads_start_now",
    "downloads_move",
    "downloads_pause_all",
    "downloads_resume_all",
    "downloads_reveal",
    "history_list",
    "history_clear",
    "history_reveal",
    "settings_get",
    "settings_set_concurrency",
    "settings_set_resource_mode",
    "settings_pick_download_dir",
    "components_status",
    "components_install",
];

fn main() {
    tauri_build::try_build(
        tauri_build::Attributes::new()
            .app_manifest(tauri_build::AppManifest::new().commands(COMMANDS)),
    )
    .expect("failed to run tauri-build");
}
