//! Child process control: no console window, optional low priority, and a
//! Windows Job Object so that cancelling kills the whole process tree
//! (yt-dlp and the FFmpeg it spawns).

use std::io;

use tokio::process::{Child, Command};

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x0800_0000;
#[cfg(windows)]
const BELOW_NORMAL_PRIORITY_CLASS: u32 = 0x0000_4000;

/// Applies platform flags to a command before spawning it.
pub fn configure(command: &mut Command, low_priority: bool) {
    command.kill_on_drop(true);
    #[cfg(windows)]
    {
        let mut flags = CREATE_NO_WINDOW;
        if low_priority {
            flags |= BELOW_NORMAL_PRIORITY_CLASS;
        }
        command.creation_flags(flags);
    }
    #[cfg(not(windows))]
    let _ = low_priority;
    #[cfg(unix)]
    command.process_group(0);
}

/// Kills every process of the job when dropped.
pub struct ProcessTree {
    #[cfg(windows)]
    job: windows_sys::Win32::Foundation::HANDLE,
    #[cfg(unix)]
    group: i32,
}

// The job handle is only used to terminate/close the job.
unsafe impl Send for ProcessTree {}
unsafe impl Sync for ProcessTree {}

impl ProcessTree {
    /// Puts `child` (and its future children) in a kill-on-close job.
    #[cfg(windows)]
    pub fn adopt(child: &Child) -> io::Result<Self> {
        use windows_sys::Win32::Foundation::CloseHandle;
        use windows_sys::Win32::System::JobObjects::{
            AssignProcessToJobObject, CreateJobObjectW, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
            JOBOBJECT_EXTENDED_LIMIT_INFORMATION, JobObjectExtendedLimitInformation,
            SetInformationJobObject,
        };

        let handle = child
            .raw_handle()
            .ok_or_else(|| io::Error::other("process already exited"))?;
        unsafe {
            let job = CreateJobObjectW(std::ptr::null(), std::ptr::null());
            if job.is_null() {
                return Err(io::Error::last_os_error());
            }
            let mut info: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = std::mem::zeroed();
            info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            let ok = SetInformationJobObject(
                job,
                JobObjectExtendedLimitInformation,
                &info as *const _ as *const _,
                std::mem::size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
            );
            if ok == 0 || AssignProcessToJobObject(job, handle as _) == 0 {
                let err = io::Error::last_os_error();
                CloseHandle(job);
                return Err(err);
            }
            Ok(Self { job })
        }
    }

    #[cfg(unix)]
    pub fn adopt(child: &Child) -> io::Result<Self> {
        let group = child
            .id()
            .and_then(|id| i32::try_from(id).ok())
            .filter(|id| *id > 0)
            .ok_or_else(|| io::Error::other("process already exited"))?;
        Ok(Self { group })
    }

    #[cfg(not(any(windows, unix)))]
    pub fn adopt(_child: &Child) -> io::Result<Self> {
        Ok(Self {})
    }
}

#[cfg(unix)]
impl Drop for ProcessTree {
    fn drop(&mut self) {
        unsafe extern "C" {
            fn kill(pid: i32, signal: i32) -> i32;
        }
        // configure() puts only this child and its descendants in this group.
        // SIGKILL terminates Python AND FFmpeg before the scheduler cleans files.
        unsafe {
            kill(-self.group, 9);
        }
    }
}

#[cfg(windows)]
impl Drop for ProcessTree {
    fn drop(&mut self) {
        use windows_sys::Win32::Foundation::CloseHandle;
        use windows_sys::Win32::System::JobObjects::TerminateJobObject;
        unsafe {
            TerminateJobObject(self.job, 1);
            CloseHandle(self.job);
        }
    }
}

#[cfg(all(test, windows))]
mod tests {
    use super::*;
    use std::time::Duration;

    #[tokio::test]
    async fn dropping_the_tree_kills_children() {
        // cmd starts a grandchild (ping) that must die with the job.
        let mut command = Command::new("cmd");
        command.args(["/C", "ping -n 30 127.0.0.1 > NUL"]);
        configure(&mut command, true);
        let mut child = command.spawn().unwrap();
        let tree = ProcessTree::adopt(&child).unwrap();
        tokio::time::sleep(Duration::from_millis(300)).await;
        drop(tree);
        let status = tokio::time::timeout(Duration::from_secs(5), child.wait())
            .await
            .expect("process tree terminated")
            .unwrap();
        assert!(!status.success());
    }
}
