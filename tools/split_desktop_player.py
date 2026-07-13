#!/usr/bin/env python3
"""Split desktop_player_screen.dart into part/mixin files (RFC-019)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main_path = ROOT / 'apps/forja/lib/shared/player/player/desktop_player_screen.dart'
lines = main_path.read_text().splitlines(keepends=True)

IGNORE = {
    'return', 'break', 'continue', 'if', 'else', 'for', 'while', 'switch',
    'case', 'default', 'try', 'catch', 'finally', 'throw', 'async', 'await',
    'true', 'false', 'null', 'this', 'super', 'const', 'final', 'var', 'new',
    'in', 'is', 'as', 'required', 'yield', 'part', 'import', 'export', 'void',
    'setState', 'mounted', 'context', 'widget', 'unawaited', 'debugPrint',
}

METHOD_START = re.compile(
    r'^\s+(?:@\w+\s+)*(?:Future<[^>]+>|void|bool\??|String\??|int|Widget|List<[^>]+>|Set<[^>]+>|Map<[^>]+>|Duration\??|double|Color|BoxFit|IntroDbResponse\??|ProviderScoreScope\??|PlaybackRecovery\??|Player|VideoController|Uint8List\??)\s+(_?\w+)\s*[\({]'
)


def collect_fields(src, start, end_marker):
    fields = set()
    for line in src[start - 1 :]:
        if end_marker in line:
            break
        gm = re.search(r'\bget\s+(\w+)', line)
        if gm and ' get ' in line:
            fields.add(gm.group(1))
        fm = re.match(r'^\s+([\w<>,\s\?\.]+?)\s+(_?\w+)\s*=', line)
        if fm and ' get ' not in line and '(' not in fm.group(1):
            fields.add(fm.group(2))
        fm2 = re.match(r'^\s+([\w<>,\s\?\.]+?)\s+(_?\w+)\s*;', line)
        if fm2 and ' get ' not in line and '(' not in fm2.group(1):
            fields.add(fm2.group(2))
    return fields


def collect_methods(src, start, end_line):
    methods = set()
    for line in src[start - 1 : end_line]:
        mm = METHOD_START.match(line)
        if mm:
            methods.add(mm.group(1))
    return methods


fields = collect_fields(lines, 490, '  //  LIFECYCLE')
methods = collect_methods(lines, 625, 5466)


def transform_body(body_lines, self_methods):
    out = []
    in_sig = False
    params = set()
    locals_ = set()

    def reset_scope():
        nonlocal params, locals_
        params = set()
        locals_ = set()

    def transform_segment(segment):
        skip = params | locals_

        def repl(m):
            ident = m.group(1)
            if ident in skip or ident in IGNORE or len(ident) <= 1:
                return ident
            if ident in self_methods:
                return ident
            if ident not in fields and ident not in methods:
                return ident
            start = m.start(1)
            if start > 0 and segment[start - 1] in '.':
                return ident
            end = m.end(1)
            if end < len(segment) and segment[end] == ':':
                return ident
            return f'_s.{ident}'

        return re.sub(r'\b([_a-zA-Z]\w*)\b', repl, segment)

    def transform_line(line):
        parts = re.split(r"('(?:\\'|[^'])*'|\"(?:\\\"|[^\"])*\")", line)
        return ''.join(
            parts[i] if i % 2 == 1 else transform_segment(parts[i])
            for i in range(len(parts))
        )

    for line in body_lines:
        if METHOD_START.match(line) or (
            re.match(r'^\s+Future<', line)
            and not re.search(r'\)\s*(?:async\s*)?[{=>]', line)
        ):
            reset_scope()
            in_sig = True
        if in_sig:
            for pm in re.finditer(
                r'(?:required\s+)?[\w<>,\s\?\.]+\s+(\w+)(?:\s*[,})]|\s*=\s*)', line
            ):
                params.add(pm.group(1))
            for pm in re.finditer(r'\{([^}]+)\}', line):
                for nm in re.finditer(r'(?:required\s+)?[\w\?]+\s+(\w+)', pm.group(1)):
                    params.add(nm.group(1))
            out.append(line)
            if re.search(r'\)\s*(?:async\s*)?[{=>]', line):
                in_sig = False
            continue
        if '=>' in line and re.match(
            r'^\s+(?:bool\??|String\??|void|int|Future<[^>]+>|List<[^>]+>|Widget|Duration\??|double|Color|BoxFit)',
            line,
        ):
            out.append(line)
            continue
        if re.match(r'^\s{2}(?:bool|int|String|List|Set|Map|final|late|var)\s+', line):
            out.append(line)
            continue
        if re.match(r'^\s+const\s+', line) or re.match(r'^\s{4,}[\w<>,\s\?\.]+\s+\w+\s*;\s*$', line):
            out.append(line)
            continue
        lm = re.match(r'^\s+(?:final|var)\s+(\w+)\s*=', line)
        if lm:
            locals_.add(lm.group(1))
            prefix, _, rhs = line.partition('=')
            out.append(prefix + '=' + transform_line(rhs))
            continue
        if line.strip().startswith('//') or re.match(r'^\s+@override', line):
            out.append(line)
            continue
        out.append(transform_line(line))
    return out


def extract(ranges):
    out = []
    for s, e in ranges:
        out.extend(lines[s - 1 : e])
    return out


def mixin_methods_in_range(ranges):
    names = set()
    for line in extract(ranges):
        mm = METHOD_START.match(line)
        if mm:
            names.add(mm.group(1))
    return names


slices = [
    ('desktop_player_glass.dart', None, [(62, 409)]),
    ('desktop_player_lifecycle.dart', '_DesktopPlayerLifecycle', [(625, 992), (1065, 1206)]),
    ('desktop_player_playback.dart', '_DesktopPlayerPlayback', [(1212, 2127)]),
    ('desktop_player_tracks.dart', '_DesktopPlayerTracks', [(2133, 2758)]),
    ('desktop_player_sources.dart', '_DesktopPlayerSources', [(2763, 3552)]),
    ('desktop_player_episodes.dart', '_DesktopPlayerEpisodes', [(3558, 4677)]),
    ('desktop_player_ui.dart', '_DesktopPlayerUi', [(4683, 4837)]),
    ('desktop_player_build.dart', '_DesktopPlayerBuild', [(4844, 5466)]),
    ('desktop_player_seekbar.dart', None, [(5469, len(lines))]),
]

base = main_path.parent
part_names = []
mixin_names = []
for fname, mname, ranges in slices:
    part_names.append(fname)
    if mname is None:
        (base / fname).write_text(
            "part of 'desktop_player_screen.dart';\n\n" + ''.join(extract(ranges))
        )
    else:
        mixin_names.append(mname)
        self_m = mixin_methods_in_range(ranges)
        body = transform_body(extract(ranges), self_m)
        (base / fname).write_text(
            "part of 'desktop_player_screen.dart';\n\n"
            f'mixin {mname} on State<DesktopPlayerScreen>, '
            'WidgetsBindingObserver, WindowListener {\n'
            '  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;\n\n'
            + ''.join(body)
            + '}\n'
        )

imports = lines[0:61]
parts = [f"part '{f}';\n" for f in part_names] + ['\n']
widget_block = lines[405:486]
class_open = (
    'class _DesktopPlayerScreenState extends State<DesktopPlayerScreen>\n'
    '    with WindowListener, WidgetsBindingObserver,\n'
    '        '
    + ',\n        '.join(mixin_names)
    + ' {\n'
)
field_block = lines[489:620]
dispose = lines[992:1063]

main_path.write_text(
    ''.join(imports + parts + widget_block + [class_open] + field_block + dispose + ['}\n'])
)
print(f'fields={len(fields)} methods={len(methods)}')
