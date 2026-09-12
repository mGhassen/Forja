#include "forja_vlc_channel.h"

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <atomic>
#include <cstring>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

#include <windows.h>

namespace {

using libvlc_instance_t = struct libvlc_instance_t;
using libvlc_media_t = struct libvlc_media_t;
using libvlc_media_player_t = struct libvlc_media_player_t;

using FnNew = libvlc_instance_t* (*)(int, const char* const*);
using FnRelease = void (*)(libvlc_instance_t*);
using FnMediaNew = libvlc_media_t* (*)(libvlc_instance_t*, const char*);
using FnMediaRelease = void (*)(libvlc_media_t*);
using FnMediaAddOption = void (*)(libvlc_media_t*, const char*);
using FnPlayerNew = libvlc_media_player_t* (*)(libvlc_instance_t*);
using FnPlayerRelease = void (*)(libvlc_media_player_t*);
using FnPlayerSetMedia = void (*)(libvlc_media_player_t*, libvlc_media_t*);
using FnPlayerPlay = int (*)(libvlc_media_player_t*);
using FnPlayerStop = void (*)(libvlc_media_player_t*);
using FnPlayerSetPause = void (*)(libvlc_media_player_t*, int);
using FnAudioSetVolume = int (*)(libvlc_media_player_t*, int);
using FnVideoSetFormat = void (*)(libvlc_media_player_t*, const char*, unsigned,
                                  unsigned, unsigned);
using FnVideoSetCallbacks = void (*)(
    libvlc_media_player_t*, void* (*)(void*, void**),
    void (*)(void*, void*, void* const*), void (*)(void*, void*), void*);

struct VlcApi {
  HMODULE module = nullptr;
  libvlc_instance_t* instance = nullptr;
  FnNew libvlc_new = nullptr;
  FnRelease libvlc_release = nullptr;
  FnMediaNew media_new = nullptr;
  FnMediaRelease media_release = nullptr;
  FnMediaAddOption media_add_option = nullptr;
  FnPlayerNew player_new = nullptr;
  FnPlayerRelease player_release = nullptr;
  FnPlayerSetMedia player_set_media = nullptr;
  FnPlayerPlay player_play = nullptr;
  FnPlayerStop player_stop = nullptr;
  FnPlayerSetPause player_set_pause = nullptr;
  FnAudioSetVolume audio_set_volume = nullptr;
  FnVideoSetFormat video_set_format = nullptr;
  FnVideoSetCallbacks video_set_callbacks = nullptr;

  bool Load() {
    const wchar_t* candidates[] = {
        L"C:\\Program Files\\VideoLAN\\VLC\\libvlc.dll",
        L"C:\\Program Files (x86)\\VideoLAN\\VLC\\libvlc.dll",
        L"libvlc.dll",
    };
    for (const wchar_t* path : candidates) {
      module = LoadLibraryW(path);
      if (module) break;
    }
    if (!module) return false;

    libvlc_new = reinterpret_cast<FnNew>(GetProcAddress(module, "libvlc_new"));
    libvlc_release =
        reinterpret_cast<FnRelease>(GetProcAddress(module, "libvlc_release"));
    media_new = reinterpret_cast<FnMediaNew>(
        GetProcAddress(module, "libvlc_media_new_location"));
    media_release = reinterpret_cast<FnMediaRelease>(
        GetProcAddress(module, "libvlc_media_release"));
    media_add_option = reinterpret_cast<FnMediaAddOption>(
        GetProcAddress(module, "libvlc_media_add_option"));
    player_new = reinterpret_cast<FnPlayerNew>(
        GetProcAddress(module, "libvlc_media_player_new"));
    player_release = reinterpret_cast<FnPlayerRelease>(
        GetProcAddress(module, "libvlc_media_player_release"));
    player_set_media = reinterpret_cast<FnPlayerSetMedia>(
        GetProcAddress(module, "libvlc_media_player_set_media"));
    player_play = reinterpret_cast<FnPlayerPlay>(
        GetProcAddress(module, "libvlc_media_player_play"));
    player_stop = reinterpret_cast<FnPlayerStop>(
        GetProcAddress(module, "libvlc_media_player_stop"));
    player_set_pause = reinterpret_cast<FnPlayerSetPause>(
        GetProcAddress(module, "libvlc_media_player_set_pause"));
    audio_set_volume = reinterpret_cast<FnAudioSetVolume>(
        GetProcAddress(module, "libvlc_audio_set_volume"));
    video_set_format = reinterpret_cast<FnVideoSetFormat>(
        GetProcAddress(module, "libvlc_video_set_format"));
    video_set_callbacks = reinterpret_cast<FnVideoSetCallbacks>(
        GetProcAddress(module, "libvlc_video_set_callbacks"));

    if (!libvlc_new || !media_new || !player_new || !video_set_callbacks ||
        !video_set_format) {
      return false;
    }
    instance = libvlc_new(0, nullptr);
    return instance != nullptr;
  }
};

struct VlcSession {
  flutter::TextureRegistrar* textures = nullptr;
  std::unique_ptr<flutter::TextureVariant> texture;
  int64_t texture_id = -1;
  int64_t view_id = -1;
  libvlc_media_player_t* player = nullptr;
  VlcApi* api = nullptr;

