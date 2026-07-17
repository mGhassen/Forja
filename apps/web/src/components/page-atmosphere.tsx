import { cn } from '@/lib/utils'

/**
 * Soft brand / flame blooms — each orb has a clearly different size + fade.
 */
function Bloom({
  className,
  color,
}: {
  className?: string
  color: 'brand' | 'flame'
}) {
  return (
    <div
      className={cn(
        'absolute aspect-square rounded-full',
        color === 'brand' ? 'bg-brand' : 'bg-flame',
        className,
      )}
    />
  )
}

export type AtmosphereRecipe = 'landing' | 'iptv' | 'auth' | 'download' | 'quiet'

export function PageAtmosphere({
  recipe,
  className,
}: {
  recipe: AtmosphereRecipe
  className?: string
}) {
  return (
    <div
      aria-hidden
      className={cn(
        'pointer-events-none absolute inset-0 z-0 overflow-hidden',
        className,
      )}
    >
      {recipe === 'landing' ? <LandingLight /> : null}
      {recipe === 'iptv' ? <IptvLight /> : null}
      {recipe === 'auth' ? <AuthLight /> : null}
      {recipe === 'download' ? <DownloadLight /> : null}
      {recipe === 'quiet' ? <QuietLight /> : null}
    </div>
  )
}

/** Home — sizes ~12–58vw, fades 0.10–0.34 (all unique). */
function LandingLight() {
  return (
    <>
      <Bloom
        color="brand"
        className="top-[-10%] right-[-8%] w-[min(58vw,36rem)] opacity-[0.34] blur-[130px]"
      />
      <Bloom
        color="brand"
        className="top-[16%] right-[10%] w-[min(14vw,9rem)] opacity-[0.14] blur-[55px]"
      />
      <Bloom
        color="flame"
        className="top-[28%] left-[-12%] w-[min(48vw,30rem)] opacity-[0.26] blur-[115px]"
      />
      <Bloom
        color="brand"
        className="top-[46%] left-[24%] w-[min(20vw,12rem)] opacity-[0.18] blur-[70px]"
      />
      <Bloom
        color="flame"
        className="top-[58%] right-[16%] w-[min(32vw,20rem)] opacity-[0.3] blur-[95px]"
      />
      <Bloom
        color="brand"
        className="top-[74%] left-[2%] w-[min(40vw,25rem)] opacity-[0.22] blur-[110px]"
      />
      <Bloom
        color="flame"
        className="top-[88%] right-[-6%] w-[min(24vw,15rem)] opacity-[0.12] blur-[80px]"
      />
    </>
  )
}

/** IPTV — sizes / fades all unique. */
function IptvLight() {
  return (
    <>
      <Bloom
        color="flame"
        className="top-[-12%] left-[10%] w-[min(62vw,38rem)] opacity-[0.32] blur-[140px]"
      />
      <Bloom
        color="brand"
        className="top-[18%] right-[-10%] w-[min(36vw,22rem)] opacity-[0.2] blur-[100px]"
      />
      <Bloom
        color="flame"
        className="top-[38%] left-[2%] w-[min(16vw,10rem)] opacity-[0.28] blur-[60px]"
      />
      <Bloom
        color="brand"
        className="top-[52%] left-[36%] w-[min(44vw,27rem)] opacity-[0.14] blur-[115px]"
      />
      <Bloom
        color="flame"
        className="top-[70%] right-[4%] w-[min(28vw,17rem)] opacity-[0.24] blur-[85px]"
      />
      <Bloom
        color="brand"
        className="top-[86%] left-[-8%] w-[min(50vw,30rem)] opacity-[0.18] blur-[125px]"
      />
    </>
  )
}

/** Auth */
function AuthLight() {
  return (
    <>
      <Bloom
        color="brand"
        className="top-[2%] left-[-14%] w-[min(55vw,34rem)] opacity-[0.3] blur-[135px]"
      />
      <Bloom
        color="brand"
        className="top-[38%] left-[4%] w-[min(18vw,11rem)] opacity-[0.16] blur-[65px]"
      />
      <Bloom
        color="flame"
        className="top-[66%] left-[12%] w-[min(34vw,21rem)] opacity-[0.22] blur-[100px]"
      />
    </>
  )
}

/** Download */
function DownloadLight() {
  return (
    <>
      <Bloom
        color="flame"
        className="top-[-4%] right-[-16%] w-[min(58vw,36rem)] opacity-[0.34] blur-[135px]"
      />
      <Bloom
        color="brand"
        className="top-[6%] left-[2%] w-[min(15vw,9.5rem)] opacity-[0.2] blur-[55px]"
      />
      <Bloom
        color="flame"
        className="top-[34%] right-[12%] w-[min(26vw,16rem)] opacity-[0.14] blur-[75px]"
      />
      <Bloom
        color="brand"
        className="top-[54%] left-[14%] w-[min(42vw,26rem)] opacity-[0.26] blur-[115px]"
      />
      <Bloom
        color="flame"
        className="top-[80%] right-[-2%] w-[min(30vw,18rem)] opacity-[0.18] blur-[90px]"
      />
    </>
  )
}

/** Quiet */
function QuietLight() {
  return (
    <>
      <Bloom
        color="brand"
        className="top-[10%] left-[16%] w-[min(38vw,23rem)] opacity-[0.2] blur-[110px]"
      />
      <Bloom
        color="flame"
        className="top-[52%] right-[6%] w-[min(22vw,14rem)] opacity-[0.14] blur-[80px]"
      />
    </>
  )
}
