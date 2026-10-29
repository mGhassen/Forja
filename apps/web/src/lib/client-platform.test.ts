/// <reference types="node" />
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { guessOsPlatform } from './client-platform.ts'

function withUserAgent(userAgent: string, run: () => void) {
  const original = Object.getOwnPropertyDescriptor(globalThis, 'navigator')
  Object.defineProperty(globalThis, 'navigator', {
    configurable: true,
    value: { userAgent, platform: 'Linux armv8l' },
  })
  try {
    run()
  } finally {
    if (original) Object.defineProperty(globalThis, 'navigator', original)
    else delete (globalThis as { navigator?: unknown }).navigator
  }
}

describe('guessOsPlatform', () => {
  it('sends Android phones to android_mobile', () => {
    withUserAgent(
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36',
      () => assert.equal(guessOsPlatform(), 'android_mobile'),
    )
  })

  it('sends Android TV devices to android_tv', () => {
    for (const ua of [
      'Mozilla/5.0 (Linux; Android 12; Chromecast) AppleWebKit/537.36 Chrome/120.0 Safari/537.36',
      'Mozilla/5.0 (Linux; Android 9; MIBOX4) AppleWebKit/537.36 Chrome/110.0 Safari/537.36',
      'Mozilla/5.0 (Linux; Android 11; SHIELD Android TV) AppleWebKit/537.36 Chrome/118.0 Safari/537.36',
      'Mozilla/5.0 (Linux; Android 9; AFTMM) AppleWebKit/537.36 Silk/100.0 Safari/537.36',
      'Mozilla/5.0 (Linux; Android 10; BRAVIA 4K VH2) AppleWebKit/537.36 Chrome/96.0 Safari/537.36',
    ]) {
      withUserAgent(ua, () => assert.equal(guessOsPlatform(), 'android_tv', ua))
    }
  })
})
