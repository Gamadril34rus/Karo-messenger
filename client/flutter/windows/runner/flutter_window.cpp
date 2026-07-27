#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <memory>
#include <string>

#include "flutter_window.h"

FlutterWindow::FlutterWindow(flutter::FlutterViewController *flutter_controller)
    : flutter_controller_(flutter_controller) {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }
  return true;
}

void FlutterWindow::OnDestroy() {
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                                       LPARAM const lparam) noexcept {
  return Win32Window::MessageHandler(window, message, wparam, lparam);
}
