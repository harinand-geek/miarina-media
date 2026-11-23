//! The app's Flutter window (Windows): the browser pages and the system
//! media controls are attached to it.

use windows::Win32::Foundation::{HWND, LPARAM};
use windows::Win32::System::Threading::GetCurrentProcessId;
use windows::Win32::UI::WindowsAndMessaging::{
    EnumWindows, GetClassNameW, GetWindowThreadProcessId,
};
use windows::core::BOOL;

const FLUTTER_WINDOW_CLASS: &str = "FLUTTER_RUNNER_WIN32_WINDOW";

/// The top-level Flutter window of this process.
pub fn flutter_window() -> Option<HWND> {
    unsafe extern "system" fn visit(hwnd: HWND, found: LPARAM) -> BOOL {
        let mut pid = 0;
        unsafe { GetWindowThreadProcessId(hwnd, Some(&mut pid)) };
        if pid != unsafe { GetCurrentProcessId() } {
            return true.into();
        }
        let mut class = [0u16; 64];
        let n = unsafe { GetClassNameW(hwnd, &mut class) } as usize;
        if String::from_utf16_lossy(&class[..n]) == FLUTTER_WINDOW_CLASS {
            unsafe { *(found.0 as *mut Option<HWND>) = Some(hwnd) };
            return false.into();
        }
        true.into()
    }
    let mut found: Option<HWND> = None;
    let _ = unsafe { EnumWindows(Some(visit), LPARAM(&mut found as *mut _ as isize)) };
    found
}
