#ifndef RUNNER_DESKTOP_SPACE_CHANNEL_H_
#define RUNNER_DESKTOP_SPACE_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/event_sink.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <windows.h>

// Watches Win10/11 virtual-desktop switches and streams
// {onActiveSpace: bool} on forja/desktop_space.
class DesktopSpaceChannel {
 public:
  static std::unique_ptr<DesktopSpaceChannel> Register(
      flutter::BinaryMessenger* messenger, HWND hwnd);

  explicit DesktopSpaceChannel(HWND hwnd);
  ~DesktopSpaceChannel();

  DesktopSpaceChannel(const DesktopSpaceChannel&) = delete;
  DesktopSpaceChannel& operator=(const DesktopSpaceChannel&) = delete;

  void SetEventSink(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);
  void ClearEventSink();
  void OnDesktopSwitch();

 private:
  bool IsWindowOnCurrentVirtualDesktop() const;

  HWND hwnd_;
  HWINEVENTHOOK hook_ = nullptr;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
};

#endif  // RUNNER_DESKTOP_SPACE_CHANNEL_H_
