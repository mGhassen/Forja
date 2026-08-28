import { Pencil } from 'lucide-react'
import { cn } from '@/lib/utils'

export const PROFILE_AVATAR_CATEGORIES = [
  {
    key: 'characters',
    label: 'Characters',
    avatars: [
      { key: 'forge', label: 'Forge', colors: ['#1b1b1b', '#1ce783', '#0a2d21'] },
      { key: 'flame', label: 'Flame', colors: ['#ff4d1c', '#ffd1a8', '#3a130a'] },
      { key: 'mint', label: 'Mint', colors: ['#1ce783', '#f5fff9', '#0c3b2a'] },
      { key: 'captain', label: 'Captain', colors: ['#123a68', '#f4c7a1', '#facc15'] },
      { key: 'rebel', label: 'Rebel', colors: ['#9f1239', '#ffd2b3', '#1f1020'] },
      { key: 'ninja', label: 'Ninja', colors: ['#111827', '#c084fc', '#05070c'] },
      { key: 'royal', label: 'Royal', colors: ['#6d28d9', '#f6d0ad', '#facc15'] },
      { key: 'racer', label: 'Racer', colors: ['#dc2626', '#f8d5ba', '#111827'] },
    ],
  },
  {
    key: 'creatures',
    label: 'Creatures',
    avatars: [
      { key: 'night', label: 'Night Cat', colors: ['#10172c', '#64748b', '#1ce783'] },
      { key: 'panda', label: 'Panda', colors: ['#f8fafc', '#111827', '#fb7185'] },
      { key: 'fox', label: 'Fox', colors: ['#ea580c', '#fff7ed', '#431407'] },
      { key: 'owl', label: 'Owl', colors: ['#92400e', '#fde68a', '#1e3a8a'] },
      { key: 'shark', label: 'Shark', colors: ['#0369a1', '#bae6fd', '#172554'] },
      { key: 'dragon', label: 'Dragon', colors: ['#166534', '#86efac', '#facc15'] },
      { key: 'bunny', label: 'Bunny', colors: ['#f9a8d4', '#fff1f2', '#831843'] },
      { key: 'yeti', label: 'Yeti', colors: ['#dbeafe', '#f8fafc', '#1e40af'] },
    ],
  },
  {
    key: 'space',
    label: 'Space',
    avatars: [
      { key: 'orbit', label: 'Orbit', colors: ['#3978d5', '#dcecff', '#152b4d'] },
      { key: 'comet', label: 'Comet', colors: ['#312e81', '#f97316', '#fef3c7'] },
      { key: 'nova', label: 'Nova', colors: ['#701a75', '#f0abfc', '#facc15'] },
      { key: 'alien', label: 'Alien', colors: ['#052e16', '#4ade80', '#111827'] },
      { key: 'rover', label: 'Rover', colors: ['#7c2d12', '#fed7aa', '#292524'] },
      { key: 'lunar', label: 'Lunar', colors: ['#1e293b', '#e2e8f0', '#38bdf8'] },
      { key: 'solar', label: 'Solar', colors: ['#9a3412', '#facc15', '#fff7ed'] },
      { key: 'void', label: 'Void', colors: ['#020617', '#7c3aed', '#22d3ee'] },
    ],
  },
  {
    key: 'retro',
    label: 'Retro',
    avatars: [
      { key: 'pixel', label: 'Pixel', colors: ['#7c3aed', '#ded7ff', '#1ce783'] },
      { key: 'arcade', label: 'Arcade', colors: ['#172554', '#22d3ee', '#f472b6'] },
      { key: 'cassette', label: 'Cassette', colors: ['#f59e0b', '#292524', '#fef3c7'] },
      { key: 'glitch', label: 'Glitch', colors: ['#111827', '#ef4444', '#22d3ee'] },
      { key: 'neon', label: 'Neon', colors: ['#4a044e', '#f0abfc', '#a3e635'] },
      { key: 'synth', label: 'Synth', colors: ['#312e81', '#fb7185', '#67e8f9'] },
    ],
  },
] as const

