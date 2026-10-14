#include "desktop_pip_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

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

const wchar_t kFloatClass[] = L"ForjaPipFloatWindow";

LRESULT CALLBACK FloatWndProc(HWND hwnd, UINT msg, WPARAM wparam,
                              LPARAM lparam) {
  switch (msg) {
    case WM_DESTROY:
      return 0;
    case WM_NCHITTEST: {
      // Allow drag from client area when Flutter does not claim it.
      LRESULT hit = DefWindowProc(hwnd, msg, wparam, lparam);
      if (hit == HTCLIENT) return HTCAPTION;
      return hit;
    }
    default:
      return DefWindowProc(hwnd, msg, wparam, lparam);
  }
}

void EnsureFloatClass() {
  static bool registered = false;
  if (registered) return;
  WNDCLASSW wc{};
  wc.lpfnWndProc = FloatWndProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.lpszClassName = kFloatClass;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = reinterpret_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
  RegisterClassW(&wc);
  registered = true;
}

}  // namespace

std::unique_ptr<DesktopPipChannel> DesktopPipChannel::Register(
    flutter::BinaryMessenger* messenger, HWND hwnd,
    const flutter::DartProject& project) {
  auto channel = std::make_unique<DesktopPipChannel>(hwnd, project);
  DesktopPipChannel* raw = channel.get();
  raw->main_messenger_ = messenger;

  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "forja/desktop_pip",
          &flutter::StandardMethodCodec::GetInstance());

  method_channel->SetMethodCallHandler(
      [raw](const flutter::MethodCall<flutter::EncodableValue>& call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                result) {
        const auto& method = call.method_name();
        if (method == "createFloat") {
          double width = 360;
          double height = 203;
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args != nullptr) {
            auto w = args->find(flutter::EncodableValue("width"));
            auto h = args->find(flutter::EncodableValue("height"));
            if (w != args->end() && std::holds_alternative<double>(w->second)) {
              width = std::get<double>(w->second);
            }
            if (h != args->end() && std::holds_alternative<double>(h->second)) {
              height = std::get<double>(h->second);
            }
          }
          result->Success(flutter::EncodableValue(raw->CreateFloat(width, height)));
        } else if (method == "openFloat") {
          if (call.arguments() != nullptr) {
            raw->OpenFloat(*call.arguments());
          }
          result->Success();
        } else if (method == "destroyFloat") {
          raw->DestroyFloat();
          result->Success();
        } else if (method == "setEnabled" || method == "enterPip" ||
                   method == "dockBottomRight" ||
                   method == "setSpaceLeavePrepAllowed" ||
                   method == "cancelSpaceLeavePrep") {
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

DesktopPipChannel::DesktopPipChannel(HWND hwnd,
                                     const flutter::DartProject& project)
    : hwnd_(hwnd), project_(project) {}

DesktopPipChannel::~DesktopPipChannel() { DestroyFloat(); }

bool DesktopPipChannel::CreateFloat(double width, double height) {
  DestroyFloat();
  EnsureFloatClass();

  const RECT work = WorkAreaFor(hwnd_);
  constexpr int pad = 12;
  const int w = static_cast<int>(width);
  const int h = static_cast<int>(height);
  const int x = work.right - w - pad;
  const int y = work.bottom - h - pad;

  float_hwnd_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_APPWINDOW,
      kFloatClass, L"Forja PiP", WS_POPUP | WS_VISIBLE | WS_THICKFRAME, x, y, w,
      h, nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
  if (float_hwnd_ == nullptr) {
    return false;
  }

  flutter::DartProject float_project = project_;
  float_project.set_dart_entrypoint("pipFloatMain");

  float_controller_ = std::make_unique<flutter::FlutterViewController>(
      w, h, float_project);
  if (!float_controller_->engine() || !float_controller_->view()) {
    DestroyFloat();
    return false;
  }
  RegisterPlugins(float_controller_->engine());

  SetParent(float_controller_->view()->GetNativeWindow(), float_hwnd_);
  MoveWindow(float_controller_->view()->GetNativeWindow(), 0, 0, w, h, TRUE);
  ShowWindow(float_hwnd_, SW_SHOWNOACTIVATE);
  SetWindowPos(float_hwnd_, HWND_TOPMOST, x, y, w, h,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);

  float_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          float_controller_->engine()->messenger(), "forja/pip_float",
          &flutter::StandardMethodCodec::GetInstance());
  float_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleFloatCall(call, std::move(result));
      });

  float_ready_ = false;
  return true;
}

void DesktopPipChannel::OpenFloat(const flutter::EncodableValue& args) {
  pending_open_ = args;
  has_pending_open_ = true;
  if (float_ready_ && float_channel_) {
    float_channel_->InvokeMethod("open",
                                 std::make_unique<flutter::EncodableValue>(args));
    has_pending_open_ = false;
  }
}

void DesktopPipChannel::DestroyFloat() {
  if (float_channel_) {
    float_channel_->InvokeMethod("teardown", nullptr);
    float_channel_.reset();
  }
  float_controller_.reset();
  if (float_hwnd_ != nullptr) {
    DestroyWindow(float_hwnd_);
    float_hwnd_ = nullptr;
  }
  has_pending_open_ = false;
  float_ready_ = false;
}

void DesktopPipChannel::NotifyMain(
    const std::string& method, const flutter::EncodableValue* args) {
  if (main_messenger_ == nullptr) return;
  flutter::MethodChannel<flutter::EncodableValue> channel(
      main_messenger_, "forja/desktop_pip",
      &flutter::StandardMethodCodec::GetInstance());
  if (args != nullptr) {
    channel.InvokeMethod(
        method, std::make_unique<flutter::EncodableValue>(*args));
  } else {
    channel.InvokeMethod(method, nullptr);
  }
}

void DesktopPipChannel::HandleFloatCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = call.method_name();
  if (method == "floatReady") {
    float_ready_ = true;
    if (has_pending_open_ && float_channel_) {
      float_channel_->InvokeMethod(
          "open",
          std::make_unique<flutter::EncodableValue>(pending_open_));
      has_pending_open_ = false;
    }
    result->Success();
  } else if (method == "expand") {
    NotifyMain("floatExpand", call.arguments());
    result->Success();
  } else if (method == "close") {
    NotifyMain("floatClose", nullptr);
    result->Success();
  } else if (method == "minimize") {
    if (float_hwnd_ != nullptr) {
      ShowWindow(float_hwnd_, SW_MINIMIZE);
    }
    result->Success();
  } else if (method == "startDrag") {
    // WS_THICKFRAME + HTCAPTION hit-test handles drag.
    result->Success();
  } else {
    result->NotImplemented();
  }
}
