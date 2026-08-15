import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/nuvio/crypto_aes.dart';

void main() {
  const key = '00112233445566778899aabbccddeeff';
  const pt = '{"ok":true}';
  final ptHex = hexFromBytes(utf8.encode(pt));

  test('AES-128-CBC PKCS7 decrypts openssl vector', () {
    const ct = 'ee85473d494b4d2a7c322c5a5ff8210f';
    final hex = aesHex(
      mode: 'AES-CBC',
      keyHex: key,
      ivHex: key,
      dataHex: ct,
      encrypt: false,
    );
    expect(utf8.decode(bytesFromHex(hex)), pt);
  });

  test('AES-128-CBC PKCS7 roundtrip', () {
    final ct = aesHex(
      mode: 'AES-CBC',
      keyHex: key,
      ivHex: key,
      dataHex: ptHex,
      encrypt: true,
    );
    expect(ct, 'ee85473d494b4d2a7c322c5a5ff8210f');
    final back = aesHex(
      mode: 'AES-CBC',
      keyHex: key,
      ivHex: key,
      dataHex: ct,
      encrypt: false,
    );
    expect(back, ptHex);
  });

  test('AES-128-ECB PKCS7 decrypts openssl vector', () {
    const ct = 'eaf3579803b2d9d107b8e67389a83b9b';
    final hex = aesHex(
      mode: 'AES-ECB',
      keyHex: key,
      ivHex: '',
      dataHex: ct,
      encrypt: false,
    );
    expect(utf8.decode(bytesFromHex(hex)), pt);
  });

  test('AES-128-GCM roundtrip', () {
    const iv = '0102030405060708090a0b0c';
    final ct = aesHex(
      mode: 'AES-GCM',
      keyHex: key,
      ivHex: iv,
      dataHex: ptHex,
      encrypt: true,
    );
    final back = aesHex(
      mode: 'AES-GCM',
      keyHex: key,
      ivHex: iv,
      dataHex: ct,
      encrypt: false,
    );
    expect(back, ptHex);
  });
}
