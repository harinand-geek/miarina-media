#include "screen_tools.h"

#include <dwmapi.h>

#include <string>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

// Hot key ids start here (others may be used by the system or plugins).
constexpr int kHotkeyBase = 0x4D4D;
constexpr int kHotkeyMax = 8;

int IntArg(const EncodableMap& map, const char* key, int fallback = 0) {
  auto it = map.find(EncodableValue(key));
  if (it == map.end()) return fallback;
  if (auto v = std::get_if<int32_t>(&it->second)) return *v;
  if (auto v = std::get_if<int64_t>(&it->second)) return static_cast<int>(*v);
  return fallback;
}

bool BoolArg(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(key));
  if (it == map.end()) return false;
  auto v = std::get_if<bool>(&it->second);
  return v && *v;
}

std::string StringArg(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(key));
  if (it == map.end()) return std::string();
  auto v = std::get_if<std::string>(&it->second);
  return v ? *v : std::string();
}

std::wstring Wide(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int size = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                       static_cast<int>(utf8.size()), nullptr,
                                       0);
  std::wstring out(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      out.data(), size);
  return out;
}

EncodableMap RectMap(const RECT& rect) {
  return EncodableMap{
      {EncodableValue("x"), EncodableValue(static_cast<int>(rect.left))},
      {EncodableValue("y"), EncodableValue(static_cast<int>(rect.top))},
      {EncodableValue("width"),
       EncodableValue(static_cast<int>(rect.right - rect.left))},
      {EncodableValue("height"),
       EncodableValue(static_cast<int>(rect.bottom - rect.top))},
  };
}

// The monitor the mouse is on, in physical pixels.
RECT MonitorAtCursor() {
  POINT p;
  GetCursorPos(&p);
  HMONITOR monitor = MonitorFromPoint(p, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{sizeof(MONITORINFO)};
  GetMonitorInfo(monitor, &info);
  return info.rcMonitor;
}

// Writes the 32-bit picture of `rect` (bottom-up BMP) to `path`.
bool CaptureToBmp(const RECT& rect, bool cursor, const std::wstring& path) {
  const int w = rect.right - rect.left;
  const int h = rect.bottom - rect.top;
  if (w <= 0 || h <= 0) return false;
  HDC screen = GetDC(nullptr);
  HDC memory = CreateCompatibleDC(screen);
  HBITMAP bitmap = CreateCompatibleBitmap(screen, w, h);
  HGDIOBJ old = SelectObject(memory, bitmap);
  BitBlt(memory, 0, 0, w, h, screen, rect.left, rect.top,
         SRCCOPY | CAPTUREBLT);
  if (cursor) {
    CURSORINFO ci{sizeof(CURSORINFO)};
    if (GetCursorInfo(&ci) && (ci.flags & CURSOR_SHOWING)) {
      ICONINFO ii{};
      if (GetIconInfo(ci.hCursor, &ii)) {
        DrawIconEx(memory,
                   ci.ptScreenPos.x - rect.left - static_cast<int>(ii.xHotspot),
                   ci.ptScreenPos.y - rect.top - static_cast<int>(ii.yHotspot),
                   ci.hCursor, 0, 0, 0, nullptr, DI_NORMAL);
        if (ii.hbmMask) DeleteObject(ii.hbmMask);
        if (ii.hbmColor) DeleteObject(ii.hbmColor);
      }
    }
  }
  BITMAPINFOHEADER header{};
  header.biSize = sizeof(BITMAPINFOHEADER);
  header.biWidth = w;
  header.biHeight = h;  // bottom-up
  header.biPlanes = 1;
  header.biBitCount = 32;
  header.biCompression = BI_RGB;
  const DWORD size = static_cast<DWORD>(w) * h * 4;
  std::vector<BYTE> pixels(size);
  GetDIBits(memory, bitmap, 0, h, pixels.data(),
            reinterpret_cast<BITMAPINFO*>(&header), DIB_RGB_COLORS);
  // Opaque (GDI leaves the alpha byte at 0).
  for (DWORD i = 3; i < size; i += 4) pixels[i] = 255;
  SelectObject(memory, old);
  DeleteObject(bitmap);
  DeleteDC(memory);
  ReleaseDC(nullptr, screen);

  BITMAPFILEHEADER file{};
  file.bfType = 0x4D42;
  file.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
  file.bfSize = file.bfOffBits + size;
  HANDLE out = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                           CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (out == INVALID_HANDLE_VALUE) return false;
  DWORD written = 0;
  const bool ok =
      WriteFile(out, &file, sizeof(file), &written, nullptr) &&
      WriteFile(out, &header, sizeof(header), &written, nullptr) &&
      WriteFile(out, pixels.data(), size, &written, nullptr);
  CloseHandle(out);
  return ok;
}

// A BMP file's picture to the clipboard (CF_DIB: the file minus its header).
bool CopyBmp(HWND window, const std::wstring& path) {
  HANDLE in = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                          OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (in == INVALID_HANDLE_VALUE) return false;
  LARGE_INTEGER length{};
  GetFileSizeEx(in, &length);
  const LONGLONG total = length.QuadPart;
  if (total <= static_cast<LONGLONG>(sizeof(BITMAPFILEHEADER)) ||
      total > 512LL * 1024 * 1024) {
    CloseHandle(in);
    return false;
  }
  std::vector<BYTE> data(static_cast<size_t>(total));
  DWORD read = 0;
  ReadFile(in, data.data(), static_cast<DWORD>(total), &read, nullptr);
  CloseHandle(in);
  const size_t dib = data.size() - sizeof(BITMAPFILEHEADER);
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, dib);
  if (!memory) return false;
  memcpy(GlobalLock(memory), data.data() + sizeof(BITMAPFILEHEADER), dib);
  GlobalUnlock(memory);
  if (!OpenClipboard(window)) {
    GlobalFree(memory);
    return false;
  }
  EmptyClipboard();
  const bool ok = SetClipboardData(CF_DIB, memory) != nullptr;
  CloseClipboard();
  if (!ok) GlobalFree(memory);
  return ok;
}