  std::mutex mu;
  std::vector<uint8_t> front;
  std::vector<uint8_t> back;
  unsigned width = 1280;
  unsigned height = 720;
  FlutterDesktopPixelBuffer pixel_buffer{};

  explicit VlcSession(flutter::TextureRegistrar* registrar) : textures(registrar) {
    texture = std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
        [this](size_t, size_t) -> const FlutterDesktopPixelBuffer* {
          std::lock_guard<std::mutex> lock(mu);
          if (front.empty()) return nullptr;
          pixel_buffer.buffer = front.data();
          pixel_buffer.width = width;
          pixel_buffer.height = height;
          return &pixel_buffer;
        }));
    texture_id = textures->RegisterTexture(texture.get());
  }

  ~VlcSession() {
    DisposePlayer();
    if (textures && texture_id >= 0) {
      textures->UnregisterTexture(texture_id);
    }
  }

  static void* Lock(void* opaque, void** planes) {
    auto* self = static_cast<VlcSession*>(opaque);
    std::lock_guard<std::mutex> lock(self->mu);
    const size_t bytes =
        static_cast<size_t>(self->width) * self->height * 4;
    if (self->back.size() != bytes) self->back.assign(bytes, 0);
    *planes = self->back.data();
    return nullptr;
  }

  static void Unlock(void*, void*, void* const*) {}

  static void Display(void* opaque, void*) {
    auto* self = static_cast<VlcSession*>(opaque);
    {
      std::lock_guard<std::mutex> lock(self->mu);
      self->front.swap(self->back);
    }
    if (self->textures && self->texture_id >= 0) {
      self->textures->MarkTextureFrameAvailable(self->texture_id);
    }
  }

  void DisposePlayer() {
    if (player && api) {
      api->player_stop(player);
      api->player_release(player);
    }
    player = nullptr;
  }
};

}  // namespace

struct ForjaVlcChannel::Impl {
  flutter::BinaryMessenger* messenger = nullptr;
  flutter::TextureRegistrar* textures = nullptr;
  VlcApi api;
  bool available = false;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink;
  std::unordered_map<int64_t, std::unique_ptr<VlcSession>> sessions;

  void Emit(int64_t view_id, const std::string& type,
            flutter::EncodableValue value = flutter::EncodableValue()) {
    if (!event_sink) return;
    flutter::EncodableMap map = {
        {flutter::EncodableValue("viewId"), flutter::EncodableValue(view_id)},
        {flutter::EncodableValue("type"), flutter::EncodableValue(type)},
    };
    if (!value.IsNull()) {
      map[flutter::EncodableValue("value")] = std::move(value);
    }
    event_sink->Success(flutter::EncodableValue(map));
  }
};

std::unique_ptr<ForjaVlcChannel> ForjaVlcChannel::Register(
    flutter::BinaryMessenger* messenger,
    flutter::TextureRegistrar* textures) {
  return std::make_unique<ForjaVlcChannel>(messenger, textures);
}

