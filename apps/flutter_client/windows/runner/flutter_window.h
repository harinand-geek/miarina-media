#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "file_drop.h"
#include "single_instance.h"
#include "taskbar_buttons.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Previous / Play / Next in the taskbar thumbnail (W-M4).
  std::unique_ptr<TaskbarButtons> taskbar_buttons_;

  // Files handed over by a later launch (single instance).
  std::unique_ptr<OpenFilesChannel> open_files_;

  // Files dropped from the Explorer.
  std::unique_ptr<FileDropChannel> file_drop_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
