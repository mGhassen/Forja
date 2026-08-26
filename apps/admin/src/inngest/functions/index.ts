import {
  iptvCatalogScrape,
  iptvCatalogScrapeCancelled,
} from './iptv-catalog-scrape'
import { iptvPromoteBackfill } from './iptv-promote-backfill'
import { iptvStalkerNoteBackfill } from './iptv-stalker-note-backfill'
import { iptvShareCodesPurge } from './iptv-share-codes-purge'
import {
  r2DownloadsBackfill,
  r2DownloadsRollup,
} from './r2-downloads-rollup'

export const functions = [
  iptvCatalogScrape,
  iptvCatalogScrapeCancelled,
  iptvPromoteBackfill,
  iptvStalkerNoteBackfill,
  iptvShareCodesPurge,
  r2DownloadsRollup,
  r2DownloadsBackfill,
]
