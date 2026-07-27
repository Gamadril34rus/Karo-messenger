#include <flutter/dart_api.h>
#include <flutter/engine.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <iostream>

#include "flutter_window.cpp"
#include "utils.cpp"

int APIENTRY wWinMain(HINSTANCE instance, HINSTANCE prev, wchar_t *command_line, int show_command) {
  // Attach to console when present
  HWND console_window = GetConsoleWindow();
  if (console_window != nullptr) {
    ShowWindow(console_window, SW_HIDE);
  }

  // Initialize COM
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr)) {
    return EXIT_FAILURE;
  }

  // Flutter engine setup
  flutter::FlutterViewController flutter_controller(
      L"", // dart_entrypoint
      GetCurrentProcessId(),
      std::string("ЧАРО"),
      std::string("com.charo.messenger"));

  FlutterWindow window(&flutter_controller);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"ЧАРО", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  CoUninitialize();
  return EXIT_SUCCESS;
}
