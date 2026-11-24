#ifndef RUNNER_FILE_DROP_H_
#define RUNNER_FILE_DROP_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>

// Files dropped on the window from the Explorer (Convertir: "Glissez des
// fichiers ici"). Sent to Dart on org.miarina.media/drop as "files" with
// their paths; screens that do not take files ignore them.
class FileDropChannel {
 public:
  FileDropChannel(flutter::BinaryMessenger* messenger, HWND window);
  ~FileDropChannel();

  // True when `message` was a drop (handled).
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_FILE_DROP_H_
