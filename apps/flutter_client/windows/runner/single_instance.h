#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

// One window per installed copy of the app (like other media players): a
// second launch ("Open with Miarina Media", a double-click on a file, the
// Start menu) hands its arguments to the window already open and exits.
// The lock is per executable path, so a recette or development build never
// talks to the installed app.

// Called first in wWinMain: true when another copy is running and received
// `arguments` (the caller then exits).
bool ForwardToRunningInstance(const std::vector<std::string>& arguments);

// In the running window: arguments sent by a later launch reach Dart on
// "org.miarina.media/open_with" ("args", a list of strings), and the window
// comes to the front.
class OpenFilesChannel {
 public:
  OpenFilesChannel(flutter::BinaryMessenger* messenger, HWND window);

  // True when `message` was a launch's arguments (handled).
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_SINGLE_INSTANCE_H_
