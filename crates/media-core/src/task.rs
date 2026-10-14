//! Download task lifecycle.
//!
//! Every state change goes through [`TaskState::transition`], so an invalid
//! transition is a typed error instead of silent data corruption.

use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskState {
    /// Accepted by the user, waiting to be analyzed or scheduled.
    Queued,
    /// Reading metadata and formats from the source.
    Analyzing,
    /// Ready, waiting for a free download slot (or a retry delay).
    Waiting,
    /// Bytes are being streamed to a temporary file.
    Downloading,
    /// Stopped by the user or by the system (offline, metered network).
    Paused,
    /// Merging or converting after the download.
    Processing,
    Completed,
    Failed,
    Canceled,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
#[error("invalid task transition from {from:?} to {to:?}")]
pub struct TransitionError {
    pub from: TaskState,
    pub to: TaskState,
}

impl TaskState {
    pub const ALL: [TaskState; 9] = [
        Self::Queued,
        Self::Analyzing,
        Self::Waiting,
        Self::Downloading,
        Self::Paused,
        Self::Processing,
        Self::Completed,
        Self::Failed,
        Self::Canceled,
    ];

    /// Stable identifier used in storage and events (same as serde).
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Queued => "queued",
            Self::Analyzing => "analyzing",
            Self::Waiting => "waiting",
            Self::Downloading => "downloading",
            Self::Paused => "paused",
            Self::Processing => "processing",
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Canceled => "canceled",
        }
    }

    pub fn parse(value: &str) -> Option<TaskState> {
        Self::ALL.into_iter().find(|s| s.as_str() == value)
    }

    pub fn is_terminal(self) -> bool {
        matches!(self, Self::Completed | Self::Canceled)
    }

    /// States in which a worker may hold resources (network, process, file).
    pub fn is_active(self) -> bool {
        matches!(self, Self::Analyzing | Self::Downloading | Self::Processing)
    }

    pub fn can_transition(self, to: TaskState) -> bool {
        use TaskState::*;
        matches!(
            (self, to),
            (Queued, Analyzing | Waiting | Failed | Canceled)
                | (Analyzing, Waiting | Failed | Canceled)
                | (Waiting, Downloading | Paused | Canceled)
                // Downloading -> Waiting is a bounded retry after a transient error.
                | (Downloading, Processing | Completed | Paused | Waiting | Failed | Canceled)
                | (Paused, Waiting | Canceled)
                | (Processing, Completed | Failed | Canceled)
                // A failed task can be retried by the user.
                | (Failed, Queued | Canceled)
        )
    }

    pub fn transition(self, to: TaskState) -> Result<TaskState, TransitionError> {
        if self.can_transition(to) {
            Ok(to)
        } else {
            Err(TransitionError { from: self, to })
        }
    }

    /// State to restore for a task found in `self` after the application was
    /// interrupted. Work that was in flight never resumes silently: it either
    /// waits for the user (`Paused`) or restarts from the queue when the
    /// source cannot resume partial data.
    pub fn recover_after_restart(self, source_supports_resume: bool) -> TaskState {
        match self {
            Self::Analyzing => Self::Queued,
            Self::Downloading | Self::Processing if source_supports_resume => Self::Paused,
            Self::Downloading | Self::Processing => Self::Queued,
            other => other,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::TaskState::{self, *};

    const ALL: [TaskState; 9] = TaskState::ALL;

    #[test]
    fn string_round_trip_matches_serde() {
        for state in ALL {
            assert_eq!(TaskState::parse(state.as_str()), Some(state));
            assert_eq!(
                serde_json::to_string(&state).unwrap(),
                format!("\"{}\"", state.as_str())
            );
        }
        assert_eq!(TaskState::parse("unknown"), None);
    }

    #[test]
    fn happy_path_is_valid() {
        let mut state = Queued;
        for next in [Analyzing, Waiting, Downloading, Processing, Completed] {
            state = state.transition(next).expect("valid transition");
        }
        assert_eq!(state, Completed);
    }

    #[test]
    fn pause_resume_cycle_is_valid() {
        let state = Downloading.transition(Paused).unwrap();
        let state = state.transition(Waiting).unwrap();
        assert_eq!(state.transition(Downloading), Ok(Downloading));
    }

    #[test]
    fn terminal_states_have_no_exit() {
        for from in [Completed, Canceled] {
            assert!(from.is_terminal());
            for to in ALL {
                assert!(
                    !from.can_transition(to),
                    "{from:?} -> {to:?} must be rejected"
                );
            }
        }
    }

    #[test]
    fn invalid_transitions_are_rejected() {
        let err = Queued.transition(Completed).unwrap_err();
        assert_eq!((err.from, err.to), (Queued, Completed));
        assert!(
            Paused.transition(Downloading).is_err(),
            "must wait for a slot first"
        );
        assert!(Processing.transition(Paused).is_err());
        assert!(Failed.transition(Downloading).is_err());
    }

    #[test]
    fn no_self_transitions() {
        for state in ALL {
            assert!(!state.can_transition(state), "{state:?} -> itself");
        }
    }

    #[test]
    fn every_non_terminal_state_can_be_canceled() {
        for state in ALL.into_iter().filter(|s| !s.is_terminal()) {
            assert!(
                state.can_transition(Canceled),
                "{state:?} cannot be canceled"
            );
        }
    }

    #[test]
    fn restart_recovery() {
        assert_eq!(Downloading.recover_after_restart(true), Paused);
        assert_eq!(Downloading.recover_after_restart(false), Queued);
        assert_eq!(Processing.recover_after_restart(false), Queued);
        assert_eq!(Analyzing.recover_after_restart(true), Queued);
        assert_eq!(Completed.recover_after_restart(false), Completed);
        assert_eq!(Paused.recover_after_restart(false), Paused);
        for state in ALL {
            assert!(!state.recover_after_restart(true).is_active());
        }
    }

    #[test]
    fn serializes_as_snake_case() {
        assert_eq!(
            serde_json::to_string(&Downloading).unwrap(),
            "\"downloading\""
        );
    }
}
