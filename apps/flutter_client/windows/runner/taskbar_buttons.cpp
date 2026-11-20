#include "taskbar_buttons.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdint>
#include <cstring>

namespace {

constexpr UINT kPrevious = 1;
constexpr UINT kToggle = 2;
constexpr UINT kNext = 3;

// Segoe Fluent Icons (Windows 11) / Segoe MDL2 Assets (Windows 10) glyphs.
constexpr wchar_t kGlyphPrevious = 0xE892;
constexpr wchar_t kGlyphPlay = 0xE768;
constexpr wchar_t kGlyphPause = 0xE769;
constexpr wchar_t kGlyphNext = 0xE893;

std::wstring Widen(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int n = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                              static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring out(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      out.data(), n);
  return out;
}

bool BoolArg(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return false;
  const bool* value = std::get_if<bool>(&it->second);
  return value != nullptr && *value;
}

HFONT IconFont(int size, const wchar_t* face) {
  return CreateFontW(-size, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                     DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                     ANTIALIASED_QUALITY, DEFAULT_PITCH, face);
}

}  // namespace

TaskbarButtons::TaskbarButtons(flutter::BinaryMessenger* messenger,
                               HWND window)
    : window_(window),
      created_message_(RegisterWindowMessageW(L"TaskbarButtonCreated")) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "miarina/taskbar",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "update") {
          result->NotImplemented();
          return;
        }
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (args == nullptr) {
          result->Error("bad-arguments");
          return;
        }
        enabled_ = BoolArg(*args, "enabled");
        playing_ = BoolArg(*args, "playing");
        has_previous_ = BoolArg(*args, "hasPrevious");
        has_next_ = BoolArg(*args, "hasNext");
        auto tips = args->find(flutter::EncodableValue("tips"));
        if (tips != args->end()) {
          if (const auto* list =
                  std::get_if<flutter::EncodableList>(&tips->second)) {
            for (size_t i = 0; i < 4 && i < list->size(); i++) {
              if (const auto* s = std::get_if<std::string>(&(*list)[i])) {
                tips_[i] = Widen(*s);
              }
            }
          }
        }
        Apply();
        result->Success();
      });
}

TaskbarButtons::~TaskbarButtons() {
  for (HICON& icon : icons_) {
    if (icon != nullptr) DestroyIcon(icon);
    icon = nullptr;
  }
  if (taskbar_ != nullptr) taskbar_->Release();
}

bool TaskbarButtons::HandleMessage(UINT message, WPARAM wparam,
                                   LPARAM lparam) {
  if (message == created_message_) {
    // Sent when the taskbar button exists (again after an Explorer
    // restart): the buttons are added from scratch.
    if (taskbar_ == nullptr &&
        SUCCEEDED(CoCreateInstance(CLSID_TaskbarList, nullptr,
                                   CLSCTX_INPROC_SERVER,
                                   IID_PPV_ARGS(&taskbar_)))) {
      if (FAILED(taskbar_->HrInit())) {
        taskbar_->Release();
        taskbar_ = nullptr;
      }
    }
    added_ = false;
    Apply();
    return false;
  }
  if (message == WM_COMMAND && HIWORD(wparam) == THBN_CLICKED) {
    const char* name = nullptr;
    switch (LOWORD(wparam)) {
      case kPrevious:
        name = "previous";
        break;
      case kToggle:
        name = "toggle";
        break;
      case kNext:
        name = "next";
        break;
    }
    if (name != nullptr) {
      channel_->InvokeMethod(
          "pressed", std::make_unique<flutter::EncodableValue>(name));
      return true;
    }
  }
  return false;
}

HICON TaskbarButtons::GlyphIcon(wchar_t glyph) {
  const UINT dpi = GetDpiForWindow(window_);
  const int size = GetSystemMetricsForDpi(SM_CXSMICON, dpi);

  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = size;
  info.bmiHeader.biHeight = -size;  // top-down
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;

  HDC screen = GetDC(nullptr);
  HDC dc = CreateCompatibleDC(screen);
  ReleaseDC(nullptr, screen);
  void* bits = nullptr;
  HBITMAP color =
      CreateDIBSection(dc, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
  if (color == nullptr || bits == nullptr) {
    DeleteDC(dc);
    return nullptr;
  }
  HGDIOBJ old_bitmap = SelectObject(dc, color);
  std::memset(bits, 0, static_cast<size_t>(size) * size * 4);

  HFONT font = IconFont(size, L"Segoe Fluent Icons");
  HGDIOBJ old_font = SelectObject(dc, font);
  wchar_t face[LF_FACESIZE] = {};
  GetTextFaceW(dc, LF_FACESIZE, face);
  if (wcscmp(face, L"Segoe Fluent Icons") != 0) {
    SelectObject(dc, old_font);
    DeleteObject(font);
    font = IconFont(size, L"Segoe MDL2 Assets");
    old_font = SelectObject(dc, font);
  }
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, RGB(255, 255, 255));
  RECT rect = {0, 0, size, size};
  DrawTextW(dc, &glyph, 1, &rect,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
  GdiFlush();

  // GDI leaves alpha at 0: the glyph's coverage becomes the alpha of a
  // white icon.
  auto* pixels = static_cast<uint32_t*>(bits);
  for (int i = 0; i < size * size; i++) {
    const uint32_t p = pixels[i];
    const uint32_t v = std::max({p & 0xFF, (p >> 8) & 0xFF, (p >> 16) & 0xFF});
    pixels[i] = (v << 24) | 0x00FFFFFF;
  }

  SelectObject(dc, old_font);
  DeleteObject(font);
  SelectObject(dc, old_bitmap);
  DeleteDC(dc);

  HBITMAP mask = CreateBitmap(size, size, 1, 1, nullptr);
  ICONINFO icon_info = {};
  icon_info.fIcon = TRUE;
  icon_info.hbmMask = mask;
  icon_info.hbmColor = color;
  HICON icon = CreateIconIndirect(&icon_info);
  DeleteObject(mask);
  DeleteObject(color);
  return icon;
}

void TaskbarButtons::Apply() {
  if (taskbar_ == nullptr) return;
  if (icons_[0] == nullptr) {
    icons_[0] = GlyphIcon(kGlyphPrevious);
    icons_[1] = GlyphIcon(kGlyphPlay);
    icons_[2] = GlyphIcon(kGlyphPause);
    icons_[3] = GlyphIcon(kGlyphNext);
  }
  THUMBBUTTON buttons[3] = {};
  const struct {
    UINT id;
    HICON icon;
    const std::wstring* tip;
    bool on;
  } specs[3] = {
      {kPrevious, icons_[0], &tips_[0], has_previous_},
      {kToggle, playing_ ? icons_[2] : icons_[1],
       playing_ ? &tips_[2] : &tips_[1], true},
      {kNext, icons_[3], &tips_[3], has_next_},
  };
  for (int i = 0; i < 3; i++) {
    THUMBBUTTON& b = buttons[i];
    b.dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
    b.iId = specs[i].id;
    b.hIcon = specs[i].icon;
    wcsncpy_s(b.szTip, specs[i].tip->c_str(), _TRUNCATE);
    // Nothing loaded: no buttons rather than buttons doing nothing.
    b.dwFlags = !enabled_ ? THBF_HIDDEN
                          : (specs[i].on ? THBF_ENABLED : THBF_DISABLED);
  }
  if (!added_) {
    added_ = SUCCEEDED(taskbar_->ThumbBarAddButtons(window_, 3, buttons));
  } else {
    taskbar_->ThumbBarUpdateButtons(window_, 3, buttons);
  }
}
