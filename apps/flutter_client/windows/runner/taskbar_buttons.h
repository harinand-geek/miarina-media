#ifndef RUNNER_TASKBAR_BUTTONS_H_
#define RUNNER_TASKBAR_BUTTONS_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <shobjidl.h>
#include <windows.h>

#include <memory>
#include <string>

// Previous / Play-Pause / Next buttons in the window's taskbar thumbnail
// (handoff W-M4). Dart sends the state on channel "miarina/taskbar"
// ("update"); clicks come back as "pressed" with "previous", "toggle" or
// "next".
class TaskbarButtons {
 public:
  TaskbarButtons(flutter::BinaryMessenger* messenger, HWND window);
  ~TaskbarButtons();

  // Handles the messages of the top-level window that concern the buttons;
  // returns true when the message was consumed.
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  void Apply();
  HICON GlyphIcon(wchar_t glyph);

  HWND window_;
  UINT created_message_;
  ITaskbarList3* taskbar_ = nullptr;
  bool added_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  // State from Dart.
  bool enabled_ = false;
  bool playing_ = false;
  bool has_previous_ = false;
  bool has_next_ = false;
  std::wstring tips_[4];  // previous, play, pause, next

  HICON icons_[4] = {nullptr, nullptr, nullptr, nullptr};
};

#endif  // RUNNER_TASKBAR_BUTTONS_H_
