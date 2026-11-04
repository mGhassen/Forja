import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class _AvatarPalette {
  const _AvatarPalette(this.background, this.foreground, this.accent);

  final Color background;
  final Color foreground;
  final Color accent;
}

const Map<String, _AvatarPalette> _avatarPalettes = {
  'forge': _AvatarPalette(
    Color(0xFF1B1B1B),
    Color(0xFF1CE783),
    Color(0xFF0A2D21),
  ),
  'flame': _AvatarPalette(
    Color(0xFFFF4D1C),
    Color(0xFFFFD1A8),
    Color(0xFF3A130A),
  ),
  'mint': _AvatarPalette(
    Color(0xFF1CE783),
    Color(0xFFF5FFF9),
    Color(0xFF0C3B2A),
  ),
  'captain': _AvatarPalette(
    Color(0xFF123A68),
    Color(0xFFF4C7A1),
    Color(0xFFFACC15),
  ),
  'rebel': _AvatarPalette(
    Color(0xFF9F1239),
    Color(0xFFFFD2B3),
    Color(0xFF1F1020),
  ),
  'ninja': _AvatarPalette(
    Color(0xFF111827),
    Color(0xFFC084FC),
    Color(0xFF05070C),
  ),
  'royal': _AvatarPalette(
    Color(0xFF6D28D9),
    Color(0xFFF6D0AD),
    Color(0xFFFACC15),
  ),
  'racer': _AvatarPalette(
    Color(0xFFDC2626),
    Color(0xFFF8D5BA),
    Color(0xFF111827),
  ),
  'night': _AvatarPalette(
    Color(0xFF10172C),
    Color(0xFF64748B),
    Color(0xFF1CE783),
  ),
  'panda': _AvatarPalette(
    Color(0xFFF8FAFC),
    Color(0xFF111827),
    Color(0xFFFB7185),
  ),
  'fox': _AvatarPalette(
    Color(0xFFEA580C),
    Color(0xFFFFF7ED),
    Color(0xFF431407),
  ),
  'owl': _AvatarPalette(
    Color(0xFF92400E),
    Color(0xFFFDE68A),
    Color(0xFF1E3A8A),
  ),
  'shark': _AvatarPalette(
    Color(0xFF0369A1),
    Color(0xFFBAE6FD),
    Color(0xFF172554),
  ),
  'dragon': _AvatarPalette(
    Color(0xFF166534),
    Color(0xFF86EFAC),
    Color(0xFFFACC15),
  ),
  'bunny': _AvatarPalette(
    Color(0xFFF9A8D4),
    Color(0xFFFFF1F2),
    Color(0xFF831843),
  ),
  'yeti': _AvatarPalette(
    Color(0xFFDBEAFE),
    Color(0xFFF8FAFC),
    Color(0xFF1E40AF),
  ),
  'orbit': _AvatarPalette(
    Color(0xFF3978D5),
    Color(0xFFDCECFF),
    Color(0xFF152B4D),
  ),
  'comet': _AvatarPalette(
    Color(0xFF312E81),
    Color(0xFFF97316),
    Color(0xFFFEF3C7),
  ),
  'nova': _AvatarPalette(
    Color(0xFF701A75),
    Color(0xFFF0ABFC),
    Color(0xFFFACC15),
  ),
  'alien': _AvatarPalette(
    Color(0xFF052E16),
    Color(0xFF4ADE80),
    Color(0xFF111827),
  ),
  'rover': _AvatarPalette(
    Color(0xFF7C2D12),
    Color(0xFFFED7AA),
    Color(0xFF292524),
  ),
  'lunar': _AvatarPalette(
    Color(0xFF1E293B),
    Color(0xFFE2E8F0),
    Color(0xFF38BDF8),
  ),
  'solar': _AvatarPalette(
    Color(0xFF9A3412),
    Color(0xFFFACC15),
    Color(0xFFFFF7ED),
  ),
  'void': _AvatarPalette(
    Color(0xFF020617),
    Color(0xFF7C3AED),
    Color(0xFF22D3EE),
  ),
  'pixel': _AvatarPalette(
    Color(0xFF7C3AED),
    Color(0xFFDED7FF),
    Color(0xFF1CE783),
  ),
  'arcade': _AvatarPalette(
    Color(0xFF172554),
    Color(0xFF22D3EE),
    Color(0xFFF472B6),
  ),
  'cassette': _AvatarPalette(
    Color(0xFFF59E0B),
    Color(0xFF292524),
    Color(0xFFFEF3C7),
  ),
  'glitch': _AvatarPalette(
    Color(0xFF111827),
    Color(0xFFEF4444),
    Color(0xFF22D3EE),
  ),
  'neon': _AvatarPalette(
    Color(0xFF4A044E),
    Color(0xFFF0ABFC),
    Color(0xFFA3E635),
  ),
  'synth': _AvatarPalette(
    Color(0xFF312E81),
    Color(0xFFFB7185),
    Color(0xFF67E8F9),
  ),
  'invader': _AvatarPalette(
    Color(0xFF0B1026),
    Color(0xFF4ADE80),
    Color(0xFFFACC15),
  ),
  'ghost': _AvatarPalette(
    Color(0xFF1E1B4B),
    Color(0xFFFDA4AF),
    Color(0xFF67E8F9),
  ),
  'knight': _AvatarPalette(
    Color(0xFF1F2937),
    Color(0xFFCBD5E1),
    Color(0xFFFACC15),
  ),
  'wizard': _AvatarPalette(
    Color(0xFF2E1065),
    Color(0xFFE9D5FF),
    Color(0xFFFACC15),
  ),
  'toad': _AvatarPalette(
    Color(0xFF14532D),
    Color(0xFFFECACA),
    Color(0xFFEF4444),
  ),
  'heartbit': _AvatarPalette(
    Color(0xFF4C0519),
    Color(0xFFFB7185),
    Color(0xFFFEF3C7),
  ),
  'boombox': _AvatarPalette(
    Color(0xFF1C1917),
    Color(0xFFF97316),
    Color(0xFF22D3EE),
  ),
  'chip': _AvatarPalette(
    Color(0xFF052E16),
    Color(0xFF86EFAC),
    Color(0xFFA3E635),
  ),
  'wolf': _AvatarPalette(
    Color(0xFF1C1917),
    Color(0xFFA8A29E),
    Color(0xFFFACC15),
  ),
  'bear': _AvatarPalette(
    Color(0xFF44403C),
    Color(0xFFD6D3D1),
    Color(0xFF292524),
  ),
  'penguin': _AvatarPalette(
    Color(0xFF0C4A6E),
    Color(0xFFF8FAFC),
    Color(0xFFF97316),
  ),
  'frog': _AvatarPalette(
    Color(0xFF14532D),
    Color(0xFF4ADE80),
    Color(0xFFFACC15),
  ),
  'lion': _AvatarPalette(
    Color(0xFF9A3412),
    Color(0xFFFDBA74),
    Color(0xFFFACC15),
  ),
  'bee': _AvatarPalette(
    Color(0xFF1E3A8A),
    Color(0xFFFACC15),
    Color(0xFF111827),
  ),
  'elf': _AvatarPalette(
    Color(0xFF064E3B),
    Color(0xFFFDE68A),
    Color(0xFF67E8F9),
  ),
  'orc': _AvatarPalette(
    Color(0xFF365314),
    Color(0xFFA3E635),
    Color(0xFF431407),
  ),
  'fairy': _AvatarPalette(
    Color(0xFF831843),
    Color(0xFFFBCFE8),
    Color(0xFFA78BFA),
  ),
  'golem': _AvatarPalette(
    Color(0xFF292524),
    Color(0xFFA8A29E),
    Color(0xFF22D3EE),
  ),
  'phoenix': _AvatarPalette(
    Color(0xFF7C2D12),
    Color(0xFFFBBF24),
    Color(0xFFEF4444),
  ),
  'mermaid': _AvatarPalette(
    Color(0xFF164E63),
    Color(0xFFFBCFE8),
    Color(0xFF22D3EE),
  ),
  'cyborg': _AvatarPalette(
    Color(0xFF111827),
    Color(0xFF94A3B8),
    Color(0xFF22D3EE),
  ),
  'hacker': _AvatarPalette(
    Color(0xFF052E16),
    Color(0xFF4ADE80),
    Color(0xFF14532D),
  ),
  'drone': _AvatarPalette(
    Color(0xFF0F172A),
    Color(0xFF38BDF8),
    Color(0xFFF43F5E),
  ),
  'matrix': _AvatarPalette(
    Color(0xFF022C22),
    Color(0xFF22C55E),
    Color(0xFF86EFAC),
  ),
  'laser': _AvatarPalette(
    Color(0xFF1E1B4B),
    Color(0xFFF472B6),
    Color(0xFF22D3EE),
  ),
  'android': _AvatarPalette(
    Color(0xFF1E293B),
    Color(0xFFA3E635),
    Color(0xFF38BDF8),
  ),
};

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

