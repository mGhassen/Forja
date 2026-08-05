#include "desktop_pip_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <utility>

namespace {

RECT WorkAreaFor(HWND hwnd) {
  MONITORINFO mi{};
  mi.cbSize = sizeof(mi);
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  if (monitor != nullptr && GetMonitorInfo(monitor, &mi)) {
    return mi.rcWork;
  }
  RECT work{};
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0);
  return work;
}

void DockBottomRight(HWND hwnd) {
  if (hwnd == nullptr || !IsWindow(hwnd)) return;
  RECT frame{};
  GetWindowRect(hwnd, &frame);
  const int width = frame.right - frame.left;
  const int height = frame.bottom - frame.top;
  const RECT work = WorkAreaFor(hwnd);
  constexpr int pad = 12;
  SetWindowPos(hwnd, HWND_TOPMOST, work.right - width - pad,
               work.bottom - height - pad, width, height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

flutter::EncodableMap VisibleFramePayload(HWND hwnd) {
  const RECT work = WorkAreaFor(hwnd);
  return flutter::EncodableMap{
      {flutter::EncodableValue("x"),
       flutter::EncodableValue(static_cast<double>(work.left))},
      {flutter::EncodableValue("y"),
       flutter::EncodableValue(static_cast<double>(work.top))},
      {flutter::EncodableValue("width"),
       flutter::EncodableValue(static_cast<double>(work.right - work.left))},
      {flutter::EncodableValue("height"),
       flutter::EncodableValue(static_cast<double>(work.bottom - work.top))},
  };
}

}  // namespace

std::unique_ptr<DesktopPipChannel> DesktopPipChannel::Register(
    flutter::BinaryMessenger* messenger, HWND hwnd) {
  auto channel = std::make_unique<DesktopPipChannel>(hwnd);
  DesktopPipChannel* raw = channel.get();

  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "forja/desktop_pip",
          &flutter::StandardMethodCodec::GetInstance());

  method_channel->SetMethodCallHandler(
      [raw](const flutter::MethodCall<flutter::EncodableValue>& call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                result) {
        const auto& method = call.method_name();
        if (method == "setEnabled") {
          // Dart/window_manager owns always-on-top; nothing extra required.
          result->Success();
        } else if (method == "dockBottomRight") {
          DockBottomRight(raw->hwnd());
          result->Success();
        } else if (method == "visibleFrame") {
          result->Success(VisibleFramePayload(raw->hwnd()));
        } else {
          result->NotImplemented();
        }
      });

  method_channel.release();
  return channel;
}

DesktopPipChannel::DesktopPipChannel(HWND hwnd) : hwnd_(hwnd) {}
