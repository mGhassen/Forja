export const meta = {
  name: 'forja-law-review',
  description: 'Review the working-tree diff against Forja laws: one finder per law dimension, adversarial verification, confirmed findings only',
  whenToUse: 'Thorough review before reporting work done or opening a PR (/forja-review --thorough). args: { base: "<git ref>" } (default HEAD)',
  phases: [
    { title: 'Find', detail: 'one finder per law dimension over the diff' },
    { title: 'Verify', detail: 'a skeptic re-reads the code and tries to refute each finding' },
  ],
}

const base = (args && args.base) || 'HEAD'

const DIMENSIONS = [
  {
    key: 'pack-host',
    rules: '.cursor/rules/forja-pack-product-host.mdc and .cursor/rules/forja-playback-host-generic.mdc (skill .cursor/skills/forja-pack-product-host/SKILL.md for detail)',
    focus: 'product tab ids, hub inventory, pack-id branches, title/poster/homeTeam field mappers or product verbs inside apps/forja; open.surface or EngineCategories branches inside apps/forja/lib/shared/playback; orchestrators, hooks, registries, or Riverpod inside packages/forja_foundation',
  },
  {
    key: 'design',
    rules: '.cursor/rules/forja-design-system.mdc, .cursor/rules/forja-foundation-no-hardcode.mdc, .cursor/rules/forja-shared-ui.mdc',
    focus: 'magic numbers for reused density, clamps, radii that belong in packages/forja_foundation/lib/tokens; raw Colors.white54/70/38 where a ForjaShellColors token exists; BackdropFilter or ImageFilter.blur outside ForjaFrostedPanel (and never over live video); raw Switch/SwitchListTile color overrides; duplicated hero or cast UI; imports of the forja_foundation.dart gallery barrel; imports added to part-of files',
  },
  {
    key: 'tv',
    rules: '.cursor/rules/forja-tv-scope.mdc',
    focus: 'raw TextField/TextFormField reachable on leanback without TvBrowseTextField/SettingsTextField or browseTextUntilActivate gating; onFocusChange wired to open/edit/submit; autofocus: true on editable fields; ShellTokens.isTvLayout or isAndroidTvDevice in widgets instead of ShellScope; a D-pad fix applied to one in-scope tab but not the same pattern elsewhere',
  },
  {
    key: 'engine',
    rules: 'docs/ENGINE_BOUNDARY.md, .cursor/rules/rust-migration.mdc, .cursor/rules/rust-engine-versioning.mdc',
    focus: 'new non-platform engine logic written in Dart; RustLib.instance.* in apps/forja/lib outside docs/issues/sync-ffi-allowlist.txt; new Pattern A *_html_json FFI; a per-crate version = field; only one of crates/Cargo.toml and packages/rust/pubspec.yaml bumped',
  },
  {
    key: 'live',
    rules: '.cursor/rules/no-embed-playback.mdc, .cursor/rules/live-catalog-schedule-only.mdc',
    focus: 'webviewOnly or embedUrl-only rows treated as streams; embed WebView fallback for Forja Live / live sports; streams[], iframe, or embedUrl on catalog schedule rows; pending Providers rows invented when discover is empty',
  },
  {
    key: 'honesty',
    rules: '.cursor/rules/honesty-and-completion.mdc, .cursor/rules/no-hide-as-fix.mdc',
    focus: 'a user-facing option, engine, tab, or menu entry hidden, removed, disabled, or force-defaulted as the fix; a symptom-only change where the surrounding code or comments claim a root fix; TODO or placeholder code left where behavior was claimed complete',
  },
  {
    key: 'docs',
    rules: '.cursor/rules/docs-rfc-issues.mdc, .cursor/rules/changelog.mdc, .cursor/rules/user-facing-copy-truth.mdc',
    focus: 'user-visible code change with no bullet added to docs/changelog/*-[draft].md; bullet prefix other than **Add:** **Change:** **Fix:** **Remove:**; bullet with file paths, issue IDs, or crate names; issue/RFC filename tag different from **Status:** in body; folder README row not updated after a rename; anything under docs/backlog changed; product strings or feature docs with formerly / no longer / only / host-owned / kit protocol wording',
  },
  {
    key: 'tests',
    rules: '.cursor/rules/forja-host-tests-no-pack-contracts.mdc',
    focus: 'tests under apps/forja/test asserting shipped plugin ids (kisskh, videasy, hianime…), hub slot ids as contracts, or real pack type tokens; loadAllForjaHqPlugins or the pack tree used as an oracle',
  },
  {
    key: 'correctness',
    rules: 'none — ordinary correctness review',
    focus: 'missing await on futures whose result matters, cancel tokens not checked after async gaps, null or empty-list handling, wrong platform gates, listeners or controllers not disposed, broken part-of imports, off-by-one in paging or indices, FFI calls on the UI thread that can block',
  },
]

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string', description: 'repo-relative path' },
          line: { type: 'integer' },
          rule: { type: 'string', description: 'rule file name or "correctness"' },
          severity: { type: 'string', enum: ['block', 'fix', 'nit'] },
          summary: { type: 'string', description: 'one sentence: the defect' },
          evidence: { type: 'string', description: 'the code you read that proves it, quoted briefly' },
          failure_scenario: { type: 'string', description: 'input/state → wrong result' },
        },
        required: ['file', 'rule', 'severity', 'summary', 'evidence'],
      },
    },
  },
  required: ['findings'],
}

