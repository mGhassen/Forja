#ifndef RUNNER_DESKTOP_PIP_CHANNEL_H_
#define RUNNER_DESKTOP_PIP_CHANNEL_H_

#include <flutter/binary_messenger.h>

#include <memory>
#include <windows.h>

class DesktopPipChannel {
 public:
  static std::unique_ptr<DesktopPipChannel> Register(
      flutter::BinaryMessenger* messenger, HWND hwnd);

  explicit DesktopPipChannel(HWND hwnd);
  ~DesktopPipChannel() = default;

  HWND hwnd() const { return hwnd_; }

  DesktopPipChannel(const DesktopPipChannel&) = delete;
  DesktopPipChannel& operator=(const DesktopPipChannel&) = delete;

 private:
  HWND hwnd_;
};

#endif  // RUNNER_DESKTOP_PIP_CHANNEL_H_
