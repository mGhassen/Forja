#include "desktop_space_channel.h"

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <shobjidl.h>
#include <windows.h>

#include <utility>

namespace {

DesktopSpaceChannel* g_channel = nullptr;

void CALLBACK WinEventProc(HWINEVENTHOOK /*hook*/,
                           DWORD event,
                           HWND /*hwnd*/,
                           LONG /*idObject*/,
                           LONG /*idChild*/,
                           DWORD /*idEventThread*/,
                           DWORD /*dwmsEventTime*/) {
  if (event != EVENT_SYSTEM_DESKTOPSWITCH || g_channel == nullptr) {
    return;
  }
  g_channel->OnDesktopSwitch();
}

}  // namespace

std::unique_ptr<DesktopSpaceChannel> DesktopSpaceChannel::Register(
    flutter::BinaryMessenger* messenger, HWND hwnd) {
  auto channel = std::make_unique<DesktopSpaceChannel>(hwnd);
  g_channel = channel.get();

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          messenger, "forja/desktop_space",
          &flutter::StandardMethodCodec::GetInstance());

  DesktopSpaceChannel* raw = channel.get();
  event_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [raw](const flutter::EncodableValue* /*arguments*/,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                    events)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            raw->SetEventSink(std::move(events));
            return nullptr;
          },
          [raw](const flutter::EncodableValue* /*arguments*/)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            raw->ClearEventSink();
            return nullptr;
          }));

  // Keep the EventChannel alive for the process lifetime by leaking it —
  // runner has no other owner, and Flutter tears the messenger down on exit.
  event_channel.release();
  return channel;
}

DesktopSpaceChannel::DesktopSpaceChannel(HWND hwnd) : hwnd_(hwnd) {
  hook_ = SetWinEventHook(EVENT_SYSTEM_DESKTOPSWITCH, EVENT_SYSTEM_DESKTOPSWITCH,
                          nullptr, WinEventProc, 0, 0,
                          WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
}

DesktopSpaceChannel::~DesktopSpaceChannel() {
  if (g_channel == this) {
    g_channel = nullptr;
  }
  if (hook_ != nullptr) {
    UnhookWinEvent(hook_);
    hook_ = nullptr;
  }
}

void DesktopSpaceChannel::SetEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink) {
  sink_ = std::move(sink);
}

void DesktopSpaceChannel::ClearEventSink() { sink_.reset(); }

void DesktopSpaceChannel::OnDesktopSwitch() {
  if (sink_ == nullptr) {
    return;
  }
  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("onActiveSpace")] =
      flutter::EncodableValue(IsWindowOnCurrentVirtualDesktop());
  sink_->Success(flutter::EncodableValue(payload));
}

bool DesktopSpaceChannel::IsWindowOnCurrentVirtualDesktop() const {
  if (hwnd_ == nullptr || !IsWindow(hwnd_)) {
    return false;
  }

  IVirtualDesktopManager* manager = nullptr;
  const HRESULT hr =
      CoCreateInstance(CLSID_VirtualDesktopManager, nullptr, CLSCTX_ALL,
                       IID_PPV_ARGS(&manager));
  if (FAILED(hr) || manager == nullptr) {
    // Fallback: treat a visible top-level window as on the active desktop.
    return IsWindowVisible(hwnd_) != FALSE;
  }

  BOOL on_current = FALSE;
  const HRESULT query_hr =
      manager->IsWindowOnCurrentVirtualDesktop(hwnd_, &on_current);
  manager->Release();
  if (FAILED(query_hr)) {
    return IsWindowVisible(hwnd_) != FALSE;
  }
  return on_current != FALSE;
}
