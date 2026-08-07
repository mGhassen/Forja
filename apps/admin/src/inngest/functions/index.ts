import {
  iptvCatalogScrape,
  iptvCatalogScrapeCancelled,
} from './iptv-catalog-scrape'
import { iptvPromoteBackfill } from './iptv-promote-backfill'

export const functions = [
  iptvCatalogScrape,
  iptvCatalogScrapeCancelled,
  iptvPromoteBackfill,
]
