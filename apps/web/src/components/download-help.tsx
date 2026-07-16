import { useCallback, useEffect, useId, useRef, useState } from 'react'
import { Reveal } from '@/components/reveal'
import { cn } from '@/lib/utils'

const FAQ: {
  q: string
  a: string
  guideHref?: string
  guideLabel?: string
}[] = [
  {
    q: 'What is Forja?',
    a: 'Forja is a free app for movies, series, anime, live sport, and live TV — everything in one place so you can relax and watch. Download it for your computer or living-room TV. This site is for getting the app and your account.',
  },
  {
    q: 'Which download should I pick?',
    a: 'Choose the screen you watch on: Windows for PC, macOS for Mac, Linux if that’s your computer, Android TV for the living room. Forja picks a good default when it can — then you just download and open.',
  },
  {
    q: 'Will it run on my machine?',
    a: 'Yes on everyday Windows and Mac computers, most Linux desktops, and Android / Google TV boxes that let you install apps. You’ll need a normal internet connection to browse and watch.',
  },
  {
    q: 'Do I need an account?',
    a: 'No. Download and watch. An account is optional if you want preferences across devices later.',
  },
  {
    q: 'Windows says the app is unrecognized / blocked',
    a: 'Windows often warns on apps it hasn’t seen a lot. That’s caution, not a verdict. If you got Forja from this page, use More info → Run anyway.',
    guideHref: '#windows-smartscreen',
    guideLabel: 'See the photo steps for Windows',
  },
  {
    q: 'Windows shows a red “unsafe” / blocked screen',
    a: 'That’s Microsoft Defender being stricter than the usual blue SmartScreen. If you downloaded Forja from this page, open More information and continue — or restore the file from Windows Security → Virus & threat protection → Protection history if it was quarantined.',
    guideHref: '#windows-smartscreen',
    guideLabel: 'See the photo steps for Windows',
  },
  {
    q: 'Mac says Apple could not verify the app',
    a: 'Mac does this for apps outside the App Store. Open Forja once, then allow it in System Settings → Privacy & Security → Open Anyway.',
    guideHref: '#macos-gatekeeper',
    guideLabel: 'See the photo steps for Mac',
  },
  {
    q: 'Antivirus quarantined the download',
    a: 'Restore or allow the file, then open it again from this downloads page. Only install Forja from here.',
    guideHref: '#windows-smartscreen',
    guideLabel: 'See the Windows photo guide',
  },
  {
    q: 'Anything I should know?',
    a: 'Some networks are picky about streams. Live TV needs your own channel list. On Android TV you may need to allow installing apps. Forja still works great without an account.',
  },
]

type Shot = {
  src: string
  alt: string
  /** Short step label under the image */
  title: string
  /** Simple plain-language explanation */
  body: string
  /** Intrinsic pixels — cards share height; width follows aspect. */
  w: number
  h: number
}

const WINDOWS_SHOTS: Shot[] = [
  {
    src: '/brand/help/windows-01-protected.png',
    alt: 'Windows SmartScreen — Windows protected your PC',
    title: 'Step 1 — Windows stopped the open',
    body: 'You may see “Windows protected your PC.” This is common for new apps. It does not mean Forja is bad. Stay on this screen and go to the next step.',
    w: 1098,
    h: 1035,
  },
  {
    src: '/brand/help/windows-02-more-info.png',
    alt: 'Windows SmartScreen — click More info',
    title: 'Step 2 — Click More info',
    body: 'Under the warning message, click More info. Windows will show you more choices so you can keep going.',
    w: 538,
    h: 514,
  },
  {
    src: '/brand/help/windows-03-run-anyway.jpg',
    alt: 'Windows SmartScreen — Run anyway',
    title: 'Step 3 — Click Run anyway',
    body: 'Now click Run anyway. Forja will start. You only need to do this the first time.',
    w: 1106,
    h: 1046,
  },
  {
    src: '/brand/help/windows-04-on-desktop.jpg',
    alt: 'Windows SmartScreen dialog on the desktop',
    title: 'Step 4 — Same warning on the desktop',
    body: 'If the warning appears on your desktop instead, it is the same thing. Click More info, then Run anyway.',
    w: 1280,
    h: 720,
  },
  {
    src: '/brand/help/windows-05-red-unsafe.png',
    alt: 'Microsoft Defender red screen — reported as unsafe',
    title: 'Step 5 — Red “unsafe” screen',
    body: 'Sometimes Windows shows a red screen instead of blue. Click More information, then continue — only if you downloaded Forja from this page.',
    w: 1258,
    h: 835,
  },
]

