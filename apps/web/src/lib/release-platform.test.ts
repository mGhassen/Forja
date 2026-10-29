/// <reference types="node" />
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { detectPlatformFromFilename } from './release-platform.ts'

describe('detectPlatformFromFilename', () => {
  it('classifies phone APKs as android_mobile', () => {
    assert.equal(
      detectPlatformFromFilename('Forja-1.4.0-android-mobile-arm64.apk'),
      'android_mobile',
    )
    assert.equal(
      detectPlatformFromFilename('Forja-1.4.0-android-mobile-armeabi-v7a.apk'),
      'android_mobile',
    )
    assert.equal(
      detectPlatformFromFilename('forja_1.4.0_android_mobile_arm64.apk'),
      'android_mobile',
    )
  })

  it('classifies TV APKs as android_tv', () => {
    assert.equal(
      detectPlatformFromFilename('Forja-1.4.0-android-tv-arm64.apk'),
      'android_tv',
    )
    assert.equal(
      detectPlatformFromFilename('Forja-1.4.0-android-tv-armeabi-v7a.apk'),
      'android_tv',
    )
  })

  it('keeps unlabelled APKs from older releases on android_tv', () => {
    assert.equal(detectPlatformFromFilename('Forja-1.2.300-arm64.apk'), 'android_tv')
    assert.equal(detectPlatformFromFilename('Forja-1.2.300-android.apk'), 'android_tv')
  })

  it('never classifies a TV APK as a phone APK, or the reverse', () => {
    for (const abi of ['arm64', 'armeabi-v7a']) {
      assert.notEqual(
        detectPlatformFromFilename(`Forja-2.0.0-android-tv-${abi}.apk`),
        'android_mobile',
      )
      assert.notEqual(
        detectPlatformFromFilename(`Forja-2.0.0-android-mobile-${abi}.apk`),
        'android_tv',
      )
    }
  })

  it('leaves desktop installers on their platforms', () => {
    assert.equal(detectPlatformFromFilename('Forja-1.4.0-windows-x86_64.exe'), 'windows')
    assert.equal(detectPlatformFromFilename('Forja-1.4.0-macos-arm64.dmg'), 'macos')
    assert.equal(detectPlatformFromFilename('Forja-1.4.0-linux-x86_64.AppImage'), 'linux')
    assert.equal(detectPlatformFromFilename('manifest.json'), 'other')
  })
})
