#ifndef RUNNER_DESKTOP_PIP_CHANNEL_H_
#define RUNNER_DESKTOP_PIP_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <windows.h>

class DesktopPipChannel {
 public:
  static std::unique_ptr<DesktopPipChannel> Register(
      flutter::BinaryMessenger* messenger, HWND hwnd,
      const flutter::DartProject& project);

  DesktopPipChannel(HWND hwnd, const flutter::DartProject& project);
  ~DesktopPipChannel();

  HWND hwnd() const { return hwnd_; }

  DesktopPipChannel(const DesktopPipChannel&) = delete;
  DesktopPipChannel& operator=(const DesktopPipChannel&) = delete;

 private:
  bool CreateFloat(double width, double height);
  void OpenFloat(const flutter::EncodableValue& args);
  void DestroyFloat();
  void NotifyMain(const std::string& method, const flutter::EncodableValue* args);
  void HandleFloatCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  HWND hwnd_;
  flutter::DartProject project_;
  flutter::BinaryMessenger* main_messenger_ = nullptr;

  HWND float_hwnd_ = nullptr;
  std::unique_ptr<flutter::FlutterViewController> float_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> float_channel_;
  flutter::EncodableValue pending_open_;
  bool has_pending_open_ = false;
  bool float_ready_ = false;
};

#endif  // RUNNER_DESKTOP_PIP_CHANNEL_H_