const MACOS_SHOTS: Shot[] = [
  {
    src: '/brand/help/macos-blocked-dialog.png',
    alt: 'macOS — Apple could not verify this app',
    title: 'Step 1 — Mac blocks the first open',
    body: 'Mac may say it could not verify the app. That is normal outside the App Store. Click Done. Do not move Forja to the Trash.',
    w: 520,
    h: 464,
  },
  {
    src: '/brand/help/macos-privacy-settings-top.png',
    alt: 'macOS System Settings — Privacy & Security',
    title: 'Step 2 — Open Privacy & Security',
    body: 'Open System Settings, then go to Privacy & Security. You will allow Forja here.',
    w: 1200,
    h: 700,
  },
  {
    src: '/brand/help/macos-open-anyway-closeup.png',
    alt: 'macOS Privacy & Security — Open Anyway',
    title: 'Step 3 — Find Open Anyway',
    body: 'Scroll down to the Security section. You should see a message about Forja with an Open Anyway button.',
    w: 1200,
    h: 700,
  },
  {
    src: '/brand/help/macos-privacy-open-anyway.png',
    alt: 'macOS Privacy & Security full panel with Open Anyway',
    title: 'Step 4 — Allow Forja once',
    body: 'Click Open Anyway, confirm, then type your Mac password (or use Touch ID). After that, Forja opens normally.',
    w: 1430,
    h: 1226,
  },
]

/** Shared media height for all help cards (px). Width scales with image aspect. */
const SHOT_MEDIA_H = 380
const SHOT_PAD_X = 40
const SHOT_MIN_W = 280
const SHOT_MAX_W = 820

function shotCardWidth(shot: Shot): number {
  const mediaW = (SHOT_MEDIA_H * shot.w) / shot.h
  return Math.round(
    Math.min(SHOT_MAX_W, Math.max(SHOT_MIN_W, mediaW + SHOT_PAD_X * 2)),
  )
}

function ShotLightbox({
  shot,
  onClose,
}: {
  shot: Shot
  onClose: () => void
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', onKey)
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = prev
    }
  }, [onClose])

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={shot.alt}
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/88 p-4 sm:p-8"
      onClick={onClose}
    >
      <button
        type="button"
        onClick={onClose}
        className="font-mono-ui absolute top-5 right-5 z-[2] rounded-full border border-white/20 bg-black/50 px-4 py-2 text-[11px] uppercase tracking-[0.14em] text-[#EDE6DA] transition-colors hover:border-brand hover:text-brand"
      >
        Close
      </button>
      <figure
        className="relative flex max-h-[min(92vh,900px)] w-full max-w-5xl flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex min-h-0 flex-1 items-center justify-center overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.2)] bg-[#0a0a0a] p-3 sm:p-6">
          <img
            src={shot.src}
            alt={shot.alt}
            className="max-h-[min(78vh,760px)] w-auto max-w-full object-contain"
          />
        </div>
        <figcaption className="mt-4 space-y-2 text-center">
          <p className="font-disp text-lg uppercase tracking-tight text-[#EDE6DA] sm:text-xl">
            {shot.title}
          </p>
          <p className="mx-auto max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.65)] sm:text-lg">
            {shot.body}
          </p>
        </figcaption>
      </figure>
    </div>
  )
}

