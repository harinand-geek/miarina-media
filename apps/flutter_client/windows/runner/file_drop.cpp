#include "file_drop.h"

#include <shellapi.h>

#include <string>

namespace {

// Paths dropped at once, at most (the screen bounds them again).
constexpr UINT kMaxFiles = 500;

std::string Utf8(const std::wstring& wide) {
  if (wide.empty()) return std::string();
  const int size = WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                                       static_cast<int>(wide.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string out(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                      out.data(), size, nullptr, nullptr);
  return out;
}

}  // namespace

FileDropChannel::FileDropChannel(flutter::BinaryMessenger* messenger,
                                 HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "org.miarina.media/drop",
      &flutter::StandardMethodCodec::GetInstance());
  DragAcceptFiles(window_, TRUE);
}

FileDropChannel::~FileDropChannel() { DragAcceptFiles(window_, FALSE); }

bool FileDropChannel::HandleMessage(UINT message, WPARAM wparam, LPARAM) {
  if (message != WM_DROPFILES) return false;
  HDROP drop = reinterpret_cast<HDROP>(wparam);
  const UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
  flutter::EncodableList files;
  for (UINT i = 0; i < count && i < kMaxFiles; ++i) {
    const UINT length = DragQueryFileW(drop, i, nullptr, 0);
    std::wstring path(length, L'\0');
    DragQueryFileW(drop, i, path.data(), length + 1);
    files.emplace_back(Utf8(path));
  }
  DragFinish(drop);
  channel_->InvokeMethod(
      "files", std::make_unique<flutter::EncodableValue>(std::move(files)));
  return true;
}