type ProfileAvatarDefinition = (typeof PROFILE_AVATAR_CATEGORIES)[number]['avatars'][number]

export const PROFILE_AVATARS: readonly ProfileAvatarDefinition[] =
  PROFILE_AVATAR_CATEGORIES.flatMap((category) =>
    category.avatars as unknown as ProfileAvatarDefinition[],
  )

export type ProfileAvatarKey = ProfileAvatarDefinition['key']

export function normalizeAvatarKey(value: string): ProfileAvatarKey {
  return PROFILE_AVATARS.some((avatar) => avatar.key === value)
    ? (value as ProfileAvatarKey)
    : 'forge'
}

type ProfileAvatarProps = {
  avatarKey: string
  name: string
  className?: string
  editing?: boolean
}

export function ProfileAvatar({
  avatarKey,
  name,
  className,
  editing = false,
}: ProfileAvatarProps) {
  const key = normalizeAvatarKey(avatarKey)

  return (
    <span
      role="img"
      aria-label={`${name} avatar`}
      className={cn(
        'relative block aspect-square overflow-hidden rounded-[4px] bg-[#171717]',
        className,
      )}
    >
      <AvatarArtwork avatarKey={key} />
      {editing ? (
        <span className="absolute inset-0 flex items-center justify-center bg-black/55">
          <span className="flex size-11 items-center justify-center rounded-full border-2 border-white bg-black/45">
            <Pencil className="size-5 text-white" />
          </span>
        </span>
      ) : null}
    </span>
  )
}

