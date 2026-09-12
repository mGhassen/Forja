#ifndef RUNNER_FORJA_VLC_CHANNEL_H_
#define RUNNER_FORJA_VLC_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/texture_registrar.h>

#include <memory>

class ForjaVlcChannel {
 public:
  static std::unique_ptr<ForjaVlcChannel> Register(
      flutter::BinaryMessenger* messenger,
      flutter::TextureRegistrar* textures);

  ForjaVlcChannel(flutter::BinaryMessenger* messenger,
                  flutter::TextureRegistrar* textures);
  ~ForjaVlcChannel();

  ForjaVlcChannel(const ForjaVlcChannel&) = delete;
  ForjaVlcChannel& operator=(const ForjaVlcChannel&) = delete;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_FORJA_VLC_CHANNEL_H_
