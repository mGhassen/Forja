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
      { key: 'elf', label: 'Elf', colors: ['#064e3b', '#fde68a', '#67e8f9'] },
      { key: 'orc', label: 'Orc', colors: ['#365314', '#a3e635', '#431407'] },
      { key: 'fairy', label: 'Fairy', colors: ['#831843', '#fbcfe8', '#a78bfa'] },
      { key: 'golem', label: 'Golem', colors: ['#292524', '#a8a29e', '#22d3ee'] },
      { key: 'phoenix', label: 'Phoenix', colors: ['#7c2d12', '#fbbf24', '#ef4444'] },
      { key: 'mermaid', label: 'Mermaid', colors: ['#164e63', '#fbcfe8', '#22d3ee'] },
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
      { key: 'wolf', label: 'Wolf', colors: ['#1c1917', '#a8a29e', '#facc15'] },
      { key: 'bear', label: 'Bear', colors: ['#44403c', '#d6d3d1', '#292524'] },
      { key: 'penguin', label: 'Penguin', colors: ['#0c4a6e', '#f8fafc', '#f97316'] },
      { key: 'frog', label: 'Frog', colors: ['#14532d', '#4ade80', '#facc15'] },
      { key: 'lion', label: 'Lion', colors: ['#9a3412', '#fdba74', '#facc15'] },
      { key: 'bee', label: 'Bee', colors: ['#1e3a8a', '#facc15', '#111827'] },
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
      { key: 'invader', label: 'Invader', colors: ['#0b1026', '#4ade80', '#facc15'] },
      { key: 'ghost', label: 'Ghost', colors: ['#1e1b4b', '#fda4af', '#67e8f9'] },
      { key: 'knight', label: 'Knight', colors: ['#1f2937', '#cbd5e1', '#facc15'] },
      { key: 'wizard', label: 'Wizard', colors: ['#2e1065', '#e9d5ff', '#facc15'] },
      { key: 'toad', label: 'Toad', colors: ['#14532d', '#fecaca', '#ef4444'] },
      { key: 'heartbit', label: 'Heartbit', colors: ['#4c0519', '#fb7185', '#fef3c7'] },
      { key: 'boombox', label: 'Boombox', colors: ['#1c1917', '#f97316', '#22d3ee'] },
      { key: 'chip', label: 'Chip', colors: ['#052e16', '#86efac', '#a3e635'] },
      { key: 'cyborg', label: 'Cyborg', colors: ['#111827', '#94a3b8', '#22d3ee'] },
      { key: 'hacker', label: 'Hacker', colors: ['#052e16', '#4ade80', '#14532d'] },
      { key: 'drone', label: 'Drone', colors: ['#0f172a', '#38bdf8', '#f43f5e'] },
      { key: 'matrix', label: 'Matrix', colors: ['#022c22', '#22c55e', '#86efac'] },
      { key: 'laser', label: 'Laser', colors: ['#1e1b4b', '#f472b6', '#22d3ee'] },
      { key: 'android', label: 'Android', colors: ['#1e293b', '#a3e635', '#38bdf8'] },
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
        'relative block aspect-square overflow-hidden rounded-sm bg-[#171717]',
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

const CUSTOM_AVATAR_KEYS = new Set<ProfileAvatarKey>([
  'forge',
  'flame',
  'orbit',
  'pixel',
  'arcade',
  'cassette',
  'glitch',
  'neon',
  'synth',
  'invader',
  'ghost',
  'knight',
  'wizard',
  'toad',
  'heartbit',
  'boombox',
  'chip',
  'wolf',
  'bear',
  'penguin',
  'frog',
  'lion',
  'bee',
  'elf',
  'orc',
  'fairy',
  'golem',
  'phoenix',
  'mermaid',
  'cyborg',
  'hacker',
  'drone',
  'matrix',
  'laser',
  'android',
  'night',
  'mint',
])

