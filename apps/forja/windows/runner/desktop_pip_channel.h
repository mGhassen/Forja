#ifndef RUNNER_DESKTOP_PIP_CHANNEL_H_
#define RUNNER_DESKTOP_PIP_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>

#include <cstdint>
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

  /// TimerProc — float teardown wait timed out, or deferred engine kill.
  void OnDestroyTimer();

  DesktopPipChannel(const DesktopPipChannel&) = delete;
  DesktopPipChannel& operator=(const DesktopPipChannel&) = delete;

 private:
  bool CreateFloat(double width, double height);
  void OpenFloat(const flutter::EncodableValue& args);
  /// Sync kill — CreateFloat re-entry / destructor. Does not await Dart teardown.
  void DestroyFloatImmediate();
  /// Await float media_kit teardown, then kill. Completes [result] when done.
  void DestroyFloatAsync(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void CancelDestroyTimer();
  /// Schedule FinishPendingDestroy on the next timer tick (off MethodResult stack).
  void ScheduleFinishDestroy(uint64_t gen, UINT delay_ms);
  void FinishPendingDestroy();
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

  uint64_t destroy_generation_ = 0;
  /// Generation that the armed timer / deferred finish belongs to.
  uint64_t armed_destroy_generation_ = 0;
  UINT_PTR destroy_timeout_timer_ = 0;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
      pending_destroy_result_;
};

#endif  // RUNNER_DESKTOP_PIP_CHANNEL_H_