/** One big card at a time — slide between steps; click to enlarge. */
function ShotSlider({
  shots,
  accent = 'flame',
}: {
  shots: Shot[]
  accent?: 'flame' | 'brand'
}) {
  const trackRef = useRef<HTMLDivElement>(null)
  const [index, setIndex] = useState(0)
  const [lightbox, setLightbox] = useState<Shot | null>(null)
  const labelId = useId()

  const goTo = useCallback((i: number) => {
    const el = trackRef.current
    if (!el) return
    const clamped = Math.max(0, Math.min(shots.length - 1, i))
    const card = el.children[clamped] as HTMLElement | undefined
    card?.scrollIntoView({ behavior: 'smooth', inline: 'start', block: 'nearest' })
    setIndex(clamped)
  }, [shots.length])

  useEffect(() => {
    const el = trackRef.current
    if (!el) return

    const onScroll = () => {
      const kids = Array.from(el.children) as HTMLElement[]
      if (!kids.length) return
      const mid = el.scrollLeft + el.clientWidth * 0.35
      let best = 0
      let bestDist = Infinity
      kids.forEach((kid, i) => {
        const d = Math.abs(kid.offsetLeft - mid + kid.clientWidth * 0.35)
        if (d < bestDist) {
          bestDist = d
          best = i
        }
      })
      setIndex(best)
    }

    el.addEventListener('scroll', onScroll, { passive: true })
    return () => el.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <div className="mt-10">
      <div className="mb-5 flex flex-wrap items-center justify-between gap-4">
        <p
          id={labelId}
          className={cn(
            'font-mono-ui text-[11px] uppercase tracking-[0.16em]',
            accent === 'flame' ? 'text-flame' : 'text-brand',
          )}
        >
          Step {String(index + 1).padStart(2, '0')} / {String(shots.length).padStart(2, '0')}
          <span className="ml-3 hidden text-[rgba(237,230,218,0.35)] sm:inline">
            · click shot to enlarge
          </span>
          <span className="ml-3 text-[rgba(237,230,218,0.35)] sm:hidden">· tap to enlarge</span>
        </p>
        <div className="flex items-center gap-2">
          <button
            type="button"
            data-hover=""
            aria-label="Previous step"
            disabled={index <= 0}
            onClick={() => goTo(index - 1)}
            className="rounded-full border border-[rgba(237,230,218,0.2)] px-4 py-2 font-mono-ui text-[11px] uppercase tracking-[0.12em] text-[#EDE6DA] transition-colors hover:border-brand hover:text-brand disabled:cursor-not-allowed disabled:opacity-30"
          >
            Prev
          </button>
          <button
            type="button"
            data-hover=""
            aria-label="Next step"
            disabled={index >= shots.length - 1}
            onClick={() => goTo(index + 1)}
            className="rounded-full border border-[rgba(237,230,218,0.2)] px-4 py-2 font-mono-ui text-[11px] uppercase tracking-[0.12em] text-[#EDE6DA] transition-colors hover:border-brand hover:text-brand disabled:cursor-not-allowed disabled:opacity-30"
          >
            Next
          </button>
        </div>
      </div>

      <div
        ref={trackRef}
        role="region"
        aria-labelledby={labelId}
        className="flex snap-x snap-mandatory items-stretch gap-5 overflow-x-auto pb-3 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        style={{ height: SHOT_MEDIA_H + 168 }}
      >
        {shots.map((shot, i) => {
          const cardW = shotCardWidth(shot)
          return (
            <button
              key={shot.src}
              type="button"
              data-hover=""
              onClick={() => setLightbox(shot)}
              style={{ width: `min(92vw, ${cardW}px)` }}
              className={cn(
                'group relative flex h-full shrink-0 snap-start flex-col overflow-hidden rounded-2xl border bg-[#121110] text-left transition-colors',
                i === index
                  ? 'border-[rgba(237,230,218,0.35)]'
                  : 'border-[rgba(237,230,218,0.14)] opacity-80',
              )}
            >
              <div
                className="flex shrink-0 items-center justify-center bg-[#0a0a0a] px-5 sm:px-8"
                style={{ height: SHOT_MEDIA_H }}
              >
                <img
                  src={shot.src}
                  alt={shot.alt}
                  width={shot.w}
                  height={shot.h}
                  className="h-full w-auto max-w-full object-contain object-center transition duration-500 group-hover:scale-[1.02]"
                  loading="lazy"
                  decoding="async"
                  draggable={false}
                />
              </div>
              <div className="mt-auto flex min-h-[10.5rem] flex-col justify-between gap-3 border-t border-[rgba(237,230,218,0.1)] px-5 py-4 sm:min-h-[11rem] sm:px-6 sm:py-5">
                <div className="space-y-2">
                  <p className="font-disp text-base uppercase leading-tight tracking-tight text-[#EDE6DA] sm:text-lg">
                    {shot.title}
                  </p>
                  <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.62)] normal-case sm:text-[15px] sm:leading-relaxed">
                    {shot.body}
                  </p>
                </div>
                <span
                  className={cn(
                    'shrink-0 font-mono-ui text-[10px] uppercase tracking-[0.14em]',
                    accent === 'flame' ? 'text-flame' : 'text-brand',
                  )}
                >
                  Enlarge
                </span>
              </div>
            </button>
          )
        })}
      </div>

      <div className="mt-5 flex justify-center gap-2">
        {shots.map((shot, i) => (
          <button
            key={shot.src}
            type="button"
            aria-label={`Go to step ${i + 1}`}
            aria-current={i === index}
            onClick={() => goTo(i)}
            className={cn(
              'h-1.5 rounded-full transition-all',
              i === index
                ? cn('w-8', accent === 'flame' ? 'bg-flame' : 'bg-brand')
                : 'w-1.5 bg-[rgba(237,230,218,0.25)] hover:bg-[rgba(237,230,218,0.45)]',
            )}
          />
        ))}
      </div>

      {lightbox ? (
        <ShotLightbox shot={lightbox} onClose={() => setLightbox(null)} />
      ) : null}
    </div>
  )
}

