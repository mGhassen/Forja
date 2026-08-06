/** CPU arch used to pick split installers (macOS arm64 vs Intel, etc.). */
export type ClientCpuArch = 'arm64' | 'x86_64'

export type ClientOsPlatform = 'windows' | 'macos' | 'linux' | 'android_tv'
type NavigatorUaData = {
  getHighEntropyValues: (
    hints: string[],
  ) => Promise<{ architecture?: string }>
}

function webglUnmaskedRenderer(): string | null {
  if (typeof document === 'undefined') return null
  try {
    const canvas = document.createElement('canvas')
    const gl =
      canvas.getContext('webgl') || canvas.getContext('experimental-webgl')
    if (!gl || !(gl instanceof WebGLRenderingContext)) return null
    const ext = gl.getExtension('WEBGL_debug_renderer_info')
    if (!ext) return null
    const renderer = gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)
    return typeof renderer === 'string' ? renderer : null
  } catch {
    return null
  }
}

function archFromHint(raw: string | null | undefined): ClientCpuArch | null {
  const a = raw?.trim().toLowerCase() ?? ''
  if (!a) return null
  if (
    a === 'arm' ||
    a === 'arm64' ||
    a === 'aarch64' ||
    a.startsWith('arm')
  ) {
    return 'arm64'
  }
  if (
    a === 'x86' ||
    a === 'x86_64' ||
    a === 'x64' ||
    a === 'amd64' ||
    a.includes('x86')
  ) {
    return 'x86_64'
  }
  return null
}

/** Guess OS for download picker (sync). */
export function guessOsPlatform(): ClientOsPlatform {
  if (typeof navigator === 'undefined') return 'windows'
  const ua = navigator.userAgent.toLowerCase()
  const plat = navigator.platform?.toLowerCase() ?? ''
  if (plat.includes('mac') || ua.includes('mac')) return 'macos'
  if (plat.includes('linux') || ua.includes('linux')) return 'linux'
  return 'windows'
}

/**
 * Guess host CPU arch for installer selection.
 * Prefer UA Client Hints (Chromium); fall back to WebGL renderer (Safari)
 * and UA tokens. `navigator.platform` is useless on Mac (always MacIntel).
 */
export async function guessCpuArch(): Promise<ClientCpuArch | null> {
  if (typeof navigator === 'undefined') return null

  const uaData = (
    navigator as Navigator & { userAgentData?: NavigatorUaData }
  ).userAgentData
  if (uaData?.getHighEntropyValues) {
    try {
      const { architecture } = await uaData.getHighEntropyValues([
        'architecture',
      ])
      const fromHint = archFromHint(architecture)
      if (fromHint) return fromHint
    } catch {
      // Hints denied or unsupported — fall through.
    }
  }

  const renderer = webglUnmaskedRenderer()?.toLowerCase() ?? ''
  if (renderer) {
    // Apple Silicon: "Apple GPU", "Apple M1", … — Intel Macs: Intel / AMD.
    if (renderer.includes('apple')) return 'arm64'
    if (
      renderer.includes('intel') ||
      renderer.includes('amd') ||
      renderer.includes('radeon') ||
      renderer.includes('nvidia')
    ) {
      return 'x86_64'
    }
  }

  const ua = navigator.userAgent.toLowerCase()
  if (ua.includes('aarch64') || ua.includes('arm64')) return 'arm64'
  if (
    ua.includes('x86_64') ||
    ua.includes('win64') ||
    ua.includes('amd64') ||
    ua.includes('x64')
  ) {
    return 'x86_64'
  }
  if (/\barm\b/.test(ua)) return 'arm64'

  return null
}

/** True when an installer filename matches the preferred CPU arch. */
export function filenameMatchesArch(
  name: string,
  arch: ClientCpuArch,
): boolean {
  const n = name.toLowerCase()
  if (arch === 'arm64') {
    // True 64-bit only — armeabi-v7a is 32-bit ARM.
    if (n.includes('armeabi-v7a') || n.includes('armeabi_v7a')) return false
    return n.includes('arm64') || n.includes('aarch64')
  }
  return (
    n.includes('x86_64') ||
    n.includes('x86-64') ||
    n.includes('amd64') ||
    /\bx86\b/.test(n) ||
    n.includes('i686')
  )
}
