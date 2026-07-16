import { Link } from '@tanstack/react-router'
import { LegalPage, LegalSection } from '@/components/legal-shell'

/**
 * Terms — aggregator / media-client framing inspired by public
 * FMHY-style “index, not host” and BingeBox-style “we don’t store content” notices.
 */
export function TermsPage() {
  return (
    <LegalPage
      eyebrow="Legal"
      title={
        <>
          Terms of
          <br />
          <span className="font-serif-i normal-case text-flame">use.</span>
        </>
      }
    >
      <p className="text-[rgba(237,230,218,0.72)]">
        Last updated: 16 July 2026. By downloading or using Forja (the app or this
        website), you agree to these terms.
      </p>

      <LegalSection title="What Forja is">
        <p>
          Forja is a media <strong className="font-semibold text-[#EDE6DA]">client and
          browser</strong>. It searches publicly available sources on the web, shows
          results (titles, links, streams, metadata), and lets you open them in a
          player. Think of it as a finder — not a library of files we own.
        </p>
        <p>
          Forja does <strong className="font-semibold text-[#EDE6DA]">not</strong> claim
          ownership of movies, series, live channels, or other media you may see. Those
          belong to their respective rights holders.
        </p>
      </LegalSection>

      <LegalSection title="What Forja does not do">
        <ul className="list-disc space-y-2 pl-5">
          <li>
            We do <strong className="font-semibold text-[#EDE6DA]">not</strong> host,
            upload, or store movie/TV/stream files on Forja servers.
          </li>
          <li>
            We do <strong className="font-semibold text-[#EDE6DA]">not</strong> keep a
            permanent copy of third-party media content for redistribution.
          </li>
          <li>
            We do <strong className="font-semibold text-[#EDE6DA]">not</strong> sell you
            copyrighted films or shows as our own product.
          </li>
        </ul>
        <p>
          Catalog posters, titles, and descriptions often come from third-party
          metadata providers (for example TMDB) or from the sources you choose to
          browse. Live TV / IPTV uses playlists and portals <em>you</em> add — Forja
          does not invent those channels.
        </p>
      </LegalSection>

      <LegalSection title="Your responsibility">
        <p>
          You are responsible for how you use Forja under the laws of your country.
          Respect copyright. Prefer legitimate sources when required. If a source or
          stream is unlawful where you live, do not use it.
        </p>
        <p>
          Forja is provided as a tool. Misuse of third-party sites or streams is your
          choice and your risk — not something Forja authorizes or controls.
        </p>
      </LegalSection>

      <LegalSection title="No warranty">
        <p>
          Forja and this website are provided “as is,” without warranties of any kind.
          Sources go offline. Links break. Results can be incomplete or wrong. We are
          not liable for damages from use, inability to use, or reliance on third-party
          content.
        </p>
      </LegalSection>

      <LegalSection title="Accounts & this website">
        <p>
          Optional cloud accounts (when available) are for settings sync and similar
          convenience features — not for storing media libraries of copyrighted works.
          Download pages only distribute the Forja application builds we publish.
        </p>
      </LegalSection>

      <LegalSection title="Copyright notices">
        <p>
          If you believe material surfaced through Forja infringes your rights, see our{' '}
          <Link to="/dmca" className="text-forja-green underline-offset-2 hover:underline">
            DMCA / copyright notice
          </Link>
          .
        </p>
      </LegalSection>

      <LegalSection title="Changes">
        <p>
          We may update these terms. Continued use after a change means you accept the
          updated version. The date at the top is the latest revision.
        </p>
      </LegalSection>
    </LegalPage>
  )
}