export function DownloadHelp() {
  return (
    <div className="mt-20 space-y-20 border-t border-[rgba(237,230,218,0.14)] pt-16">
      <section id="faq">
        <Reveal>
          <h2 className="font-disp text-[clamp(32px,5vw,52px)] uppercase leading-[0.95] tracking-[-0.03em]">
            Quick answers
          </h2>
          <p className="mt-4 max-w-2xl leading-relaxed text-[rgba(237,230,218,0.5)]">
            What Forja is, which download to grab, and what to do if Windows or Mac
            hesitates the first time.
          </p>
        </Reveal>

        <div className="mt-10 divide-y divide-[rgba(237,230,218,0.12)] border-y border-[rgba(237,230,218,0.12)]">
          {FAQ.map((item, i) => (
            <Reveal key={item.q} delayMs={(i % 4) * 40}>
              <details className="group py-5">
                <summary className="flex cursor-pointer list-none items-start justify-between gap-4 [&::-webkit-details-marker]:hidden">
                  <span className="font-disp text-lg uppercase tracking-tight text-[#EDE6DA] sm:text-xl">
                    {item.q}
                  </span>
                  <span className="font-mono-ui mt-1 shrink-0 text-[11px] uppercase tracking-[0.14em] text-brand transition group-open:text-flame">
                    <span className="group-open:hidden">Open</span>
                    <span className="hidden group-open:inline">Close</span>
                  </span>
                </summary>
                <div className="mt-3 max-w-3xl space-y-3">
                  <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.52)] sm:text-base">
                    {item.a}
                  </p>
                  {item.guideHref ? (
                    <a
                      href={item.guideHref}
                      className="font-mono-ui inline-flex text-[12px] uppercase tracking-[0.14em] text-brand transition-colors hover:text-flame sm:text-[13px]"
                    >
                      {item.guideLabel ?? 'See the photo steps'} →
                    </a>
                  ) : null}
                </div>
              </details>
            </Reveal>
          ))}
        </div>
      </section>

      <section id="windows-smartscreen">
        <Reveal>
          <h2 className="font-disp max-w-[18ch] text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]">
            When Windows blocks the download
          </h2>
          <div className="mt-5 max-w-2xl space-y-3 text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg">
            <p>
              Windows sometimes shows a warning the first time you open Forja. That is
              normal for new apps — it does not mean Forja is unsafe.
            </p>
            <p>
              Follow the steps below. Use the photos as a guide. Click a photo to make it
              bigger.
            </p>
          </div>
        </Reveal>

        <ol className="mt-10 max-w-2xl space-y-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
          <li>
            <span className="font-semibold text-flame">1.</span> Open the Forja file you
            downloaded. If Windows shows a warning, click{' '}
            <span className="text-[#EDE6DA]">More info</span>.
          </li>
          <li>
            <span className="font-semibold text-flame">2.</span> Click{' '}
            <span className="text-[#EDE6DA]">Run anyway</span> (or continue on the red
            screen if that is what you see).
          </li>
          <li>
            <span className="font-semibold text-flame">3.</span> Still stuck? Right-click
            the file → Properties → check <span className="text-[#EDE6DA]">Unblock</span>{' '}
            → Apply → OK, then open it again.
          </li>
        </ol>

        <ShotSlider shots={WINDOWS_SHOTS} accent="flame" />
      </section>

      <section id="macos-gatekeeper">
        <Reveal>
          <h2 className="font-disp max-w-[18ch] text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]">
            When Mac won’t open Forja
          </h2>
          <div className="mt-5 max-w-2xl space-y-3 text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg">
            <p>
              Mac may say it could not verify the app the first time. That is normal for
              apps that are not from the App Store.
            </p>
            <p>
              Put Forja in Applications, try to open it once, then allow it in{' '}
              <span className="text-[#EDE6DA]">System Settings → Privacy &amp; Security</span>.
            </p>
          </div>
        </Reveal>

        <ol className="mt-10 max-w-2xl space-y-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
          <li>
            <span className="font-semibold text-brand">1.</span> Open Forja. When the
            block dialog appears, click <span className="text-[#EDE6DA]">Done</span> — not
            Move to Trash.
          </li>
          <li>
            <span className="font-semibold text-brand">2.</span> Open{' '}
            <span className="text-[#EDE6DA]">System Settings → Privacy &amp; Security</span>{' '}
            and scroll to Security.
          </li>
          <li>
            <span className="font-semibold text-brand">3.</span> Click{' '}
            <span className="text-[#EDE6DA]">Open Anyway</span>, confirm, and enter your
            password if asked. Forja will open after that.
          </li>
        </ol>

        <ShotSlider shots={MACOS_SHOTS} accent="brand" />
      </section>
    </div>
  )
}
