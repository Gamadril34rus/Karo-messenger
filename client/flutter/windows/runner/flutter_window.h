#ifndef FLUTTER_WINDOW_H_
#define FLUTTER_WINDOW_H_

#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <memory>
#include <string>

#include "win32_window.h"

class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(flutter::FlutterViewController *flutter_controller);
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT message, WPARAM wparam,
                         LPARAM lparam) noexcept override;

 private:
  flutter::FlutterViewController *flutter_controller_;
};

#endif  // FLUTTER_WINDOW_H_