String _avatarSvg(String rawKey) {
  final key = _avatarPalettes.containsKey(rawKey) ? rawKey : 'forge';
  switch (key) {
    case 'flame':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="#ff4d1c"/>
  <path d="M0 128 30 95 58 116 88 84 121 112 160 76v84H0Z" fill="#24100b"/>
  <circle cx="80" cy="77" r="44" fill="#ffd1a8"/>
  <path d="M42 61c8-34 26-49 55-47-5 9-4 17 3 24 9-12 20-17 33-15-5 12-14 25-27 38Z" fill="#3a130a"/>
  <circle cx="64" cy="77" r="5" fill="#24100b"/>
  <circle cx="98" cy="77" r="5" fill="#24100b"/>
  <path d="M62 99c13 10 26 10 39 0" fill="none" stroke="#24100b" stroke-width="6" stroke-linecap="round"/>
</svg>''';
    case 'orbit':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="#3978d5"/>
  <circle cx="25" cy="28" r="3" fill="#fff"/><circle cx="134" cy="38" r="4" fill="#fff"/><circle cx="116" cy="16" r="2" fill="#fff"/>
  <circle cx="80" cy="82" r="58" fill="#dcecff"/><circle cx="80" cy="78" r="43" fill="#152b4d"/><circle cx="80" cy="82" r="31" fill="#b7dcff"/>
  <circle cx="68" cy="78" r="4" fill="#152b4d"/><circle cx="94" cy="78" r="4" fill="#152b4d"/>
  <path d="M67 96c9 6 18 6 27 0" fill="none" stroke="#152b4d" stroke-width="5" stroke-linecap="round"/>
  <path d="M33 137c28-19 65-19 94 0v23H33Z" fill="#e9f4ff"/><circle cx="126" cy="112" r="6" fill="#1ce783"/>
</svg>''';
    case 'pixel':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="#7c3aed"/><rect x="29" y="32" width="102" height="96" rx="9" fill="#ded7ff"/>
  <rect x="42" y="48" width="76" height="51" fill="#211747"/><rect x="53" y="62" width="13" height="13" fill="#1ce783"/>
  <rect x="94" y="62" width="13" height="13" fill="#1ce783"/><rect x="62" y="84" width="36" height="6" fill="#c084fc"/>
  <rect x="70" y="18" width="20" height="16" fill="#ded7ff"/><rect x="76" y="7" width="8" height="15" fill="#ded7ff"/>
  <rect x="43" y="111" width="18" height="8" fill="#7c3aed"/><rect x="70" y="111" width="18" height="8" fill="#7c3aed"/><rect x="97" y="111" width="18" height="8" fill="#7c3aed"/>
</svg>''';
    case 'arcade':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#172554"/>
  <rect x="28" y="16" width="104" height="128" fill="#0f172a"/>
  <rect x="36" y="24" width="88" height="56" fill="#22d3ee"/>
  <rect x="44" y="32" width="72" height="40" fill="#082f49"/>
  <rect x="56" y="40" width="12" height="12" fill="#f472b6"/>
  <rect x="92" y="40" width="12" height="12" fill="#f472b6"/>
  <rect x="64" y="60" width="32" height="6" fill="#facc15"/>
  <rect x="44" y="92" width="28" height="10" fill="#334155"/>
  <rect x="88" y="88" width="16" height="16" rx="8" fill="#ef4444"/>
  <rect x="92" y="92" width="8" height="8" fill="#fecaca"/>
  <rect x="48" y="112" width="12" height="12" fill="#22d3ee"/>
  <rect x="68" y="112" width="12" height="12" fill="#f472b6"/>
  <rect x="88" y="112" width="12" height="12" fill="#facc15"/>
  <rect x="108" y="112" width="12" height="12" fill="#a3e635"/>
</svg>''';
    case 'cassette':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#f59e0b"/>
  <rect x="20" y="36" width="120" height="88" fill="#292524"/>
  <rect x="28" y="44" width="104" height="56" fill="#fef3c7"/>
  <rect x="40" y="56" width="28" height="28" fill="#292524"/>
  <rect x="92" y="56" width="28" height="28" fill="#292524"/>
  <rect x="48" y="64" width="12" height="12" fill="#22d3ee"/>
  <rect x="100" y="64" width="12" height="12" fill="#22d3ee"/>
  <rect x="72" y="62" width="16" height="16" fill="#f59e0b"/>
  <rect x="44" y="108" width="72" height="8" fill="#78716c"/>
  <rect x="52" y="24" width="16" height="12" fill="#292524"/>
  <rect x="92" y="24" width="16" height="12" fill="#292524"/>
</svg>''';
    case 'glitch':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#111827"/>
  <rect x="34" y="28" width="92" height="104" fill="#ef4444"/>
  <rect x="30" y="32" width="92" height="104" fill="#22d3ee"/>
  <rect x="38" y="36" width="84" height="92" fill="#1f2937"/>
  <rect x="50" y="56" width="16" height="16" fill="#ef4444"/>
  <rect x="94" y="56" width="16" height="16" fill="#22d3ee"/>
  <rect x="48" y="84" width="64" height="8" fill="#f8fafc"/>
  <rect x="56" y="96" width="48" height="8" fill="#a3e635"/>
  <rect x="20" y="48" width="12" height="4" fill="#ef4444"/>
  <rect x="128" y="72" width="16" height="4" fill="#22d3ee"/>
  <rect x="16" y="100" width="20" height="4" fill="#a3e635"/>
</svg>''';
    case 'neon':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#4a044e"/>
  <rect x="36" y="28" width="88" height="104" fill="#701a75"/>
  <rect x="44" y="36" width="72" height="72" fill="#2e1065"/>
  <rect x="52" y="52" width="16" height="16" fill="#a3e635"/>
  <rect x="92" y="52" width="16" height="16" fill="#a3e635"/>
  <rect x="56" y="56" width="8" height="8" fill="#4a044e"/>
  <rect x="96" y="56" width="8" height="8" fill="#4a044e"/>
  <rect x="60" y="84" width="40" height="8" fill="#f0abfc"/>
  <rect x="40" y="116" width="80" height="8" fill="#f0abfc"/>
  <rect x="72" y="16" width="16" height="12" fill="#a3e635"/>
  <rect x="24" y="40" width="8" height="8" fill="#f0abfc"/>
  <rect x="128" y="64" width="8" height="8" fill="#a3e635"/>
</svg>''';
    case 'synth':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#312e81"/>
  <rect x="0" y="104" width="160" height="8" fill="#fb7185"/>
  <rect x="0" y="112" width="160" height="8" fill="#f97316"/>
  <rect x="0" y="120" width="160" height="8" fill="#facc15"/>
  <rect x="0" y="128" width="160" height="8" fill="#67e8f9"/>
  <rect x="40" y="28" width="80" height="72" fill="#fde68a"/>
  <rect x="36" y="52" width="88" height="20" fill="#111827"/>
  <rect x="48" y="56" width="24" height="12" fill="#67e8f9"/>
  <rect x="88" y="56" width="24" height="12" fill="#fb7185"/>
  <rect x="64" y="80" width="32" height="8" fill="#831843"/>
  <rect x="52" y="16" width="56" height="16" fill="#1e1b4b"/>
</svg>''';
    case 'invader':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#0b1026"/>
  <rect x="20" y="20" width="8" height="8" fill="#4ade80"/><rect x="132" y="36" width="8" height="8" fill="#facc15"/>
  <rect x="48" y="28" width="8" height="8" fill="#4ade80"/><rect x="104" y="28" width="8" height="8" fill="#4ade80"/>
  <rect x="40" y="36" width="8" height="8" fill="#4ade80"/><rect x="48" y="36" width="64" height="8" fill="#4ade80"/><rect x="112" y="36" width="8" height="8" fill="#4ade80"/>
  <rect x="32" y="44" width="96" height="8" fill="#4ade80"/>
  <rect x="32" y="52" width="24" height="8" fill="#4ade80"/><rect x="64" y="52" width="32" height="8" fill="#4ade80"/><rect x="104" y="52" width="24" height="8" fill="#4ade80"/>
  <rect x="32" y="60" width="96" height="8" fill="#4ade80"/>
  <rect x="48" y="56" width="16" height="8" fill="#0b1026"/><rect x="96" y="56" width="16" height="8" fill="#0b1026"/>
  <rect x="40" y="68" width="16" height="8" fill="#4ade80"/><rect x="72" y="68" width="16" height="8" fill="#4ade80"/><rect x="104" y="68" width="16" height="8" fill="#4ade80"/>
  <rect x="32" y="76" width="8" height="8" fill="#4ade80"/><rect x="120" y="76" width="8" height="8" fill="#4ade80"/>
  <rect x="64" y="84" width="8" height="8" fill="#facc15"/><rect x="88" y="84" width="8" height="8" fill="#facc15"/>
</svg>''';
    case 'ghost':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#1e1b4b"/>
  <rect x="48" y="28" width="64" height="8" fill="#fda4af"/>
  <rect x="40" y="36" width="80" height="8" fill="#fda4af"/>
  <rect x="32" y="44" width="96" height="64" fill="#fda4af"/>
  <rect x="32" y="108" width="16" height="16" fill="#fda4af"/><rect x="56" y="108" width="16" height="16" fill="#fda4af"/>
  <rect x="80" y="108" width="16" height="16" fill="#fda4af"/><rect x="104" y="108" width="16" height="16" fill="#fda4af"/>
  <rect x="48" y="60" width="16" height="20" fill="#67e8f9"/><rect x="96" y="60" width="16" height="20" fill="#67e8f9"/>
  <rect x="52" y="64" width="8" height="8" fill="#1e1b4b"/><rect x="100" y="64" width="8" height="8" fill="#1e1b4b"/>
  <rect x="72" y="88" width="16" height="8" fill="#fb7185"/>
</svg>''';
    case 'knight':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#1f2937"/>
  <rect x="56" y="16" width="48" height="12" fill="#facc15"/>
  <rect x="64" y="8" width="32" height="8" fill="#facc15"/>
  <rect x="40" y="28" width="80" height="88" fill="#cbd5e1"/>
  <rect x="48" y="36" width="64" height="64" fill="#94a3b8"/>
  <rect x="40" y="60" width="80" height="16" fill="#0f172a"/>
  <rect x="52" y="64" width="20" height="8" fill="#38bdf8"/><rect x="88" y="64" width="20" height="8" fill="#38bdf8"/>
  <rect x="68" y="88" width="24" height="8" fill="#1f2937"/>
  <rect x="32" y="116" width="96" height="24" fill="#64748b"/>
  <rect x="48" y="124" width="64" height="8" fill="#facc15"/>
</svg>''';
    case 'wizard':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#2e1065"/>
  <rect x="72" y="8" width="16" height="16" fill="#facc15"/>
  <rect x="64" y="24" width="32" height="16" fill="#7c3aed"/>
  <rect x="48" y="40" width="64" height="16" fill="#7c3aed"/>
  <rect x="32" y="56" width="96" height="12" fill="#a78bfa"/>
  <rect x="44" y="68" width="72" height="56" fill="#e9d5ff"/>
  <rect x="56" y="80" width="12" height="12" fill="#2e1065"/><rect x="92" y="80" width="12" height="12" fill="#2e1065"/>
  <rect x="68" y="100" width="24" height="8" fill="#c084fc"/>
  <rect x="52" y="116" width="56" height="20" fill="#f8fafc"/>
  <rect x="120" y="72" width="8" height="8" fill="#facc15"/><rect x="28" y="88" width="8" height="8" fill="#67e8f9"/>
</svg>''';
    case 'toad':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#14532d"/>
  <rect x="36" y="20" width="88" height="64" fill="#fecaca"/>
  <rect x="48" y="12" width="64" height="16" fill="#fecaca"/>
  <rect x="44" y="28" width="20" height="20" fill="#ef4444"/><rect x="96" y="28" width="20" height="20" fill="#ef4444"/>
  <rect x="72" y="48" width="16" height="16" fill="#ef4444"/>
  <rect x="48" y="76" width="64" height="48" fill="#fed7aa"/>
  <rect x="56" y="88" width="12" height="12" fill="#14532d"/><rect x="92" y="88" width="12" height="12" fill="#14532d"/>
  <rect x="72" y="104" width="16" height="8" fill="#fb7185"/>
  <rect x="56" y="124" width="20" height="16" fill="#fdba74"/><rect x="84" y="124" width="20" height="16" fill="#fdba74"/>
</svg>''';
    case 'heartbit':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#4c0519"/>
  <rect x="36" y="36" width="32" height="24" fill="#fb7185"/><rect x="92" y="36" width="32" height="24" fill="#fb7185"/>
  <rect x="28" y="52" width="104" height="40" fill="#fb7185"/>
  <rect x="40" y="92" width="80" height="24" fill="#fb7185"/>
  <rect x="56" y="116" width="48" height="16" fill="#fb7185"/>
  <rect x="68" y="132" width="24" height="8" fill="#fb7185"/>
  <rect x="52" y="64" width="16" height="16" fill="#fef3c7"/><rect x="92" y="64" width="16" height="16" fill="#fef3c7"/>
  <rect x="56" y="68" width="8" height="8" fill="#4c0519"/><rect x="96" y="68" width="8" height="8" fill="#4c0519"/>
  <rect x="68" y="92" width="24" height="8" fill="#be123c"/>
</svg>''';
    case 'boombox':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#1c1917"/>
  <rect x="20" y="44" width="120" height="80" fill="#292524"/>
  <rect x="28" y="52" width="40" height="40" fill="#f97316"/>
  <rect x="92" y="52" width="40" height="40" fill="#f97316"/>
  <rect x="36" y="60" width="24" height="24" fill="#1c1917"/>
  <rect x="100" y="60" width="24" height="24" fill="#1c1917"/>
  <rect x="44" y="68" width="8" height="8" fill="#22d3ee"/><rect x="108" y="68" width="8" height="8" fill="#22d3ee"/>
  <rect x="72" y="56" width="16" height="32" fill="#44403c"/>
  <rect x="76" y="60" width="8" height="8" fill="#a3e635"/><rect x="76" y="76" width="8" height="8" fill="#ef4444"/>
  <rect x="48" y="100" width="64" height="12" fill="#57534e"/>
  <rect x="56" y="28" width="48" height="16" fill="#44403c"/>
  <rect x="64" y="20" width="8" height="12" fill="#22d3ee"/><rect x="88" y="20" width="8" height="12" fill="#22d3ee"/>
</svg>''';
    case 'chip':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#052e16"/>
  <rect x="16" y="56" width="12" height="8" fill="#86efac"/><rect x="16" y="76" width="12" height="8" fill="#86efac"/><rect x="16" y="96" width="12" height="8" fill="#86efac"/>
  <rect x="132" y="56" width="12" height="8" fill="#86efac"/><rect x="132" y="76" width="12" height="8" fill="#86efac"/><rect x="132" y="96" width="12" height="8" fill="#86efac"/>
  <rect x="48" y="16" width="8" height="12" fill="#86efac"/><rect x="76" y="16" width="8" height="12" fill="#86efac"/><rect x="104" y="16" width="8" height="12" fill="#86efac"/>
  <rect x="48" y="132" width="8" height="12" fill="#86efac"/><rect x="76" y="132" width="8" height="12" fill="#86efac"/><rect x="104" y="132" width="8" height="12" fill="#86efac"/>
  <rect x="36" y="36" width="88" height="88" fill="#166534"/>
  <rect x="48" y="48" width="64" height="64" fill="#14532d"/>
  <rect x="56" y="60" width="16" height="16" fill="#a3e635"/><rect x="88" y="60" width="16" height="16" fill="#a3e635"/>
  <rect x="60" y="64" width="8" height="8" fill="#052e16"/><rect x="92" y="64" width="8" height="8" fill="#052e16"/>
  <rect x="64" y="92" width="32" height="8" fill="#86efac"/>
</svg>''';
    case 'wolf':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#1c1917"/>
  <rect x="36" y="36" width="88" height="72" fill="#a8a29e"/>
  <rect x="28" y="28" width="24" height="32" fill="#a8a29e"/><rect x="108" y="28" width="24" height="32" fill="#a8a29e"/>
  <rect x="48" y="56" width="16" height="16" fill="#facc15"/><rect x="96" y="56" width="16" height="16" fill="#facc15"/>
  <rect x="52" y="60" width="8" height="8" fill="#1c1917"/><rect x="100" y="60" width="8" height="8" fill="#1c1917"/>
  <rect x="68" y="76" width="24" height="16" fill="#78716c"/>
  <rect x="76" y="80" width="8" height="8" fill="#1c1917"/>
  <rect x="44" y="108" width="72" height="24" fill="#57534e"/>
</svg>''';
    case 'bear':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#44403c"/>
  <rect x="32" y="24" width="24" height="24" fill="#d6d3d1"/><rect x="104" y="24" width="24" height="24" fill="#d6d3d1"/>
  <rect x="40" y="40" width="80" height="72" fill="#d6d3d1"/>
  <rect x="56" y="60" width="16" height="16" fill="#292524"/><rect x="88" y="60" width="16" height="16" fill="#292524"/>
  <rect x="68" y="84" width="24" height="16" fill="#a8a29e"/>
  <rect x="76" y="88" width="8" height="8" fill="#292524"/>
  <rect x="48" y="112" width="64" height="24" fill="#78716c"/>
</svg>''';
    case 'penguin':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#0c4a6e"/>
  <rect x="48" y="24" width="64" height="96" fill="#0f172a"/>
  <rect x="56" y="48" width="48" height="64" fill="#f8fafc"/>
  <rect x="60" y="40" width="12" height="12" fill="#f8fafc"/><rect x="88" y="40" width="12" height="12" fill="#f8fafc"/>
  <rect x="64" y="44" width="4" height="4" fill="#0f172a"/><rect x="92" y="44" width="4" height="4" fill="#0f172a"/>
  <rect x="72" y="56" width="16" height="12" fill="#f97316"/>
  <rect x="40" y="72" width="16" height="32" fill="#0f172a"/><rect x="104" y="72" width="16" height="32" fill="#0f172a"/>
  <rect x="56" y="120" width="20" height="12" fill="#f97316"/><rect x="84" y="120" width="20" height="12" fill="#f97316"/>
</svg>''';
    case 'frog':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#14532d"/>
  <rect x="36" y="48" width="88" height="64" fill="#4ade80"/>
  <rect x="40" y="28" width="32" height="32" fill="#4ade80"/><rect x="88" y="28" width="32" height="32" fill="#4ade80"/>
  <rect x="48" y="36" width="16" height="16" fill="#facc15"/><rect x="96" y="36" width="16" height="16" fill="#facc15"/>
  <rect x="52" y="40" width="8" height="8" fill="#14532d"/><rect x="100" y="40" width="8" height="8" fill="#14532d"/>
  <rect x="68" y="80" width="24" height="8" fill="#166534"/>
  <rect x="44" y="112" width="24" height="16" fill="#22c55e"/><rect x="92" y="112" width="24" height="16" fill="#22c55e"/>
</svg>''';
    case 'lion':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#9a3412"/>
  <rect x="24" y="32" width="112" height="96" fill="#ea580c"/>
  <rect x="44" y="48" width="72" height="64" fill="#fdba74"/>
  <rect x="56" y="64" width="16" height="16" fill="#431407"/><rect x="88" y="64" width="16" height="16" fill="#431407"/>
  <rect x="68" y="88" width="24" height="12" fill="#f97316"/>
  <rect x="76" y="92" width="8" height="8" fill="#431407"/>
  <rect x="64" y="24" width="32" height="16" fill="#facc15"/>
</svg>''';
    case 'bee':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#1e3a8a"/>
  <rect x="20" y="48" width="32" height="40" fill="#e2e8f0"/><rect x="108" y="48" width="32" height="40" fill="#e2e8f0"/>
  <rect x="48" y="40" width="64" height="80" fill="#facc15"/>
  <rect x="48" y="56" width="64" height="12" fill="#111827"/>
  <rect x="48" y="80" width="64" height="12" fill="#111827"/>
  <rect x="60" y="48" width="12" height="12" fill="#111827"/><rect x="88" y="48" width="12" height="12" fill="#111827"/>
  <rect x="72" y="28" width="16" height="12" fill="#111827"/>
</svg>''';
    case 'elf':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#064e3b"/>
  <rect x="28" y="44" width="24" height="12" fill="#fde68a"/><rect x="108" y="44" width="24" height="12" fill="#fde68a"/>
  <rect x="44" y="36" width="72" height="72" fill="#fde68a"/>
  <rect x="52" y="24" width="56" height="24" fill="#067a55"/>
  <rect x="56" y="56" width="12" height="12" fill="#064e3b"/><rect x="92" y="56" width="12" height="12" fill="#064e3b"/>
  <rect x="68" y="80" width="24" height="8" fill="#67e8f9"/>
  <rect x="48" y="108" width="64" height="28" fill="#0f766e"/>
</svg>''';
    case 'orc':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#365314"/>
  <rect x="36" y="36" width="88" height="80" fill="#a3e635"/>
  <rect x="40" y="20" width="16" height="28" fill="#a3e635"/><rect x="104" y="20" width="16" height="28" fill="#a3e635"/>
  <rect x="52" y="56" width="16" height="16" fill="#431407"/><rect x="92" y="56" width="16" height="16" fill="#431407"/>
  <rect x="68" y="80" width="24" height="16" fill="#65a30d"/>
  <rect x="72" y="84" width="6" height="12" fill="#f8fafc"/><rect x="82" y="84" width="6" height="12" fill="#f8fafc"/>
  <rect x="40" y="116" width="80" height="24" fill="#3f6212"/>
</svg>''';
    case 'fairy':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#831843"/>
  <rect x="12" y="40" width="28" height="48" fill="#a78bfa"/><rect x="120" y="40" width="28" height="48" fill="#a78bfa"/>
  <rect x="44" y="36" width="72" height="72" fill="#fbcfe8"/>
  <rect x="56" y="20" width="48" height="24" fill="#f9a8d4"/>
  <rect x="56" y="56" width="12" height="12" fill="#831843"/><rect x="92" y="56" width="12" height="12" fill="#831843"/>
  <rect x="68" y="80" width="24" height="8" fill="#db2777"/>
  <rect x="60" y="108" width="40" height="28" fill="#c026d3"/>
  <rect x="76" y="8" width="8" height="12" fill="#facc15"/>
</svg>''';
    case 'golem':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#292524"/>
  <rect x="32" y="28" width="96" height="100" fill="#a8a29e"/>
  <rect x="40" y="36" width="80" height="56" fill="#78716c"/>
  <rect x="52" y="48" width="20" height="20" fill="#22d3ee"/><rect x="88" y="48" width="20" height="20" fill="#22d3ee"/>
  <rect x="56" y="52" width="12" height="12" fill="#0e7490"/><rect x="92" y="52" width="12" height="12" fill="#0e7490"/>
  <rect x="60" y="84" width="40" height="12" fill="#57534e"/>
  <rect x="44" y="112" width="28" height="16" fill="#57534e"/><rect x="88" y="112" width="28" height="16" fill="#57534e"/>
</svg>''';
    case 'phoenix':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#7c2d12"/>
  <rect x="16" y="48" width="32" height="48" fill="#ef4444"/><rect x="112" y="48" width="32" height="48" fill="#ef4444"/>
  <rect x="40" y="32" width="80" height="80" fill="#fbbf24"/>
  <rect x="52" y="48" width="16" height="16" fill="#7c2d12"/><rect x="92" y="48" width="16" height="16" fill="#7c2d12"/>
  <rect x="68" y="72" width="24" height="16" fill="#f97316"/>
  <rect x="64" y="16" width="32" height="24" fill="#ef4444"/>
  <rect x="48" y="112" width="64" height="24" fill="#ea580c"/>
</svg>''';
    case 'mermaid':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#164e63"/>
  <rect x="44" y="24" width="72" height="64" fill="#fbcfe8"/>
  <rect x="52" y="12" width="56" height="24" fill="#67e8f9"/>
  <rect x="56" y="44" width="12" height="12" fill="#164e63"/><rect x="92" y="44" width="12" height="12" fill="#164e63"/>
  <rect x="68" y="64" width="24" height="8" fill="#db2777"/>
  <rect x="48" y="88" width="64" height="40" fill="#22d3ee"/>
  <rect x="36" y="120" width="24" height="16" fill="#067a8a"/><rect x="100" y="120" width="24" height="16" fill="#067a8a"/>
</svg>''';
    case 'cyborg':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#111827"/>
  <rect x="36" y="28" width="88" height="96" fill="#94a3b8"/>
  <rect x="44" y="36" width="72" height="48" fill="#475569"/>
  <rect x="52" y="48" width="20" height="20" fill="#22d3ee"/><rect x="88" y="48" width="20" height="20" fill="#ef4444"/>
  <rect x="56" y="52" width="12" height="12" fill="#0e7490"/><rect x="92" y="52" width="12" height="12" fill="#7f1d1d"/>
  <rect x="60" y="96" width="40" height="8" fill="#1e293b"/>
  <rect x="28" y="60" width="12" height="8" fill="#22d3ee"/><rect x="120" y="72" width="12" height="8" fill="#22d3ee"/>
  <rect x="48" y="124" width="64" height="16" fill="#334155"/>
</svg>''';
    case 'hacker':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#052e16"/>
  <rect x="32" y="40" width="96" height="80" fill="#14532d"/>
  <rect x="40" y="48" width="80" height="48" fill="#4ade80"/>
  <rect x="52" y="60" width="12" height="12" fill="#052e16"/><rect x="96" y="60" width="12" height="12" fill="#052e16"/>
  <rect x="64" y="80" width="32" height="8" fill="#052e16"/>
  <rect x="48" y="20" width="64" height="20" fill="#166534"/>
  <rect x="24" y="100" width="16" height="8" fill="#4ade80"/><rect x="120" y="56" width="16" height="8" fill="#4ade80"/>
</svg>''';
    case 'drone':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#0f172a"/>
  <rect x="16" y="40" width="32" height="8" fill="#38bdf8"/><rect x="112" y="40" width="32" height="8" fill="#38bdf8"/>
  <rect x="20" y="32" width="24" height="8" fill="#64748b"/><rect x="116" y="32" width="24" height="8" fill="#64748b"/>
  <rect x="48" y="56" width="64" height="48" fill="#38bdf8"/>
  <rect x="56" y="64" width="48" height="32" fill="#1e293b"/>
  <rect x="68" y="72" width="24" height="16" fill="#f43f5e"/>
  <rect x="76" y="76" width="8" height="8" fill="#fecdd3"/>
  <rect x="64" y="112" width="32" height="16" fill="#334155"/>
</svg>''';
    case 'matrix':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#022c22"/>
  <rect x="24" y="16" width="8" height="128" fill="#14532d"/><rect x="48" y="8" width="8" height="144" fill="#22c55e"/>
  <rect x="72" y="24" width="8" height="112" fill="#86efac"/><rect x="96" y="12" width="8" height="136" fill="#22c55e"/>
  <rect x="120" y="20" width="8" height="120" fill="#14532d"/>
  <rect x="52" y="56" width="56" height="48" fill="#052e16"/>
  <rect x="60" y="68" width="12" height="12" fill="#86efac"/><rect x="88" y="68" width="12" height="12" fill="#86efac"/>
  <rect x="68" y="88" width="24" height="8" fill="#22c55e"/>
</svg>''';
    case 'laser':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#1e1b4b"/>
  <rect x="0" y="72" width="160" height="8" fill="#22d3ee"/>
  <rect x="0" y="88" width="160" height="8" fill="#f472b6"/>
  <rect x="44" y="32" width="72" height="72" fill="#312e81"/>
  <rect x="52" y="40" width="56" height="40" fill="#f472b6"/>
  <rect x="60" y="48" width="12" height="12" fill="#22d3ee"/><rect x="88" y="48" width="12" height="12" fill="#22d3ee"/>
  <rect x="68" y="72" width="24" height="8" fill="#1e1b4b"/>
  <rect x="56" y="112" width="48" height="24" fill="#4c1d95"/>
</svg>''';
    case 'android':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">
  <rect width="160" height="160" fill="#1e293b"/>
  <rect x="48" y="20" width="8" height="20" fill="#38bdf8"/><rect x="104" y="20" width="8" height="20" fill="#38bdf8"/>
  <rect x="40" y="36" width="80" height="72" fill="#a3e635"/>
  <rect x="52" y="52" width="16" height="16" fill="#1e293b"/><rect x="92" y="52" width="16" height="16" fill="#1e293b"/>
  <rect x="56" y="56" width="8" height="8" fill="#38bdf8"/><rect x="96" y="56" width="8" height="8" fill="#38bdf8"/>
  <rect x="64" y="80" width="32" height="8" fill="#1e293b"/>
  <rect x="32" y="60" width="12" height="32" fill="#a3e635"/><rect x="116" y="60" width="12" height="32" fill="#a3e635"/>
  <rect x="52" y="116" width="24" height="20" fill="#65a30d"/><rect x="84" y="116" width="24" height="20" fill="#65a30d"/>
</svg>''';
    case 'night':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="#10172c"/><circle cx="126" cy="29" r="18" fill="#facc15"/><circle cx="136" cy="22" r="18" fill="#10172c"/>
  <path d="m42 62 13-29 24 22 25-22 14 30v68H42Z" fill="#64748b"/>
  <path d="m51 56 7-14 11 11ZM107 56l-7-14-11 11Z" fill="#fda4af"/>
  <ellipse cx="65" cy="83" rx="8" ry="10" fill="#1ce783"/><ellipse cx="96" cy="83" rx="8" ry="10" fill="#1ce783"/>
  <path d="m75 101 6 5 6-5" fill="#fda4af"/><path d="M53 107h18M90 107h18" stroke="#e2e8f0" stroke-width="3" stroke-linecap="round"/>
</svg>''';
    case 'mint':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="#1ce783"/><path d="M18 160c8-61 31-99 62-99s55 38 63 99Z" fill="#0c3b2a"/>
  <circle cx="56" cy="69" r="22" fill="#f5fff9"/><circle cx="104" cy="69" r="22" fill="#f5fff9"/>
  <circle cx="60" cy="72" r="9" fill="#0c3b2a"/><circle cx="100" cy="72" r="9" fill="#0c3b2a"/>
  <path d="M57 113c15 14 31 14 46 0" fill="none" stroke="#f5fff9" stroke-width="7" stroke-linecap="round"/>
  <path d="M35 42 17 21M125 42l18-21" stroke="#0c3b2a" stroke-width="10" stroke-linecap="round"/>
</svg>''';
    case 'forge':
      return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="#1b1b1b"/><circle cx="80" cy="77" r="49" fill="#1ce783"/>
  <path d="M32 63c7-33 25-49 52-49 25 0 42 14 49 41L103 43 82 57 61 43Z" fill="#0a2d21"/>
  <rect x="43" y="66" width="31" height="23" rx="5" fill="#111"/><rect x="86" y="66" width="31" height="23" rx="5" fill="#111"/>
  <rect x="74" y="73" width="12" height="5" fill="#111"/><circle cx="59" cy="77" r="4" fill="#1ce783"/><circle cx="101" cy="77" r="4" fill="#1ce783"/>
  <path d="M58 104c14 11 29 11 44 0" fill="none" stroke="#0a2d21" stroke-width="7" stroke-linecap="round"/>
  <path d="M29 160c8-30 25-45 51-45s44 15 52 45Z" fill="#124d39"/>
</svg>''';
  }

  final category = forjaProfileAvatarCategories.indexWhere(
    (entry) => entry.keys.contains(key),
  );
  final variant = category < 0
      ? 0
      : forjaProfileAvatarCategories[category].keys.indexOf(key);
  final palette = _avatarPalettes[key]!;
  final background = _hex(palette.background);
  final primary = _hex(palette.foreground);
  final accent = _hex(palette.accent);

  if (category == 0) {
    final hair = variant.isEven
        ? '<path d="M38 62c5-31 21-47 48-47 24 0 39 13 45 40L105 42 82 55 58 42Z" fill="$accent"/>'
        : '<path d="M36 61 48 24l31 12 29-13 17 38Z" fill="$accent"/>';
    final face = variant == 5
        ? '<path d="M39 70h82v28c-25 16-54 16-82 0Z" fill="$accent"/>'
        : '<circle cx="64" cy="77" r="5" fill="$accent"/><circle cx="97" cy="77" r="5" fill="$accent"/>';
    final crown = variant == 3
        ? '<path d="m55 35 9-23 16 18 17-18 10 23Z" fill="#facc15"/>'
        : '';
    return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="$background"/><path d="M22 160c8-34 28-51 58-51s50 17 58 51Z" fill="$accent"/>
  <circle cx="80" cy="76" r="45" fill="$primary"/>$hair$face
  <path d="M61 99c13 10 26 10 39 0" fill="none" stroke="$accent" stroke-width="6" stroke-linecap="round"/>$crown
</svg>''';
  }

  if (category == 1) {
    final visor = variant == 4
        ? '<path d="M21 77h118l-18 26H39Z" fill="$accent"/>'
        : '';
    final horns = variant == 5
        ? '<path d="m80 30 9-20 8 21M58 38 48 19" stroke="#facc15" stroke-width="7" stroke-linecap="round"/>'
        : '';
    return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="$background"/>
  <path d="M28 67 38 23l32 29M132 67l-10-44-32 29" fill="$primary" stroke="$accent" stroke-width="8" stroke-linejoin="round"/>
  <ellipse cx="80" cy="89" rx="55" ry="58" fill="$primary"/>$visor
  <ellipse cx="59" cy="81" rx="9" ry="11" fill="$accent"/><ellipse cx="101" cy="81" rx="9" ry="11" fill="$accent"/>
  <ellipse cx="80" cy="106" rx="17" ry="12" fill="$background"/><circle cx="80" cy="102" r="5" fill="$accent"/>
  <path d="M65 119c10 7 20 7 30 0" fill="none" stroke="$accent" stroke-width="5" stroke-linecap="round"/>$horns
</svg>''';
  }

  if (category == 2) {
    return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="$background"/><circle cx="24" cy="27" r="3" fill="$primary"/>
  <circle cx="133" cy="38" r="4" fill="$accent"/><circle cx="119" cy="17" r="2" fill="$primary"/>
  <circle cx="80" cy="80" r="58" fill="$primary"/><circle cx="80" cy="78" r="43" fill="$accent"/><circle cx="80" cy="82" r="31" fill="$background"/>
  <circle cx="67" cy="79" r="5" fill="$primary"/><circle cx="94" cy="79" r="5" fill="$primary"/>
  <path d="M66 98c10 7 20 7 29 0" fill="none" stroke="$primary" stroke-width="5" stroke-linecap="round"/>
  <path d="M31 140c29-20 68-20 98 0v20H31Z" fill="$accent"/><circle cx="${120 - variant * 2}" cy="119" r="6" fill="$primary"/>
</svg>''';
  }

  return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <rect width="160" height="160" fill="$background"/>
  <rect x="27" y="31" width="106" height="98" rx="${variant.isEven ? 8 : 0}" fill="$primary"/>
  <rect x="40" y="47" width="80" height="54" fill="$accent"/><rect x="52" y="63" width="14" height="14" fill="$background"/>
  <rect x="94" y="63" width="14" height="14" fill="$background"/><rect x="${58 + variant * 2}" y="86" width="${44 - variant * 2}" height="7" fill="$primary"/>
  <rect x="69" y="17" width="22" height="16" fill="$primary"/><rect x="76" y="7" width="8" height="12" fill="$accent"/>
  <rect x="42" y="112" width="19" height="8" fill="$background"/><rect x="70" y="112" width="19" height="8" fill="$background"/><rect x="98" y="112" width="19" height="8" fill="$background"/>
</svg>''';
}

/// Categories matching the web portal avatar picker.
class ForjaProfileAvatarCategory {
  const ForjaProfileAvatarCategory({required this.label, required this.keys});

  final String label;
  final List<String> keys;
}

const forjaProfileAvatarCategories = <ForjaProfileAvatarCategory>[
  ForjaProfileAvatarCategory(
    label: 'Characters',
    keys: [
      'forge',
      'flame',
      'mint',
      'captain',
      'rebel',
      'ninja',
      'royal',
      'racer',
      'elf',
      'orc',
      'fairy',
      'golem',
      'phoenix',
      'mermaid',
    ],
  ),
  ForjaProfileAvatarCategory(
    label: 'Creatures',
    keys: [
      'night',
      'panda',
      'fox',
      'owl',
      'shark',
      'dragon',
      'bunny',
      'yeti',
      'wolf',
      'bear',
      'penguin',
      'frog',
      'lion',
      'bee',
    ],
  ),
  ForjaProfileAvatarCategory(
    label: 'Space',
    keys: [
      'orbit',
      'comet',
      'nova',
      'alien',
      'rover',
      'lunar',
      'solar',
      'void',
    ],
  ),
  ForjaProfileAvatarCategory(
    label: 'Retro',
    keys: [
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
      'cyborg',
      'hacker',
      'drone',
      'matrix',
      'laser',
      'android',
    ],
  ),
];

List<String> get forjaProfileAvatarKeys => [
  for (final category in forjaProfileAvatarCategories) ...category.keys,
];

String normalizeForjaAvatarKey(String? raw) {
  final key = (raw ?? '').trim();
  if (key.isEmpty || !_avatarPalettes.containsKey(key)) return 'forge';
  return key;
}

/// The same SVG artwork and generated variants used by the web profile picker.
class ForjaProfileAvatar extends StatelessWidget {
  const ForjaProfileAvatar({
    super.key,
    required this.avatarKey,
    required this.name,
    this.size = 42,
    this.selected = false,
    this.showBorder = true,
    this.editing = false,
  });

  final String avatarKey;
  final String name;
  final double size;
  final bool selected;
  final bool showBorder;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$name avatar',
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(size * 0.04),
              border: showBorder
                  ? Border.all(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.12),
                      width: selected ? 2 : 1,
                    )
                  : null,
            ),
            child: SvgPicture.string(
              _avatarSvg(avatarKey),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          if (editing)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(size * 0.04),
              ),
              child: Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: size * 0.28,
              ),
            ),
        ],
      ),
    );
  }
}
