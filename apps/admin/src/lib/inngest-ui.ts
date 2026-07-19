/** Client-side Inngest dashboard URL (logs / runs). */
export const INNGEST_UI_URL = import.meta.env.DEV
  ? 'http://127.0.0.1:8288'
  : 'https://app.inngest.com'

export const isInngestLocalUi = import.meta.env.DEV
