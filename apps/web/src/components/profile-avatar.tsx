import { Pencil } from 'lucide-react'
import { cn } from '@/lib/utils'

export const PROFILE_AVATARS = [
  { key: 'forge', label: 'Forge' },
  { key: 'flame', label: 'Flame' },
  { key: 'orbit', label: 'Orbit' },
  { key: 'pixel', label: 'Pixel' },
  { key: 'night', label: 'Night' },
  { key: 'mint', label: 'Mint' },
] as const

export type ProfileAvatarKey = (typeof PROFILE_AVATARS)[number]['key']

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