function AvatarArtwork({ avatarKey }: { avatarKey: ProfileAvatarKey }) {
  if (!CUSTOM_AVATAR_KEYS.has(avatarKey)) {
    const avatar = PROFILE_AVATARS.find((entry) => entry.key === avatarKey)!
    const category = PROFILE_AVATAR_CATEGORIES.findIndex((entry) =>
      entry.avatars.some((item) => item.key === avatarKey),
    )
    const variant = PROFILE_AVATAR_CATEGORIES[category].avatars.findIndex(
      (item) => item.key === avatarKey,
    )
    return (
      <GeneratedAvatarArtwork
        colors={avatar.colors}
        category={category}
        variant={variant}
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
    case 'arcade':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#172554" />
          <rect x="28" y="16" width="104" height="128" fill="#0f172a" />
          <rect x="36" y="24" width="88" height="56" fill="#22d3ee" />
          <rect x="44" y="32" width="72" height="40" fill="#082f49" />
          <rect x="56" y="40" width="12" height="12" fill="#f472b6" />
          <rect x="92" y="40" width="12" height="12" fill="#f472b6" />
          <rect x="64" y="60" width="32" height="6" fill="#facc15" />
          <rect x="44" y="92" width="28" height="10" fill="#334155" />
          <rect x="88" y="88" width="16" height="16" rx="8" fill="#ef4444" />
          <rect x="92" y="92" width="8" height="8" fill="#fecaca" />
          <rect x="48" y="112" width="12" height="12" fill="#22d3ee" />
          <rect x="68" y="112" width="12" height="12" fill="#f472b6" />
          <rect x="88" y="112" width="12" height="12" fill="#facc15" />
          <rect x="108" y="112" width="12" height="12" fill="#a3e635" />
        </svg>
      )
    case 'cassette':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#f59e0b" />
          <rect x="20" y="36" width="120" height="88" fill="#292524" />
          <rect x="28" y="44" width="104" height="56" fill="#fef3c7" />
          <rect x="40" y="56" width="28" height="28" fill="#292524" />
          <rect x="92" y="56" width="28" height="28" fill="#292524" />
          <rect x="48" y="64" width="12" height="12" fill="#22d3ee" />
          <rect x="100" y="64" width="12" height="12" fill="#22d3ee" />
          <rect x="72" y="62" width="16" height="16" fill="#f59e0b" />
          <rect x="44" y="108" width="72" height="8" fill="#78716c" />
          <rect x="52" y="24" width="16" height="12" fill="#292524" />
          <rect x="92" y="24" width="16" height="12" fill="#292524" />
        </svg>
      )
    case 'glitch':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#111827" />
          <rect x="34" y="28" width="92" height="104" fill="#ef4444" />
          <rect x="30" y="32" width="92" height="104" fill="#22d3ee" />
          <rect x="38" y="36" width="84" height="92" fill="#1f2937" />
          <rect x="50" y="56" width="16" height="16" fill="#ef4444" />
          <rect x="94" y="56" width="16" height="16" fill="#22d3ee" />
          <rect x="48" y="84" width="64" height="8" fill="#f8fafc" />
          <rect x="56" y="96" width="48" height="8" fill="#a3e635" />
          <rect x="20" y="48" width="12" height="4" fill="#ef4444" />
          <rect x="128" y="72" width="16" height="4" fill="#22d3ee" />
          <rect x="16" y="100" width="20" height="4" fill="#a3e635" />
        </svg>
      )
    case 'neon':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#4a044e" />
          <rect x="36" y="28" width="88" height="104" fill="#701a75" />
          <rect x="44" y="36" width="72" height="72" fill="#2e1065" />
          <rect x="52" y="52" width="16" height="16" fill="#a3e635" />
          <rect x="92" y="52" width="16" height="16" fill="#a3e635" />
          <rect x="56" y="56" width="8" height="8" fill="#4a044e" />
          <rect x="96" y="56" width="8" height="8" fill="#4a044e" />
          <rect x="60" y="84" width="40" height="8" fill="#f0abfc" />
          <rect x="40" y="116" width="80" height="8" fill="#f0abfc" />
          <rect x="72" y="16" width="16" height="12" fill="#a3e635" />
          <rect x="24" y="40" width="8" height="8" fill="#f0abfc" />
          <rect x="128" y="64" width="8" height="8" fill="#a3e635" />
        </svg>
      )
    case 'synth':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#312e81" />
          <rect x="0" y="104" width="160" height="8" fill="#fb7185" />
          <rect x="0" y="112" width="160" height="8" fill="#f97316" />
          <rect x="0" y="120" width="160" height="8" fill="#facc15" />
          <rect x="0" y="128" width="160" height="8" fill="#67e8f9" />
          <rect x="40" y="28" width="80" height="72" fill="#fde68a" />
          <rect x="36" y="52" width="88" height="20" fill="#111827" />
          <rect x="48" y="56" width="24" height="12" fill="#67e8f9" />
          <rect x="88" y="56" width="24" height="12" fill="#fb7185" />
          <rect x="64" y="80" width="32" height="8" fill="#831843" />
          <rect x="52" y="16" width="56" height="16" fill="#1e1b4b" />
        </svg>
      )
    case 'invader':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#0b1026" />
          <rect x="20" y="20" width="8" height="8" fill="#4ade80" />
          <rect x="132" y="36" width="8" height="8" fill="#facc15" />
          <rect x="48" y="28" width="8" height="8" fill="#4ade80" />
          <rect x="104" y="28" width="8" height="8" fill="#4ade80" />
          <rect x="40" y="36" width="8" height="8" fill="#4ade80" />
          <rect x="48" y="36" width="64" height="8" fill="#4ade80" />
          <rect x="112" y="36" width="8" height="8" fill="#4ade80" />
          <rect x="32" y="44" width="96" height="8" fill="#4ade80" />
          <rect x="32" y="52" width="24" height="8" fill="#4ade80" />
          <rect x="64" y="52" width="32" height="8" fill="#4ade80" />
          <rect x="104" y="52" width="24" height="8" fill="#4ade80" />
          <rect x="32" y="60" width="96" height="8" fill="#4ade80" />
          <rect x="48" y="56" width="16" height="8" fill="#0b1026" />
          <rect x="96" y="56" width="16" height="8" fill="#0b1026" />
          <rect x="40" y="68" width="16" height="8" fill="#4ade80" />
          <rect x="72" y="68" width="16" height="8" fill="#4ade80" />
          <rect x="104" y="68" width="16" height="8" fill="#4ade80" />
          <rect x="32" y="76" width="8" height="8" fill="#4ade80" />
          <rect x="120" y="76" width="8" height="8" fill="#4ade80" />
          <rect x="64" y="84" width="8" height="8" fill="#facc15" />
          <rect x="88" y="84" width="8" height="8" fill="#facc15" />
        </svg>
      )
    case 'ghost':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#1e1b4b" />
          <rect x="48" y="28" width="64" height="8" fill="#fda4af" />
          <rect x="40" y="36" width="80" height="8" fill="#fda4af" />
          <rect x="32" y="44" width="96" height="64" fill="#fda4af" />
          <rect x="32" y="108" width="16" height="16" fill="#fda4af" />
          <rect x="56" y="108" width="16" height="16" fill="#fda4af" />
          <rect x="80" y="108" width="16" height="16" fill="#fda4af" />
          <rect x="104" y="108" width="16" height="16" fill="#fda4af" />
          <rect x="48" y="60" width="16" height="20" fill="#67e8f9" />
          <rect x="96" y="60" width="16" height="20" fill="#67e8f9" />
          <rect x="52" y="64" width="8" height="8" fill="#1e1b4b" />
          <rect x="100" y="64" width="8" height="8" fill="#1e1b4b" />
          <rect x="72" y="88" width="16" height="8" fill="#fb7185" />
        </svg>
      )
    case 'knight':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#1f2937" />
          <rect x="56" y="16" width="48" height="12" fill="#facc15" />
          <rect x="64" y="8" width="32" height="8" fill="#facc15" />
          <rect x="40" y="28" width="80" height="88" fill="#cbd5e1" />
          <rect x="48" y="36" width="64" height="64" fill="#94a3b8" />
          <rect x="40" y="60" width="80" height="16" fill="#0f172a" />
          <rect x="52" y="64" width="20" height="8" fill="#38bdf8" />
          <rect x="88" y="64" width="20" height="8" fill="#38bdf8" />
          <rect x="68" y="88" width="24" height="8" fill="#1f2937" />
          <rect x="32" y="116" width="96" height="24" fill="#64748b" />
          <rect x="48" y="124" width="64" height="8" fill="#facc15" />
        </svg>
      )
    case 'wizard':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#2e1065" />
          <rect x="72" y="8" width="16" height="16" fill="#facc15" />
          <rect x="64" y="24" width="32" height="16" fill="#7c3aed" />
          <rect x="48" y="40" width="64" height="16" fill="#7c3aed" />
          <rect x="32" y="56" width="96" height="12" fill="#a78bfa" />
          <rect x="44" y="68" width="72" height="56" fill="#e9d5ff" />
          <rect x="56" y="80" width="12" height="12" fill="#2e1065" />
          <rect x="92" y="80" width="12" height="12" fill="#2e1065" />
          <rect x="68" y="100" width="24" height="8" fill="#c084fc" />
          <rect x="52" y="116" width="56" height="20" fill="#f8fafc" />
          <rect x="120" y="72" width="8" height="8" fill="#facc15" />
          <rect x="28" y="88" width="8" height="8" fill="#67e8f9" />
        </svg>
      )
    case 'toad':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#14532d" />
          <rect x="36" y="20" width="88" height="64" fill="#fecaca" />
          <rect x="48" y="12" width="64" height="16" fill="#fecaca" />
          <rect x="44" y="28" width="20" height="20" fill="#ef4444" />
          <rect x="96" y="28" width="20" height="20" fill="#ef4444" />
          <rect x="72" y="48" width="16" height="16" fill="#ef4444" />
          <rect x="48" y="76" width="64" height="48" fill="#fed7aa" />
          <rect x="56" y="88" width="12" height="12" fill="#14532d" />
          <rect x="92" y="88" width="12" height="12" fill="#14532d" />
          <rect x="72" y="104" width="16" height="8" fill="#fb7185" />
          <rect x="56" y="124" width="20" height="16" fill="#fdba74" />
          <rect x="84" y="124" width="20" height="16" fill="#fdba74" />
        </svg>
      )
    case 'heartbit':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#4c0519" />
          <rect x="36" y="36" width="32" height="24" fill="#fb7185" />
          <rect x="92" y="36" width="32" height="24" fill="#fb7185" />
          <rect x="28" y="52" width="104" height="40" fill="#fb7185" />
          <rect x="40" y="92" width="80" height="24" fill="#fb7185" />
          <rect x="56" y="116" width="48" height="16" fill="#fb7185" />
          <rect x="68" y="132" width="24" height="8" fill="#fb7185" />
          <rect x="52" y="64" width="16" height="16" fill="#fef3c7" />
          <rect x="92" y="64" width="16" height="16" fill="#fef3c7" />
          <rect x="56" y="68" width="8" height="8" fill="#4c0519" />
          <rect x="96" y="68" width="8" height="8" fill="#4c0519" />
          <rect x="68" y="92" width="24" height="8" fill="#be123c" />
        </svg>
      )
    case 'boombox':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#1c1917" />
          <rect x="20" y="44" width="120" height="80" fill="#292524" />
          <rect x="28" y="52" width="40" height="40" fill="#f97316" />
          <rect x="92" y="52" width="40" height="40" fill="#f97316" />
          <rect x="36" y="60" width="24" height="24" fill="#1c1917" />
          <rect x="100" y="60" width="24" height="24" fill="#1c1917" />
          <rect x="44" y="68" width="8" height="8" fill="#22d3ee" />
          <rect x="108" y="68" width="8" height="8" fill="#22d3ee" />
          <rect x="72" y="56" width="16" height="32" fill="#44403c" />
          <rect x="76" y="60" width="8" height="8" fill="#a3e635" />
          <rect x="76" y="76" width="8" height="8" fill="#ef4444" />
          <rect x="48" y="100" width="64" height="12" fill="#57534e" />
          <rect x="56" y="28" width="48" height="16" fill="#44403c" />
          <rect x="64" y="20" width="8" height="12" fill="#22d3ee" />
          <rect x="88" y="20" width="8" height="12" fill="#22d3ee" />
        </svg>
      )
    case 'chip':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#052e16" />
          <rect x="16" y="56" width="12" height="8" fill="#86efac" />
          <rect x="16" y="76" width="12" height="8" fill="#86efac" />
          <rect x="16" y="96" width="12" height="8" fill="#86efac" />
          <rect x="132" y="56" width="12" height="8" fill="#86efac" />
          <rect x="132" y="76" width="12" height="8" fill="#86efac" />
          <rect x="132" y="96" width="12" height="8" fill="#86efac" />
          <rect x="48" y="16" width="8" height="12" fill="#86efac" />
          <rect x="76" y="16" width="8" height="12" fill="#86efac" />
          <rect x="104" y="16" width="8" height="12" fill="#86efac" />
          <rect x="48" y="132" width="8" height="12" fill="#86efac" />
          <rect x="76" y="132" width="8" height="12" fill="#86efac" />
          <rect x="104" y="132" width="8" height="12" fill="#86efac" />
          <rect x="36" y="36" width="88" height="88" fill="#166534" />
          <rect x="48" y="48" width="64" height="64" fill="#14532d" />
          <rect x="56" y="60" width="16" height="16" fill="#a3e635" />
          <rect x="88" y="60" width="16" height="16" fill="#a3e635" />
          <rect x="60" y="64" width="8" height="8" fill="#052e16" />
          <rect x="92" y="64" width="8" height="8" fill="#052e16" />
          <rect x="64" y="92" width="32" height="8" fill="#86efac" />
        </svg>
      )
    case 'wolf':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#1c1917" />
          <rect x="36" y="36" width="88" height="72" fill="#a8a29e" />
          <rect x="28" y="28" width="24" height="32" fill="#a8a29e" />
          <rect x="108" y="28" width="24" height="32" fill="#a8a29e" />
          <rect x="48" y="56" width="16" height="16" fill="#facc15" />
          <rect x="96" y="56" width="16" height="16" fill="#facc15" />
          <rect x="52" y="60" width="8" height="8" fill="#1c1917" />
          <rect x="100" y="60" width="8" height="8" fill="#1c1917" />
          <rect x="68" y="76" width="24" height="16" fill="#78716c" />
          <rect x="76" y="80" width="8" height="8" fill="#1c1917" />
          <rect x="44" y="108" width="72" height="24" fill="#57534e" />
        </svg>
      )
    case 'bear':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#44403c" />
          <rect x="32" y="24" width="24" height="24" fill="#d6d3d1" />
          <rect x="104" y="24" width="24" height="24" fill="#d6d3d1" />
          <rect x="40" y="40" width="80" height="72" fill="#d6d3d1" />
          <rect x="56" y="60" width="16" height="16" fill="#292524" />
          <rect x="88" y="60" width="16" height="16" fill="#292524" />
          <rect x="68" y="84" width="24" height="16" fill="#a8a29e" />
          <rect x="76" y="88" width="8" height="8" fill="#292524" />
          <rect x="48" y="112" width="64" height="24" fill="#78716c" />
        </svg>
      )
    case 'penguin':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#0c4a6e" />
          <rect x="48" y="24" width="64" height="96" fill="#0f172a" />
          <rect x="56" y="48" width="48" height="64" fill="#f8fafc" />
          <rect x="60" y="40" width="12" height="12" fill="#f8fafc" />
          <rect x="88" y="40" width="12" height="12" fill="#f8fafc" />
          <rect x="64" y="44" width="4" height="4" fill="#0f172a" />
          <rect x="92" y="44" width="4" height="4" fill="#0f172a" />
          <rect x="72" y="56" width="16" height="12" fill="#f97316" />
          <rect x="40" y="72" width="16" height="32" fill="#0f172a" />
          <rect x="104" y="72" width="16" height="32" fill="#0f172a" />
          <rect x="56" y="120" width="20" height="12" fill="#f97316" />
          <rect x="84" y="120" width="20" height="12" fill="#f97316" />
        </svg>
      )
    case 'frog':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#14532d" />
          <rect x="36" y="48" width="88" height="64" fill="#4ade80" />
          <rect x="40" y="28" width="32" height="32" fill="#4ade80" />
          <rect x="88" y="28" width="32" height="32" fill="#4ade80" />
          <rect x="48" y="36" width="16" height="16" fill="#facc15" />
          <rect x="96" y="36" width="16" height="16" fill="#facc15" />
          <rect x="52" y="40" width="8" height="8" fill="#14532d" />
          <rect x="100" y="40" width="8" height="8" fill="#14532d" />
          <rect x="68" y="80" width="24" height="8" fill="#166534" />
          <rect x="44" y="112" width="24" height="16" fill="#22c55e" />
          <rect x="92" y="112" width="24" height="16" fill="#22c55e" />
        </svg>
      )
    case 'lion':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#9a3412" />
          <rect x="24" y="32" width="112" height="96" fill="#ea580c" />
          <rect x="44" y="48" width="72" height="64" fill="#fdba74" />
          <rect x="56" y="64" width="16" height="16" fill="#431407" />
          <rect x="88" y="64" width="16" height="16" fill="#431407" />
          <rect x="68" y="88" width="24" height="12" fill="#f97316" />
          <rect x="76" y="92" width="8" height="8" fill="#431407" />
          <rect x="64" y="24" width="32" height="16" fill="#facc15" />
        </svg>
      )
    case 'bee':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#1e3a8a" />
          <rect x="20" y="48" width="32" height="40" fill="#e2e8f0" />
          <rect x="108" y="48" width="32" height="40" fill="#e2e8f0" />
          <rect x="48" y="40" width="64" height="80" fill="#facc15" />
          <rect x="48" y="56" width="64" height="12" fill="#111827" />
          <rect x="48" y="80" width="64" height="12" fill="#111827" />
          <rect x="60" y="48" width="12" height="12" fill="#111827" />
          <rect x="88" y="48" width="12" height="12" fill="#111827" />
          <rect x="72" y="28" width="16" height="12" fill="#111827" />
        </svg>
      )
    case 'elf':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#064e3b" />
          <rect x="28" y="44" width="24" height="12" fill="#fde68a" />
          <rect x="108" y="44" width="24" height="12" fill="#fde68a" />
          <rect x="44" y="36" width="72" height="72" fill="#fde68a" />
          <rect x="52" y="24" width="56" height="24" fill="#067a55" />
          <rect x="56" y="56" width="12" height="12" fill="#064e3b" />
          <rect x="92" y="56" width="12" height="12" fill="#064e3b" />
          <rect x="68" y="80" width="24" height="8" fill="#67e8f9" />
          <rect x="48" y="108" width="64" height="28" fill="#0f766e" />
        </svg>
      )
    case 'orc':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#365314" />
          <rect x="36" y="36" width="88" height="80" fill="#a3e635" />
          <rect x="40" y="20" width="16" height="28" fill="#a3e635" />
          <rect x="104" y="20" width="16" height="28" fill="#a3e635" />
          <rect x="52" y="56" width="16" height="16" fill="#431407" />
          <rect x="92" y="56" width="16" height="16" fill="#431407" />
          <rect x="68" y="80" width="24" height="16" fill="#65a30d" />
          <rect x="72" y="84" width="6" height="12" fill="#f8fafc" />
          <rect x="82" y="84" width="6" height="12" fill="#f8fafc" />
          <rect x="40" y="116" width="80" height="24" fill="#3f6212" />
        </svg>
      )
    case 'fairy':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#831843" />
          <rect x="12" y="40" width="28" height="48" fill="#a78bfa" />
          <rect x="120" y="40" width="28" height="48" fill="#a78bfa" />
          <rect x="44" y="36" width="72" height="72" fill="#fbcfe8" />
          <rect x="56" y="20" width="48" height="24" fill="#f9a8d4" />
          <rect x="56" y="56" width="12" height="12" fill="#831843" />
          <rect x="92" y="56" width="12" height="12" fill="#831843" />
          <rect x="68" y="80" width="24" height="8" fill="#db2777" />
          <rect x="60" y="108" width="40" height="28" fill="#c026d3" />
          <rect x="76" y="8" width="8" height="12" fill="#facc15" />
        </svg>
      )
    case 'golem':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#292524" />
          <rect x="32" y="28" width="96" height="100" fill="#a8a29e" />
          <rect x="40" y="36" width="80" height="56" fill="#78716c" />
          <rect x="52" y="48" width="20" height="20" fill="#22d3ee" />
          <rect x="88" y="48" width="20" height="20" fill="#22d3ee" />
          <rect x="56" y="52" width="12" height="12" fill="#0e7490" />
          <rect x="92" y="52" width="12" height="12" fill="#0e7490" />
          <rect x="60" y="84" width="40" height="12" fill="#57534e" />
          <rect x="44" y="112" width="28" height="16" fill="#57534e" />
          <rect x="88" y="112" width="28" height="16" fill="#57534e" />
        </svg>
      )
    case 'phoenix':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#7c2d12" />
          <rect x="16" y="48" width="32" height="48" fill="#ef4444" />
          <rect x="112" y="48" width="32" height="48" fill="#ef4444" />
          <rect x="40" y="32" width="80" height="80" fill="#fbbf24" />
          <rect x="52" y="48" width="16" height="16" fill="#7c2d12" />
          <rect x="92" y="48" width="16" height="16" fill="#7c2d12" />
          <rect x="68" y="72" width="24" height="16" fill="#f97316" />
          <rect x="64" y="16" width="32" height="24" fill="#ef4444" />
          <rect x="48" y="112" width="64" height="24" fill="#ea580c" />
        </svg>
      )
    case 'mermaid':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#164e63" />
          <rect x="44" y="24" width="72" height="64" fill="#fbcfe8" />
          <rect x="52" y="12" width="56" height="24" fill="#67e8f9" />
          <rect x="56" y="44" width="12" height="12" fill="#164e63" />
          <rect x="92" y="44" width="12" height="12" fill="#164e63" />
          <rect x="68" y="64" width="24" height="8" fill="#db2777" />
          <rect x="48" y="88" width="64" height="40" fill="#22d3ee" />
          <rect x="36" y="120" width="24" height="16" fill="#067a8a" />
          <rect x="100" y="120" width="24" height="16" fill="#067a8a" />
        </svg>
      )
    case 'cyborg':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#111827" />
          <rect x="36" y="28" width="88" height="96" fill="#94a3b8" />
          <rect x="44" y="36" width="72" height="48" fill="#475569" />
          <rect x="52" y="48" width="20" height="20" fill="#22d3ee" />
          <rect x="88" y="48" width="20" height="20" fill="#ef4444" />
          <rect x="56" y="52" width="12" height="12" fill="#0e7490" />
          <rect x="92" y="52" width="12" height="12" fill="#7f1d1d" />
          <rect x="60" y="96" width="40" height="8" fill="#1e293b" />
          <rect x="28" y="60" width="12" height="8" fill="#22d3ee" />
          <rect x="120" y="72" width="12" height="8" fill="#22d3ee" />
          <rect x="48" y="124" width="64" height="16" fill="#334155" />
        </svg>
      )
    case 'hacker':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#052e16" />
          <rect x="32" y="40" width="96" height="80" fill="#14532d" />
          <rect x="40" y="48" width="80" height="48" fill="#4ade80" />
          <rect x="52" y="60" width="12" height="12" fill="#052e16" />
          <rect x="96" y="60" width="12" height="12" fill="#052e16" />
          <rect x="64" y="80" width="32" height="8" fill="#052e16" />
          <rect x="48" y="20" width="64" height="20" fill="#166534" />
          <rect x="24" y="100" width="16" height="8" fill="#4ade80" />
          <rect x="120" y="56" width="16" height="8" fill="#4ade80" />
        </svg>
      )
    case 'drone':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#0f172a" />
          <rect x="16" y="40" width="32" height="8" fill="#38bdf8" />
          <rect x="112" y="40" width="32" height="8" fill="#38bdf8" />
          <rect x="20" y="32" width="24" height="8" fill="#64748b" />
          <rect x="116" y="32" width="24" height="8" fill="#64748b" />
          <rect x="48" y="56" width="64" height="48" fill="#38bdf8" />
          <rect x="56" y="64" width="48" height="32" fill="#1e293b" />
          <rect x="68" y="72" width="24" height="16" fill="#f43f5e" />
          <rect x="76" y="76" width="8" height="8" fill="#fecdd3" />
          <rect x="64" y="112" width="32" height="16" fill="#334155" />
        </svg>
      )
    case 'matrix':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#022c22" />
          <rect x="24" y="16" width="8" height="128" fill="#14532d" />
          <rect x="48" y="8" width="8" height="144" fill="#22c55e" />
          <rect x="72" y="24" width="8" height="112" fill="#86efac" />
          <rect x="96" y="12" width="8" height="136" fill="#22c55e" />
          <rect x="120" y="20" width="8" height="120" fill="#14532d" />
          <rect x="52" y="56" width="56" height="48" fill="#052e16" />
          <rect x="60" y="68" width="12" height="12" fill="#86efac" />
          <rect x="88" y="68" width="12" height="12" fill="#86efac" />
          <rect x="68" y="88" width="24" height="8" fill="#22c55e" />
        </svg>
      )
    case 'laser':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#1e1b4b" />
          <rect x="0" y="72" width="160" height="8" fill="#22d3ee" />
          <rect x="0" y="88" width="160" height="8" fill="#f472b6" />
          <rect x="44" y="32" width="72" height="72" fill="#312e81" />
          <rect x="52" y="40" width="56" height="40" fill="#f472b6" />
          <rect x="60" y="48" width="12" height="12" fill="#22d3ee" />
          <rect x="88" y="48" width="12" height="12" fill="#22d3ee" />
          <rect x="68" y="72" width="24" height="8" fill="#1e1b4b" />
          <rect x="56" y="112" width="48" height="24" fill="#4c1d95" />
        </svg>
      )
    case 'android':
      return (
        <svg viewBox="0 0 160 160" className="size-full" aria-hidden shapeRendering="crispEdges">
          <rect width="160" height="160" fill="#1e293b" />
          <rect x="48" y="20" width="8" height="20" fill="#38bdf8" />
          <rect x="104" y="20" width="8" height="20" fill="#38bdf8" />
          <rect x="40" y="36" width="80" height="72" fill="#a3e635" />
          <rect x="52" y="52" width="16" height="16" fill="#1e293b" />
          <rect x="92" y="52" width="16" height="16" fill="#1e293b" />
          <rect x="56" y="56" width="8" height="8" fill="#38bdf8" />
          <rect x="96" y="56" width="8" height="8" fill="#38bdf8" />
          <rect x="64" y="80" width="32" height="8" fill="#1e293b" />
          <rect x="32" y="60" width="12" height="32" fill="#a3e635" />
          <rect x="116" y="60" width="12" height="32" fill="#a3e635" />
          <rect x="52" y="116" width="24" height="20" fill="#65a30d" />
          <rect x="84" y="116" width="24" height="20" fill="#65a30d" />
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
