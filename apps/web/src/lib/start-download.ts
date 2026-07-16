/**
 * Start a file download without opening a new tab / navigating away.
 * Uses a hidden iframe so GitHub’s Content-Disposition: attachment
 * is handled in the background (cross-origin `download` attrs are ignored).
 */
export function startBackgroundDownload(url: string): void {
  if (typeof document === 'undefined') return

  const iframe = document.createElement('iframe')
  iframe.setAttribute('aria-hidden', 'true')
  iframe.tabIndex = -1
  iframe.style.cssText =
    'position:fixed;width:0;height:0;border:0;visibility:hidden;pointer-events:none'
  iframe.src = url
  document.body.appendChild(iframe)

  window.setTimeout(() => {
    iframe.remove()
  }, 120_000)
}
