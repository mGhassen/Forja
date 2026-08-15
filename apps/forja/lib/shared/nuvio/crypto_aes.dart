import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES for the scraper CryptoJS host. Hex in / hex out — never utf8.
String aesHex({
  required String mode,
  required String keyHex,
  required String ivHex,
  required String dataHex,
  required bool encrypt,
}) {
  final key = bytesFromHex(keyHex);
  if (key.length != 16 && key.length != 24 && key.length != 32) {
    throw ArgumentError('AES key must be 16, 24, or 32 bytes');
  }
  final iv = bytesFromHex(ivHex);
  final data = bytesFromHex(dataHex);
  final normalized = mode.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final noPadding = normalized.contains('NOPADDING');
  final Uint8List out;
  if (normalized.contains('GCM')) {
    out = _gcm(encrypt, key, iv, data);
  } else if (normalized.contains('ECB')) {
    out = _ecb(encrypt, key, data, pkcs7: !noPadding);
  } else {
    out = _cbc(encrypt, key, iv, data, pkcs7: !noPadding);
  }
  return hexFromBytes(out);
}

Uint8List bytesFromHex(String hex) {
  final cleaned = hex.trim().toLowerCase().replaceAll(' ', '');
  if (cleaned.isEmpty) return Uint8List(0);
  final even = cleaned.length.isEven ? cleaned : '0$cleaned';
  final out = Uint8List(even.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final v = int.tryParse(even.substring(i * 2, i * 2 + 2), radix: 16);
    if (v == null) throw FormatException('invalid hex');
    out[i] = v;
  }
  return out;
}

String hexFromBytes(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

Uint8List _cbc(
  bool encrypt,
  Uint8List key,
  Uint8List iv,
  Uint8List data, {
  required bool pkcs7,
}) {
  if (iv.length != 16) {
    throw ArgumentError('AES-CBC requires a 16-byte IV');
  }
  final input = encrypt && pkcs7 ? _pkcs7Pad(data, 16) : data;
  if (input.length % 16 != 0) {
    throw ArgumentError('AES-CBC input must be a multiple of 16 bytes');
  }
  final cipher = CBCBlockCipher(AESEngine())
    ..init(encrypt, ParametersWithIV(KeyParameter(key), iv));
  final out = _processBlocks(cipher, input);
  return !encrypt && pkcs7 ? _pkcs7Unpad(out, 16) : out;
}

Uint8List _ecb(
  bool encrypt,
  Uint8List key,
  Uint8List data, {
  required bool pkcs7,
}) {
  final input = encrypt && pkcs7 ? _pkcs7Pad(data, 16) : data;
  if (input.length % 16 != 0) {
    throw ArgumentError('AES-ECB input must be a multiple of 16 bytes');
  }
  final cipher = ECBBlockCipher(AESEngine())..init(encrypt, KeyParameter(key));
  final out = _processBlocks(cipher, input);
  return !encrypt && pkcs7 ? _pkcs7Unpad(out, 16) : out;
}

Uint8List _gcm(bool encrypt, Uint8List key, Uint8List iv, Uint8List data) {
  if (iv.isEmpty) throw ArgumentError('AES-GCM requires an IV');
  final gcm = GCMBlockCipher(AESEngine())
    ..init(encrypt, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  return gcm.process(data);
}

Uint8List _processBlocks(BlockCipher cipher, Uint8List input) {
  final out = Uint8List(input.length);
  final n = cipher.blockSize;
  for (var offset = 0; offset < input.length; offset += n) {
    cipher.processBlock(input, offset, out, offset);
  }
  return out;
}

Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
  final padLen = blockSize - (data.length % blockSize);
  final out = Uint8List(data.length + padLen)..setAll(0, data);
  out.fillRange(data.length, out.length, padLen);
  return out;
}

Uint8List _pkcs7Unpad(Uint8List data, int blockSize) {
  if (data.isEmpty || data.length % blockSize != 0) {
    throw FormatException('invalid padded data');
  }
  final padLen = data.last;
  if (padLen <= 0 || padLen > blockSize) {
    throw FormatException('invalid pkcs7 padding');
  }
  for (var i = data.length - padLen; i < data.length; i++) {
    if (data[i] != padLen) throw FormatException('invalid pkcs7 padding');
  }
  return Uint8List.sublistView(data, 0, data.length - padLen);
}
