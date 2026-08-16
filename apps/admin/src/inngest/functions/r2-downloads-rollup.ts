import { inngest } from '@/inngest/client'
import {
  rollupDaysFromCf,
  rollupYesterday,
  utcDayString,
} from '@/server/r2-download-stats'

/**
 * 10:00 UTC + noon catch-up: CF GraphQL GetObject for yesterday → R2.
 * 01:15 was too early — CF analytics often incomplete. Manual: `r2/downloads.rollup`.
 */
export const r2DownloadsRollup = inngest.createFunction(
  {
    id: 'r2-downloads-rollup',
    concurrency: { limit: 1 },
    retries: 2,
    checkpointing: false,
    triggers: [
      { cron: '0 10 * * *' },
      { cron: '0 12 * * *' },
      { event: 'r2/downloads.rollup' },
    ],
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
