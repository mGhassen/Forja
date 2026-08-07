import { inngest } from '@/inngest/client'
import {
  rollupDaysFromCf,
  rollupYesterday,
  utcDayString,
} from '@/server/r2-download-stats'

/**
 * Daily 01:15 UTC: CF GraphQL GetObject for yesterday → R2 stats/downloads.json.
 * Manual: event `r2/downloads.rollup` (same — yesterday only).
 */
export const r2DownloadsRollup = inngest.createFunction(
  {
    id: 'r2-downloads-rollup',
    concurrency: { limit: 1 },
    retries: 2,
    checkpointing: false,
    triggers: [{ cron: '15 1 * * *' }, { event: 'r2/downloads.rollup' }],
  },
  async ({ step }) => {
    return step.run('rollup-yesterday', async () => rollupYesterday())
  },
)

/** Backfill last N days from CF (max 31) into the same JSON file. */
export const r2DownloadsBackfill = inngest.createFunction(
  {
    id: 'r2-downloads-backfill',
    concurrency: { limit: 1 },
    retries: 1,
    checkpointing: false,
    triggers: [{ event: 'r2/downloads.backfill' }],
  },
  async ({ event, step }) => {
    const days = Math.min(
      31,
      Math.max(1, Number((event.data as { days?: number })?.days ?? 30)),
    )
    const to = new Date()
    to.setUTCDate(to.getUTCDate() - 1)
    const from = new Date(to)
    from.setUTCDate(from.getUTCDate() - (days - 1))

    return step.run('backfill', async () =>
      rollupDaysFromCf({
        fromDay: utcDayString(from),
        toDay: utcDayString(to),
      }),
    )
  },
)
