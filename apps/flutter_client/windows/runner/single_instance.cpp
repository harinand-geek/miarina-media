#include "single_instance.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cwctype>
#include <functional>
#include <sstream>

namespace {

// COPYDATASTRUCT::dwData of a launch's arguments ("MMOP").
constexpr ULONG_PTR kOpenArguments = 0x4D4D4F50;
// Longest payload accepted (a few file paths): bounded, untrusted input.
constexpr DWORD kMaxPayload = 64 * 1024;

constexpr wchar_t kWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

std::wstring ExecutablePath() {
  std::wstring path(MAX_PATH, L'\0');
  for (;;) {
    DWORD n = GetModuleFileNameW(nullptr, path.data(),
                                 static_cast<DWORD>(path.size()));
    if (n < path.size()) {
      path.resize(n);
      break;
    }
    path.resize(path.size() * 2);
  }
  std::transform(path.begin(), path.end(), path.begin(), std::towlower);
  return path;
}

std::wstring ProcessPath(DWORD pid) {
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return std::wstring();
  std::wstring path(32768, L'\0');
  DWORD size = static_cast<DWORD>(path.size());
  std::wstring result;
  if (QueryFullProcessImageNameW(process, 0, path.data(), &size)) {
    path.resize(size);
    std::transform(path.begin(), path.end(), path.begin(), std::towlower);
    result = path;
  }
  CloseHandle(process);
  return result;
}

struct Search {
  std::wstring executable;
  DWORD self;
  HWND found;
};

BOOL CALLBACK FindWindowOfExecutable(HWND window, LPARAM param) {
  auto* search = reinterpret_cast<Search*>(param);
  wchar_t name[64] = {};
  GetClassNameW(window, name, 64);
  if (wcscmp(name, kWindowClass) != 0) return TRUE;
  DWORD pid = 0;
  GetWindowThreadProcessId(window, &pid);
  if (pid == search->self || ProcessPath(pid) != search->executable) {
    return TRUE;
  }
  search->found = window;
  return FALSE;
}

}  // namespace

bool ForwardToRunningInstance(const std::vector<std::string>& arguments) {
  const std::wstring executable = ExecutablePath();
  std::wstringstream name;
  name << L"Local\\MiarinaMedia-" << std::hex
       << std::hash<std::wstring>{}(executable);
  // Kept open for the life of the process: the lock is the handle itself.
  CreateMutexW(nullptr, FALSE, name.str().c_str());
  if (GetLastError() != ERROR_ALREADY_EXISTS) return false;

  // The first copy may still be creating its window: wait a little for it.
  Search search{executable, GetCurrentProcessId(), nullptr};
  for (int attempt = 0; attempt < 50 && !search.found; ++attempt) {
    EnumWindows(FindWindowOfExecutable, reinterpret_cast<LPARAM>(&search));
    if (!search.found) Sleep(100);
  }
  if (!search.found) return false;

  // Paths cannot hold a line break: one argument per line, UTF-8.
  std::string payload;
  for (const auto& argument : arguments) {
    payload += argument;
    payload += '\n';
  }
  if (payload.size() > kMaxPayload) payload.resize(kMaxPayload);
  DWORD pid = 0;
  GetWindowThreadProcessId(search.found, &pid);
  AllowSetForegroundWindow(pid);
  COPYDATASTRUCT data{kOpenArguments, static_cast<DWORD>(payload.size()),
                      payload.data()};
  DWORD_PTR ignored = 0;
  SendMessageTimeoutW(search.found, WM_COPYDATA, 0,
                      reinterpret_cast<LPARAM>(&data), SMTO_ABORTIFHUNG, 5000,
                      &ignored);
  return true;
}

OpenFilesChannel::OpenFilesChannel(flutter::BinaryMessenger* messenger,
                                   HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "org.miarina.media/open_with",
      &flutter::StandardMethodCodec::GetInstance());
}

bool OpenFilesChannel::HandleMessage(UINT message, WPARAM, LPARAM lparam) {
  if (message != WM_COPYDATA) return false;
  const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
  if (!data || data->dwData != kOpenArguments) return false;

  // The window comes back and to the front, as with a new launch.
  if (IsIconic(window_)) ShowWindow(window_, SW_RESTORE);
  SetForegroundWindow(window_);

  const DWORD size = std::min(data->cbData, kMaxPayload);
  std::string payload(static_cast<const char*>(data->lpData), size);
  flutter::EncodableList arguments;
  std::stringstream lines(payload);
  std::string line;
  while (std::getline(lines, line)) {
    if (!line.empty()) arguments.emplace_back(line);
  }
  channel_->InvokeMethod(
      "args",
      std::make_unique<flutter::EncodableValue>(std::move(arguments)));
  return true;
}
