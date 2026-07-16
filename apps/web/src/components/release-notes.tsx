import { cn } from '@/lib/utils'

type Block =
  | { type: 'h1'; text: string }
  | { type: 'h2'; text: string }
  | { type: 'h3'; text: string }
  | { type: 'p'; text: string }
  | { type: 'li'; prefix: string | null; text: string }

const PREFIX_RE = /^\*\*(Add|Change|Fix|Remove):\*\*\s*/i

function parseBlocks(markdown: string): Block[] {
  const blocks: Block[] = []
  for (const raw of markdown.split(/\r?\n/)) {
    const line = raw.trimEnd()
    const trimmed = line.trim()
    if (!trimmed) continue

    if (trimmed.startsWith('# ')) {
      blocks.push({ type: 'h1', text: trimmed.slice(2).trim() })
      continue
    }
    if (trimmed.startsWith('## ')) {
      blocks.push({ type: 'h2', text: trimmed.slice(3).trim() })
      continue
    }
    if (trimmed.startsWith('### ')) {
      blocks.push({ type: 'h3', text: trimmed.slice(4).trim() })
      continue
    }
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      const body = trimmed.slice(2).trim()
      const m = body.match(PREFIX_RE)
      if (m) {
        blocks.push({
          type: 'li',
          prefix: m[1]!,
          text: body.slice(m[0].length).trim().replace(/\*\*/g, ''),
        })
      } else {
        blocks.push({ type: 'li', prefix: null, text: body.replace(/\*\*/g, '') })
      }
      continue
    }

    if (trimmed.startsWith('**Status:**') || trimmed.startsWith('**Since release:**')) {
      continue
    }
    if (trimmed === '---') continue

    blocks.push({ type: 'p', text: trimmed.replace(/\*\*/g, '') })
  }
  return blocks
}

function prefixClass(prefix: string): string {
  switch (prefix.toLowerCase()) {
    case 'add':
      return 'text-brand'
    case 'fix':
      return 'text-flame'
    case 'change':
      return 'text-[rgba(237,230,218,0.85)]'
    case 'remove':
      return 'text-red-300'
    default:
      return 'text-brand'
  }
}

/** Renders Forja release-note markdown with styled groups and change prefixes. */
export function ReleaseNotes({
  markdown,
  className,
}: {
  markdown: string
  className?: string
}) {
  const blocks = parseBlocks(markdown)

  return (
    <div
      className={cn(
        'max-h-80 space-y-4 overflow-auto pr-1 text-sm leading-relaxed',
        className,
      )}
    >
      {blocks.map((b, i) => {
        if (b.type === 'h1') {
          return (
            <h3
              key={i}
              className="font-disp text-xl uppercase tracking-tight text-[#EDE6DA] sm:text-2xl"
            >
              {b.text}
            </h3>
          )
        }
        if (b.type === 'h2') {
          return (
            <h4
              key={i}
              className="font-disp text-lg uppercase tracking-tight text-[#EDE6DA]"
            >
              {b.text}
            </h4>
          )
        }
        if (b.type === 'h3') {
          return (
            <p
              key={i}
              className="font-mono-ui pt-2 text-[11px] uppercase tracking-[0.18em] text-brand first:pt-0"
            >
              {b.text}
            </p>
          )
        }
        if (b.type === 'li') {
          return (
            <div key={i} className="flex gap-2.5 pl-0.5">
              <span className="mt-2 h-1 w-1 shrink-0 rounded-full bg-[rgba(237,230,218,0.35)]" />
              <p className="text-[rgba(237,230,218,0.62)]">
                {b.prefix ? (
                  <>
                    <span className={cn('font-semibold', prefixClass(b.prefix))}>
                      {b.prefix}:
                    </span>{' '}
                  </>
                ) : null}
                {b.text}
              </p>
            </div>
          )
        }
        return (
          <p key={i} className="text-[rgba(237,230,218,0.5)]">
            {b.text}
          </p>
        )
      })}
    </div>
  )
}