ForjaVlcChannel::ForjaVlcChannel(flutter::BinaryMessenger* messenger,
                                 flutter::TextureRegistrar* textures)
    : impl_(std::make_unique<Impl>()) {
  impl_->messenger = messenger;
  impl_->textures = textures;
  impl_->available = impl_->api.Load();

  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.forjahq.app/vlc",
          &flutter::StandardMethodCodec::GetInstance());

  method_channel->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        auto get_int64 = [&](const char* key) -> int64_t {
          if (!args) return -1;
          auto it = args->find(flutter::EncodableValue(key));
          if (it == args->end()) return -1;
          if (const auto* i = std::get_if<int32_t>(&it->second)) return *i;
          if (const auto* i = std::get_if<int64_t>(&it->second)) return *i;
          return -1;
        };

        if (call.method_name() == "isAvailable") {
          result->Success(flutter::EncodableValue(impl_->available));
          return;
        }
        if (!impl_->available) {
          result->Error("unavailable", "libVLC not found — install VLC");
          return;
        }

        const int64_t view_id = get_int64("viewId");

        if (call.method_name() == "create") {
          auto session = std::make_unique<VlcSession>(impl_->textures);
          session->view_id = view_id;
          session->api = &impl_->api;
          const int64_t tex = session->texture_id;
          impl_->sessions[view_id] = std::move(session);
          result->Success(flutter::EncodableValue(tex));
          return;
        }

        if (call.method_name() == "open") {
          auto it = impl_->sessions.find(view_id);
          if (it == impl_->sessions.end()) {
            result->Error("missing", "call create first");
            return;
          }
          std::string url;
          if (args) {
            auto uit = args->find(flutter::EncodableValue("url"));
            if (uit != args->end()) {
              if (const auto* s = std::get_if<std::string>(&uit->second)) {
                url = *s;
              }
            }
          }
          auto* session = it->second.get();
          session->DisposePlayer();
          auto* media = impl_->api.media_new(impl_->api.instance, url.c_str());
          if (!media) {
            result->Error("open_failed", "media_new failed");
            return;
          }
          if (args) {
            auto hit = args->find(flutter::EncodableValue("headers"));
            if (hit != args->end()) {
              if (const auto* map =
                      std::get_if<flutter::EncodableMap>(&hit->second)) {
                auto ua = map->find(flutter::EncodableValue("User-Agent"));
                if (ua == map->end()) {
                  ua = map->find(flutter::EncodableValue("user-agent"));
                }
                if (ua != map->end()) {
                  if (const auto* s = std::get_if<std::string>(&ua->second)) {
                    std::string opt = ":http-user-agent=" + *s;
                    impl_->api.media_add_option(media, opt.c_str());
                  }
                }
              }
            }
          }
          session->player = impl_->api.player_new(impl_->api.instance);
          impl_->api.video_set_callbacks(session->player, VlcSession::Lock,
                                         VlcSession::Unlock, VlcSession::Display,
                                         session);
          impl_->api.video_set_format(session->player, "RV32", session->width,
                                      session->height, session->width * 4);
          impl_->api.player_set_media(session->player, media);
          impl_->api.media_release(media);
          impl_->Emit(view_id, "buffering", flutter::EncodableValue(true));
          impl_->api.player_play(session->player);
          impl_->Emit(view_id, "ready");
          impl_->Emit(view_id, "playing", flutter::EncodableValue(true));
          result->Success();
          return;
        }

        if (call.method_name() == "play") {
          auto it = impl_->sessions.find(view_id);
          if (it != impl_->sessions.end() && it->second->player) {
            impl_->api.player_set_pause(it->second->player, 0);
          }
          result->Success();
          return;
        }
        if (call.method_name() == "pause") {
          auto it = impl_->sessions.find(view_id);
          if (it != impl_->sessions.end() && it->second->player) {
            impl_->api.player_set_pause(it->second->player, 1);
          }
          result->Success();
          return;
        }
        if (call.method_name() == "setVolume") {
          int vol = 100;
          if (args) {
            auto vit = args->find(flutter::EncodableValue("volume"));
            if (vit != args->end()) {
              if (const auto* i = std::get_if<int32_t>(&vit->second)) vol = *i;
            }
          }
          auto it = impl_->sessions.find(view_id);
          if (it != impl_->sessions.end() && it->second->player) {
            impl_->api.audio_set_volume(it->second->player, vol);
          }
          result->Success();
          return;
        }
        if (call.method_name() == "dispose") {
          impl_->sessions.erase(view_id);
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  method_channel.release();

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          messenger, "com.forjahq.app/vlc_events",
          &flutter::StandardMethodCodec::GetInstance());
  event_channel->SetStreamHandler(
      std::make_unique<
          flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const flutter::EncodableValue*,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
                    && sink)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            impl_->event_sink = std::move(sink);
            return nullptr;
          },
          [this](const flutter::EncodableValue*)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            impl_->event_sink.reset();
            return nullptr;
          }));
  event_channel.release();
}

ForjaVlcChannel::~ForjaVlcChannel() {
  if (impl_) {
    impl_->sessions.clear();
    if (impl_->api.instance && impl_->api.libvlc_release) {
      impl_->api.libvlc_release(impl_->api.instance);
    }
    if (impl_->api.module) {
      FreeLibrary(impl_->api.module);
    }
  }
}
