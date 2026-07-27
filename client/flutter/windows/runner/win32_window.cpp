#include "win32_window.h"

#include <windows.h>
#include <dwmapi.h>

#include <string>

Win32Window::Win32Window() {}

Win32Window::~Win32Window() { Destroy(); }

bool Win32Window::Create(const std::wstring &title, const Point &origin,
                          const Size &size) {
  WNDCLASS window_class{};
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = L"CHARO";
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.lpfnWndProc = WndProc;
  RegisterClass(&window_class);

  window_handle_ = CreateWindow(
      L"CHARO", title.c_str(), WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      origin.x, origin.y, size.width, size.height,
      nullptr, nullptr, nullptr, this);

  if (!window_handle_) {
    return false;
  }

  return OnCreate();
}

void Win32Window::Destroy() {
  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  OnDestroy();
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

LRESULT CALLBACK Win32Window::WndProc(HWND window, UINT message,
                                       WPARAM wparam, LPARAM lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto cs = reinterpret_cast<CREATESTRUCT *>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(cs->lpCreateParams));
  } else if (message == WM_DESTROY) {
    auto win = reinterpret_cast<Win32Window *>(GetWindowLongPtr(window, GWLP_USERDATA));
    if (win) {
      win->Destroy();
      if (win->quit_on_close_) {
        PostQuitMessage(0);
      }
    }
    return 0;
  }

  auto win = reinterpret_cast<Win32Window *>(GetWindowLongPtr(window, GWLP_USERDATA));
  if (win) {
    return win->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

bool Win32Window::OnCreate() { return true; }

void Win32Window::OnDestroy() {}

LRESULT Win32Window::MessageHandler(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) noexcept {
  return DefWindowProc(window, message, wparam, lparam);
}
