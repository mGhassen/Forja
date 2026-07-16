import { Link } from '@tanstack/react-router'
import { LegalPage, LegalSection } from '@/components/legal-shell'

/**
 * DMCA / copyright notice — same “we don’t host files” posture as common
 * media-client / directory disclaimers (e.g. BingeBox-style: no storage on our
 * servers; third-party APIs/sources we don’t control).
 */
export function DmcaPage() {
  return (
    <LegalPage
      eyebrow="Legal"
      title={
        <>
          DMCA &amp;
          <br />
          <span className="font-serif-i normal-case text-flame">copyright.</span>
        </>
      }
    >
      <p className="text-[rgba(237,230,218,0.72)]">
        Forja respects intellectual property. This page explains what we are, what we
        are not, and how rights holders can reach us.
      </p>

      <LegalSection title="Clear statement">
        <p>
          Forja is <strong className="font-semibold text-[#EDE6DA]">not a pirate host</strong>.
          We do not operate a file locker for movies or TV. We do not upload copyrighted
          video files to Forja servers. We do not sell stolen copies of films.
        </p>
        <p>
          Forja is an application that <strong className="font-semibold text-[#EDE6DA]">scrapes
          and indexes publicly reachable sources</strong> on the web and shows you
          results so you can choose what to open. We are not the owner of those streams
          or of the studios’ catalogs.
        </p>
        <p>
          In short: <strong className="font-semibold text-[#EDE6DA]">we don’t save your
          movies for you on our servers</strong> — we help you find and play what is
          already published elsewhere. Ownership stays with the rights holders.
        </p>
      </LegalSection>

      <LegalSection title="What we control vs what we don’t">
        <ul className="list-disc space-y-2 pl-5">
          <li>
            <strong className="font-semibold text-[#EDE6DA]">We control:</strong> the Forja
            app UI, this marketing/download site, and our own published app builds.
          </li>
          <li>
            <strong className="font-semibold text-[#EDE6DA]">We do not control:</strong>{' '}
            third-party websites, scrapers’ upstream hosts, IPTV portals you paste in,
            or torrent/peer networks you may open.
          </li>
          <li>
            Metadata (posters, titles, overviews) may come from providers such as TMDB
            or from the sources themselves — not from a Forja-owned media archive.
          </li>
        </ul>
      </LegalSection>

      <LegalSection title="User responsibility">
        <p>
          You must follow the law where you live. Supporting creators and using licensed
          services when required is encouraged. Forja does not grant you a license to
          copyrighted works owned by others.
        </p>
      </LegalSection>

      <LegalSection title="DMCA-style notice">
        <p>
          If you are a copyright owner (or authorized agent) and believe Forja’s own
          materials (for example branding on this site or content we publish ourselves)
          infringe your rights, send a notice that includes:
        </p>
        <ul className="list-disc space-y-2 pl-5">
          <li>Your contact name, address, phone, and email</li>
          <li>A description of the work you claim is infringed</li>
          <li>The exact URL or in-app location of the material</li>
          <li>A statement that you have a good-faith belief the use is not authorized</li>
          <li>
            A statement under penalty of perjury that the information is accurate and
            that you are authorized to act
          </li>
          <li>Your physical or electronic signature</li>
        </ul>
        <p>
          Open a GitHub issue on the Forja project with the title{' '}
          <strong className="font-semibold text-[#EDE6DA]">DMCA</strong> and include the
          details above:{' '}
          <a
            href="https://github.com/forja/forja/issues"
            className="text-forja-green underline-offset-2 hover:underline"
            target="_blank"
            rel="noreferrer"
          >
            github.com/forja/forja/issues
          </a>
          .
        </p>
        <p>
          Notices about content that lives only on third-party sites must be sent to
          those sites’ operators. We cannot remove files we do not host.
        </p>
      </LegalSection>

      <LegalSection title="Related">
        <p>
          See also our{' '}
          <Link to="/terms" className="text-forja-green underline-offset-2 hover:underline">
            Terms of use
          </Link>
          .
        </p>
      </LegalSection>
    </LegalPage>
  )
}
