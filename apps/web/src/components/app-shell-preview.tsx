import { Link } from '@tanstack/react-router'

type AppShellPreviewProps = {
  className?: string
  src?: string
  alt?: string
  caption?: string
}

/** Raw app screenshot - no fake OS chrome. */
export function AppShellPreview({
  className = '',
  src = '/brand/forja-home-hero.jpg',
  alt = 'Forja - home with cinematic hero and featured shelves',
  caption = 'Windows · macOS · Linux · Android TV',
}: AppShellPreviewProps) {
  return (
    <div className={className}>
      <div className="relative overflow-hidden rounded-lg border border-white/10 shadow-[0_40px_100px_-20px_rgba(0,0,0,0.85),0_0_60px_-10px_rgba(255,77,28,0.2)]">
        <img
          src={src}
          alt={alt}
          className="aspect-[16/10] w-full object-cover object-top"
        />
      </div>

      <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
        <p className="font-mono-ui text-[10px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.4)]">
          {caption}
        </p>
        <Link
          to="/download"
          className="font-mono-ui text-[10px] uppercase tracking-[0.16em] text-flame transition-colors hover:text-brand"
        >
          Downloads
        </Link>
      </div>
    </div>
  )
}
