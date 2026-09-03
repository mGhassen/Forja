#!/usr/bin/env node
/**
 * Smoke: signed-in Community Packs profile action mirrors isPackInstalled.
 * (No vitest in apps/web — keep this tiny + node:test.)
 */
import assert from 'node:assert/strict'
import { test } from 'node:test'

function isPackInstalled(packs, manifestUrl) {
  const want = manifestUrl.trim()
  return packs.some((pack) => pack.manifestUrl.trim() === want)
}

function profileAction(onProfile) {
  return onProfile ? 'remove' : 'add'
}

test('not on profile → cloud add', () => {
  const packs = [{ manifestUrl: 'https://cdn.example/a/manifest.json' }]
  const onProfile = isPackInstalled(packs, 'https://cdn.example/b/manifest.json')
  assert.equal(onProfile, false)
  assert.equal(profileAction(onProfile), 'add')
})

test('on profile → trash remove', () => {
  const packs = [{ manifestUrl: ' https://cdn.example/a/manifest.json ' }]
  const onProfile = isPackInstalled(packs, 'https://cdn.example/a/manifest.json')
  assert.equal(onProfile, true)
  assert.equal(profileAction(onProfile), 'remove')
})
