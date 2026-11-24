#include "screen_tools.h"

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

  if (name == "enterOverlay") {
    // The window covers {x, y, width, height}, borderless and on top.
    if (!overlay_) {
      style_ = GetWindowLongPtr(window_, GWL_STYLE);
      ex_style_ = GetWindowLongPtr(window_, GWL_EXSTYLE);
      placement_.length = sizeof(WINDOWPLACEMENT);
      GetWindowPlacement(window_, &placement_);
      was_visible_ = IsWindowVisible(window_) && !IsIconic(window_);
      overlay_ = true;
    }
    SetWindowLongPtr(window_, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    SetWindowPos(window_, HWND_TOPMOST, IntArg(a, "x"), IntArg(a, "y"),
                 IntArg(a, "width"), IntArg(a, "height"),
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    SetForegroundWindow(window_);
    SetFocus(window_);
    result->Success();
    return;
  }

  if (name == "exitOverlay") {
    // Back as it was: frame, place, minimized when it was.
    const bool visible = was_visible_;
    if (overlay_) {
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