// UTF-16 → UTF-8.
std::string Narrow(const std::wstring& wide) {
  if (wide.empty()) return std::string();
  const int size = WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                                       static_cast<int>(wide.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string out(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                      out.data(), size, nullptr, nullptr);
  return out;
}

BOOL CALLBACK AddMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* list = reinterpret_cast<EncodableList*>(data);
  MONITORINFO info{sizeof(MONITORINFO)};
  if (!GetMonitorInfo(monitor, &info)) return TRUE;
  EncodableMap map = RectMap(info.rcMonitor);
  map[EncodableValue("primary")] =
      EncodableValue((info.dwFlags & MONITORINFOF_PRIMARY) != 0);
  list->emplace_back(map);
  return TRUE;
}

struct WindowSearch {
  HWND self;
  EncodableList list;
};

// Windows a person would call windows: visible, titled, not a tool window,
// not hidden by the shell (cloaked), not ours.
BOOL CALLBACK AddWindow(HWND hwnd, LPARAM data) {
  auto* search = reinterpret_cast<WindowSearch*>(data);
  if (hwnd == search->self || !IsWindowVisible(hwnd) || IsIconic(hwnd) ||
      GetWindow(hwnd, GW_OWNER) != nullptr) {
    return TRUE;
  }
  if (GetWindowLongPtr(hwnd, GWL_EXSTYLE) & WS_EX_TOOLWINDOW) return TRUE;
  DWORD cloaked = 0;
  DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
  if (cloaked) return TRUE;
  wchar_t title[512];
  const int length = GetWindowTextW(hwnd, title, 512);
  if (length <= 0) return TRUE;
  RECT rect;
  if (!GetWindowRect(hwnd, &rect) || rect.right - rect.left < 64 ||
      rect.bottom - rect.top < 64) {
    return TRUE;
  }
  EncodableMap map = RectMap(rect);
  map[EncodableValue("title")] =
      EncodableValue(Narrow(std::wstring(title, length)));
  search->list.emplace_back(map);
  return search->list.size() < 64;
}

}  // namespace

ScreenTools::ScreenTools(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "org.miarina.media/screen_tools",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    OnCall(call, std::move(result));
  });
}

ScreenTools::~ScreenTools() {
  UnregisterAll();
  channel_->SetMethodCallHandler(nullptr);
}

void ScreenTools::UnregisterAll() {
  for (int id : hotkeys_) UnregisterHotKey(window_, id);
  hotkeys_.clear();
}

bool ScreenTools::HandleMessage(UINT message, WPARAM wparam, LPARAM) {
  if (message != WM_HOTKEY) return false;
  const int id = static_cast<int>(wparam) - kHotkeyBase;
  if (id < 0 || id >= kHotkeyMax) return false;
  channel_->InvokeMethod("hotkey", std::make_unique<EncodableValue>(id));
  return true;
}