function AvatarArtwork({ avatarKey }: { avatarKey: ProfileAvatarKey }) {
  const original =
    avatarKey === 'forge' ||
    avatarKey === 'flame' ||
    avatarKey === 'orbit' ||
    avatarKey === 'pixel' ||
    avatarKey === 'night' ||
    avatarKey === 'mint'

  if (!original) {
    const index = PROFILE_AVATARS.findIndex((avatar) => avatar.key === avatarKey)
    const avatar = PROFILE_AVATARS[index]
    return (
      <GeneratedAvatarArtwork
        colors={avatar.colors}
        category={Math.floor(index / 8)}
        variant={index % 8}
      />
    )
  }

  switch (avatarKey) {
    case 'flame':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
          <rect width="160" height="160" fill="#ff4d1c" />
          <path d="M0 128 30 95 58 116 88 84 121 112 160 76v84H0Z" fill="#24100b" />
          <circle cx="80" cy="77" r="44" fill="#ffd1a8" />
          <path
            d="M42 61c8-34 26-49 55-47-5 9-4 17 3 24 9-12 20-17 33-15-5 12-14 25-27 38Z"
            fill="#3a130a"
          />
          <circle cx="64" cy="77" r="5" fill="#24100b" />
          <circle cx="98" cy="77" r="5" fill="#24100b" />
          <path d="M62 99c13 10 26 10 39 0" fill="none" stroke="#24100b" strokeWidth="6" strokeLinecap="round" />
        </svg>
      )
    case 'orbit':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
          <rect width="160" height="160" fill="#3978d5" />
          <circle cx="25" cy="28" r="3" fill="#fff" />
          <circle cx="134" cy="38" r="4" fill="#fff" />
          <circle cx="116" cy="16" r="2" fill="#fff" />
          <circle cx="80" cy="82" r="58" fill="#dcecff" />
          <circle cx="80" cy="78" r="43" fill="#152b4d" />
          <circle cx="80" cy="82" r="31" fill="#b7dcff" />
          <circle cx="68" cy="78" r="4" fill="#152b4d" />
          <circle cx="94" cy="78" r="4" fill="#152b4d" />
          <path d="M67 96c9 6 18 6 27 0" fill="none" stroke="#152b4d" strokeWidth="5" strokeLinecap="round" />
          <path d="M33 137c28-19 65-19 94 0v23H33Z" fill="#e9f4ff" />
          <circle cx="126" cy="112" r="6" fill="#1ce783" />
        </svg>
      )
    case 'pixel':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
          <rect width="160" height="160" fill="#7c3aed" />
          <rect x="29" y="32" width="102" height="96" rx="9" fill="#ded7ff" />
          <rect x="42" y="48" width="76" height="51" fill="#211747" />
          <rect x="53" y="62" width="13" height="13" fill="#1ce783" />
          <rect x="94" y="62" width="13" height="13" fill="#1ce783" />
          <rect x="62" y="84" width="36" height="6" fill="#c084fc" />
          <rect x="70" y="18" width="20" height="16" fill="#ded7ff" />
          <rect x="76" y="7" width="8" height="15" fill="#ded7ff" />
          <rect x="43" y="111" width="18" height="8" fill="#7c3aed" />
          <rect x="70" y="111" width="18" height="8" fill="#7c3aed" />
          <rect x="97" y="111" width="18" height="8" fill="#7c3aed" />
        </svg>
      )
    case 'night':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
          <rect width="160" height="160" fill="#10172c" />
          <circle cx="126" cy="29" r="18" fill="#facc15" />
          <circle cx="136" cy="22" r="18" fill="#10172c" />
          <path d="m42 62 13-29 24 22 25-22 14 30v68H42Z" fill="#64748b" />
          <path d="m51 56 7-14 11 11ZM107 56l-7-14-11 11Z" fill="#fda4af" />
          <ellipse cx="65" cy="83" rx="8" ry="10" fill="#1ce783" />
          <ellipse cx="96" cy="83" rx="8" ry="10" fill="#1ce783" />
          <path d="m75 101 6 5 6-5" fill="#fda4af" />
          <path d="M53 107h18M90 107h18" stroke="#e2e8f0" strokeWidth="3" strokeLinecap="round" />
        </svg>
      )
    case 'mint':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
          <rect width="160" height="160" fill="#1ce783" />
          <path d="M18 160c8-61 31-99 62-99s55 38 63 99Z" fill="#0c3b2a" />
          <circle cx="56" cy="69" r="22" fill="#f5fff9" />
          <circle cx="104" cy="69" r="22" fill="#f5fff9" />
          <circle cx="60" cy="72" r="9" fill="#0c3b2a" />
          <circle cx="100" cy="72" r="9" fill="#0c3b2a" />
          <path d="M57 113c15 14 31 14 46 0" fill="none" stroke="#f5fff9" strokeWidth="7" strokeLinecap="round" />
          <path d="M35 42 17 21M125 42l18-21" stroke="#0c3b2a" strokeWidth="10" strokeLinecap="round" />
        </svg>
      )
    case 'forge':
    default:
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
          <rect width="160" height="160" fill="#1b1b1b" />
          <circle cx="80" cy="77" r="49" fill="#1ce783" />
          <path d="M32 63c7-33 25-49 52-49 25 0 42 14 49 41L103 43 82 57 61 43Z" fill="#0a2d21" />
          <rect x="43" y="66" width="31" height="23" rx="5" fill="#111" />
          <rect x="86" y="66" width="31" height="23" rx="5" fill="#111" />
          <rect x="74" y="73" width="12" height="5" fill="#111" />
          <circle cx="59" cy="77" r="4" fill="#1ce783" />
          <circle cx="101" cy="77" r="4" fill="#1ce783" />
          <path d="M58 104c14 11 29 11 44 0" fill="none" stroke="#0a2d21" strokeWidth="7" strokeLinecap="round" />
          <path d="M29 160c8-30 25-45 51-45s44 15 52 45Z" fill="#124d39" />
        </svg>
      )
  }
}

