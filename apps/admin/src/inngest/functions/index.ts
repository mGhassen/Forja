import {
  iptvCatalogScrape,
  iptvCatalogScrapeCancelled,
} from './iptv-catalog-scrape'
import { iptvPromoteBackfill } from './iptv-promote-backfill'
import { iptvShareCodesPurge } from './iptv-share-codes-purge'
import {
  r2DownloadsBackfill,
  r2DownloadsRollup,
} from './r2-downloads-rollup'

export const functions = [
  iptvCatalogScrape,
  iptvCatalogScrapeCancelled,
  iptvPromoteBackfill,
  iptvShareCodesPurge,
  r2DownloadsRollup,
  r2DownloadsBackfill,
]