const VERDICT = {
  type: 'object',
  properties: {
    real: { type: 'boolean' },
    reason: { type: 'string' },
    corrected_severity: { type: 'string', enum: ['block', 'fix', 'nit'] },
  },
  required: ['real', 'reason'],
}

log(`Reviewing working tree against ${base} across ${DIMENSIONS.length} law dimensions`)

const results = await pipeline(
  DIMENSIONS,
  d => agent(
    `You review the Forja repository working tree against ONE law dimension: "${d.key}".\n` +
    `Read these rule files first: ${d.rules}.\n` +
    `Look for: ${d.focus}.\n\n` +
    `Steps: run \`git diff ${base} --stat\`, then \`git diff ${base}\`, then \`git ls-files --others --exclude-standard\` and read new files fully. ` +
    `Only lines that are new or changed versus ${base} count; pre-existing code is out of scope unless the change depends on it. ` +
    `Open every file you cite and read enough context to be certain. Report only findings you verified in code — no speculation, no generic advice, no style nits unless the rule names them. ` +
    `Severity: block = law broken, user option hidden, crash or data loss; fix = should land before the work is called done; nit = minor. ` +
    `An empty findings list is a valid answer.`,
    { label: `find:${d.key}`, phase: 'Find', schema: FINDINGS },
  ),
  (r, d) => parallel(((r && r.findings) || []).map(f => () =>
    agent(
      `You are a skeptic. Try to REFUTE this code-review finding about the Forja working tree (diff versus ${base}).\n` +
      `file: ${f.file}:${f.line || '?'} · rule: ${f.rule} · severity: ${f.severity}\n` +
      `claim: ${f.summary}\n` +
      `evidence given: ${f.evidence}\n\n` +
      `Open the file, read the surrounding code, and read the rule it cites. Refute (real=false) if the code does not do what is claimed, the rule does not forbid it, the line is pre-existing and unchanged in this diff, or an allowlist/exception covers it (for example docs/issues/sync-ffi-allowlist.txt, ForjaFrostedPanel, the shell tokens file). ` +
      `If you are uncertain, refute. If it stands, you may correct the severity. Return real, reason, corrected_severity.`,
      { label: `verify:${d.key}`, phase: 'Verify', schema: VERDICT },
    ).then(v => Object.assign({}, f, { dimension: d.key, verdict: v })),
  )),
)

const all = results.filter(Boolean).flat().filter(Boolean)
const confirmed = all.filter(f => f.verdict && f.verdict.real)
const dropped = all.filter(f => !(f.verdict && f.verdict.real))
const order = { block: 0, fix: 1, nit: 2 }
for (const f of confirmed) {
  if (f.verdict.corrected_severity) f.severity = f.verdict.corrected_severity
}
confirmed.sort((a, b) => (order[a.severity] === undefined ? 3 : order[a.severity]) - (order[b.severity] === undefined ? 3 : order[b.severity]))

log(`${confirmed.length} confirmed finding(s); ${dropped.length} dropped by verification`)

return {
  base,
  confirmed: confirmed.map(f => ({
    severity: f.severity,
    file: f.file,
    line: f.line,
    rule: f.rule,
    dimension: f.dimension,
    summary: f.summary,
    failure_scenario: f.failure_scenario,
    evidence: f.evidence,
  })),
  dropped: dropped.map(f => ({ file: f.file, summary: f.summary, why: f.verdict ? f.verdict.reason : 'verifier unavailable' })),
}
