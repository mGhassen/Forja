import { defineApiRoute } from '@/lib/api-route'
import { authedAdmin } from '@/server/admin-request'
import { processDeepRefRow } from '@/server/iptv-catalog/reddit'
import {
  createCatalogAdminClient,
  getDeepRefPortalsForPromote,
  getDeepRefRowById,
  insertScrapeDeepRefPortalsBulk,
  promoteDeepRefPortalRow,
} from '@/server/iptv-catalog/supabase-admin'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

export const Route = defineApiRoute('/api/iptv-deep-ref-reprocess', {
  POST: async ({ request }) => {
        try {
          const gate = await authedAdmin(request)
          if ('error' in gate && gate.error) return gate.error

          const body = (await request.json().catch(() => ({}))) as {
            deepRefId?: string
          }
          const deepRefId = String(body.deepRefId ?? '').trim()
          if (!deepRefId) return json({ error: 'deepRefId required' }, 400)

          const sb = createCatalogAdminClient()
          const row = await getDeepRefRowById(sb, deepRefId)
          if (!row) return json({ error: 'deep ref not found' }, 404)

          const pasteUrl = String(row.paste_url ?? '').trim()
          const b64 = String(row.base64 ?? '').trim()
          if (!pasteUrl && !b64) {
            return json(
              { error: 'deep ref has no paste URL or base64' },
              400,
            )
          }

          const processed = await processDeepRefRow(row, 500, { force: true })

          // Don't wipe junction rows when paste host is down — keep last good extract.
          if (processed.ref.fetchOk === false && pasteUrl) {
            const { error: failPatchErr } = await sb
              .from('iptv_scrape_deep_refs')
              .update({
                fetch_ok: false,
                needs_recheck: true,
              })
              .eq('id', deepRefId)
            if (failPatchErr) throw failPatchErr
            return json({
              ok: false,
              deepRefId,
              fetchOk: false,
              extractCount: row.extract_count,
              needsRecheck: true,
              hitCount: 0,
              promoted: 0,
              wasExisting: 0,
              skipped: 0,
              l2FetchOk: processed.l2FetchOk,
              l2FetchFail: processed.l2FetchFail,
              error: 'paste fetch failed — existing portals left unchanged',
            }, 502)
          }

          const { error: patchErr } = await sb
            .from('iptv_scrape_deep_refs')
            .update({
              fetch_ok: processed.ref.fetchOk,
              extract_count: processed.ref.extractCount,
              needs_recheck: processed.ref.needsRecheck,
              updated_at: new Date().toISOString(),
            })
            .eq('id', deepRefId)
          if (patchErr && /updated_at/i.test(patchErr.message)) {
            const { error: retryErr } = await sb
              .from('iptv_scrape_deep_refs')
              .update({
                fetch_ok: processed.ref.fetchOk,
                extract_count: processed.ref.extractCount,
                needs_recheck: processed.ref.needsRecheck,
              })
              .eq('id', deepRefId)
            if (retryErr) throw retryErr
          } else if (patchErr) {
            throw patchErr
          }

          const hitCount = await insertScrapeDeepRefPortalsBulk(
            sb,
            deepRefId,
            processed.ref.portals,
          )

          const { data: junctionIds, error: idsErr } = await sb
            .from('iptv_scrape_deep_ref_portals')
            .select('id')
            .eq('deep_ref_id', deepRefId)
          if (idsErr) throw idsErr

          const ids = (junctionIds ?? [])
            .map((r) => String(r.id ?? '').trim())
            .filter(Boolean)
          const promoteRows = await getDeepRefPortalsForPromote(sb, ids)

          let promoted = 0
          let wasExisting = 0
          let skipped = 0
          for (const hit of promoteRows) {
            const outcome = await promoteDeepRefPortalRow(sb, hit)
            if (!outcome.upserted) {
              skipped++
              continue
            }
            promoted++
            if (outcome.wasExisting) wasExisting++
          }

          return json({
            ok: true,
            deepRefId,
            fetchOk: processed.ref.fetchOk,
            extractCount: processed.ref.extractCount,
            needsRecheck: processed.ref.needsRecheck,
            hitCount,
            promoted,
            wasExisting,
            skipped,
            l2FetchOk: processed.l2FetchOk,
            l2FetchFail: processed.l2FetchFail,
          })
        } catch (e) {
          return json(
            { error: e instanceof Error ? e.message : String(e) },
            500,
          )
        }
      },
})