void ScreenTools::OnCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto* args = std::get_if<EncodableMap>(call.arguments());
  const EncodableMap empty;
  const EncodableMap& a = args ? *args : empty;
  const std::string& name = call.method_name();

  if (name == "registerHotkeys") {
    // {keys: [{id, mods, key}]}: returns the ids Windows refused.
    UnregisterAll();
    EncodableList failed;
    auto it = a.find(EncodableValue("keys"));
    if (it != a.end()) {
      if (auto list = std::get_if<EncodableList>(&it->second)) {
        for (const auto& entry : *list) {
          auto key = std::get_if<EncodableMap>(&entry);
          if (!key) continue;
          const int id = IntArg(*key, "id", -1);
          const int mods = IntArg(*key, "mods");
          const int vk = IntArg(*key, "key");
          if (id < 0 || id >= kHotkeyMax || vk <= 0) continue;
          if (RegisterHotKey(window_, kHotkeyBase + id,
                             static_cast<UINT>(mods) | MOD_NOREPEAT,
                             static_cast<UINT>(vk))) {
            hotkeys_.push_back(kHotkeyBase + id);
          } else {
            failed.emplace_back(id);
          }
        }
      }
    }
    result->Success(EncodableValue(failed));
    return;
  }

  if (name == "capture") {
    // The screen under the mouse, as a BMP file in `path`.
    const RECT rect = MonitorAtCursor();
    const std::wstring path = Wide(StringArg(a, "path"));
    if (path.empty() || !CaptureToBmp(rect, BoolArg(a, "cursor"), path)) {
      result->Error("capture_failed");
      return;
    }
    result->Success(EncodableValue(RectMap(rect)));
    return;
  }

  if (name == "monitor") {
    result->Success(EncodableValue(RectMap(MonitorAtCursor())));
    return;
  }

  if (name == "monitors") {
    EncodableList list;
    EnumDisplayMonitors(nullptr, nullptr, AddMonitor,
                        reinterpret_cast<LPARAM>(&list));
    result->Success(EncodableValue(list));
    return;
  }

  if (name == "windows") {
    WindowSearch search{window_, {}};
    EnumWindows(AddWindow, reinterpret_cast<LPARAM>(&search));
    result->Success(EncodableValue(search.list));
    return;
  }

  if (name == "enterOverlay") {
    // The window covers {x, y, width, height}, borderless and on top;
    // {radius} rounds its corners, {activate: false} leaves the focus
    // where it is (the recording bar).
    if (!overlay_) {
      style_ = GetWindowLongPtr(window_, GWL_STYLE);
      ex_style_ = GetWindowLongPtr(window_, GWL_EXSTYLE);
      placement_.length = sizeof(WINDOWPLACEMENT);
      GetWindowPlacement(window_, &placement_);
      was_visible_ = IsWindowVisible(window_) && !IsIconic(window_);
      overlay_ = true;
    }
    const bool activate =
        a.find(EncodableValue("activate")) == a.end() || BoolArg(a, "activate");
    const int width = IntArg(a, "width");
    const int height = IntArg(a, "height");
    const int radius = IntArg(a, "radius");
    if (IsIconic(window_)) ShowWindow(window_, SW_RESTORE);
    SetWindowLongPtr(window_, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    SetWindowPos(window_, HWND_TOPMOST, IntArg(a, "x"), IntArg(a, "y"), width,
                 height,
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW |
                     (activate ? 0 : SWP_NOACTIVATE));
    // The system owns the region once given.
    SetWindowRgn(window_,
                 radius > 0 ? CreateRoundRectRgn(0, 0, width + 1, height + 1,
                                                 radius * 2, radius * 2)
                            : nullptr,
                 TRUE);
    if (activate) {
      SetForegroundWindow(window_);
      SetFocus(window_);
    }
    result->Success();
    return;
  }

  if (name == "exitOverlay") {
    // Back as it was: frame, place, minimized when it was.
    const bool visible = was_visible_;
    if (overlay_) {
      SetWindowRgn(window_, nullptr, TRUE);
      SetWindowLongPtr(window_, GWL_STYLE, style_);
      SetWindowLongPtr(window_, GWL_EXSTYLE, ex_style_);
      SetWindowPos(window_, HWND_NOTOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);
      SetWindowPlacement(window_, &placement_);
      if (!was_visible_) ShowWindow(window_, SW_MINIMIZE);
      overlay_ = false;
    }
    result->Success(EncodableValue(visible));
    return;
  }

  if (name == "copyImage") {
    result->Success(
        EncodableValue(CopyBmp(window_, Wide(StringArg(a, "path")))));
    return;
  }

  if (name == "beep") {
    MessageBeep(MB_OK);
    result->Success();
    return;
  }

  if (name == "excludeFromCapture") {
    // The window is left out of screen recordings (Windows 10 2004+).
    const BOOL ok = SetWindowDisplayAffinity(
        window_, BoolArg(a, "on") ? WDA_EXCLUDEFROMCAPTURE : WDA_NONE);
    result->Success(EncodableValue(ok != FALSE));
    return;
  }

  result->NotImplemented();
}
