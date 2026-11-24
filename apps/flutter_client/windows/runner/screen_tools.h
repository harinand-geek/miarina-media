#ifndef RUNNER_SCREEN_TOOLS_H_
#define RUNNER_SCREEN_TOOLS_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <vector>

// Outils PC (design_handoff_outils_pc): global shortcuts, a picture of the
// screen under the mouse, the window turned into a full-screen overlay (the
// zone selection is drawn by Flutter) and back, the clipboard, the window
// left out of screen recordings. Channel org.miarina.media/screen_tools.
class ScreenTools {
 public:
  ScreenTools(flutter::BinaryMessenger* messenger, HWND window);
  ~ScreenTools();

  // True when `message` was one of ours (a global shortcut).
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  void OnCall(const flutter::MethodCall<flutter::EncodableValue>& call,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                  result);
  void UnregisterAll();

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::vector<int> hotkeys_;
  // The window as it was before the overlay.
  bool overlay_ = false;
  LONG_PTR style_ = 0;
  LONG_PTR ex_style_ = 0;
  WINDOWPLACEMENT placement_{sizeof(WINDOWPLACEMENT)};
  bool was_visible_ = true;
};

#endif  // RUNNER_SCREEN_TOOLS_H_