function GeneratedAvatarArtwork({
  colors,
  category,
  variant,
}: {
  colors: readonly [string, string, string]
  category: number
  variant: number
}) {
  const [background, primary, accent] = colors

  if (category === 0) {
    return (
      <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
        <rect width="160" height="160" fill={background} />
        <path d="M22 160c8-34 28-51 58-51s50 17 58 51Z" fill={accent} />
        <circle cx="80" cy="76" r="45" fill={primary} />
        {variant % 2 === 0 ? (
          <path d="M38 62c5-31 21-47 48-47 24 0 39 13 45 40L105 42 82 55 58 42Z" fill={accent} />
        ) : (
          <path d="M36 61 48 24l31 12 29-13 17 38Z" fill={accent} />
        )}
        {variant === 5 ? (
          <path d="M39 70h82v28c-25 16-54 16-82 0Z" fill={accent} />
        ) : (
          <>
            <circle cx="64" cy="77" r="5" fill={accent} />
            <circle cx="97" cy="77" r="5" fill={accent} />
          </>
        )}
        <path d="M61 99c13 10 26 10 39 0" fill="none" stroke={accent} strokeWidth="6" strokeLinecap="round" />
        {variant === 3 ? <path d="m55 35 9-23 16 18 17-18 10 23Z" fill="#facc15" /> : null}
      </svg>
    )
  }

  if (category === 1) {
    return (
      <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
        <rect width="160" height="160" fill={background} />
        <path d="M28 67 38 23l32 29M132 67l-10-44-32 29" fill={primary} stroke={accent} strokeWidth="8" strokeLinejoin="round" />
        <ellipse cx="80" cy="89" rx="55" ry="58" fill={primary} />
        {variant === 4 ? (
          <path d="M21 77h118l-18 26H39Z" fill={accent} />
        ) : null}
        <ellipse cx="59" cy="81" rx="9" ry="11" fill={accent} />
        <ellipse cx="101" cy="81" rx="9" ry="11" fill={accent} />
        <ellipse cx="80" cy="106" rx="17" ry="12" fill={background} />
        <circle cx="80" cy="102" r="5" fill={accent} />
        <path d="M65 119c10 7 20 7 30 0" fill="none" stroke={accent} strokeWidth="5" strokeLinecap="round" />
        {variant === 5 ? <path d="m80 30 9-20 8 21M58 38 48 19" stroke="#facc15" strokeWidth="7" strokeLinecap="round" /> : null}
      </svg>
    )
  }

  if (category === 2) {
    return (
      <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
        <rect width="160" height="160" fill={background} />
        <circle cx="24" cy="27" r="3" fill={primary} />
        <circle cx="133" cy="38" r="4" fill={accent} />
        <circle cx="119" cy="17" r="2" fill={primary} />
        <circle cx="80" cy="80" r="58" fill={primary} />
        <circle cx="80" cy="78" r="43" fill={accent} />
        <circle cx="80" cy="82" r="31" fill={background} />
        <circle cx="67" cy="79" r="5" fill={primary} />
        <circle cx="94" cy="79" r="5" fill={primary} />
        <path d="M66 98c10 7 20 7 29 0" fill="none" stroke={primary} strokeWidth="5" strokeLinecap="round" />
        <path d="M31 140c29-20 68-20 98 0v20H31Z" fill={accent} />
        <circle cx={120 - variant * 2} cy="119" r="6" fill={primary} />
      </svg>
    )
  }

  return (
    <svg viewBox="0 0 160 160" className="size-full" aria-hidden>
      <rect width="160" height="160" fill={background} />
      <rect x="27" y="31" width="106" height="98" rx={variant % 2 === 0 ? 8 : 0} fill={primary} />
      <rect x="40" y="47" width="80" height="54" fill={accent} />
      <rect x="52" y="63" width="14" height="14" fill={background} />
      <rect x="94" y="63" width="14" height="14" fill={background} />
      <rect x={58 + variant * 2} y="86" width={44 - variant * 2} height="7" fill={primary} />
      <rect x="69" y="17" width="22" height="16" fill={primary} />
      <rect x="76" y="7" width="8" height="12" fill={accent} />
      <rect x="42" y="112" width="19" height="8" fill={background} />
      <rect x="70" y="112" width="19" height="8" fill={background} />
      <rect x="98" y="112" width="19" height="8" fill={background} />
    </svg>
  )
}
