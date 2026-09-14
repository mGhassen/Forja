package com.forjahq.app

import io.flutter.embedding.engine.FlutterShellArgs

/**
 * Android TV Flutter engine flags — match ipdigi: Impeller off (Skia).
 *
 * MediaKit uses `vo=mediacodec_embed` + SurfaceTexture producers
 * ([ForjaApplication]). Glyph atlas risk on leanback Skia accepted for
 * RFC-113 parity with ipdigi.
 */
object TvFlutterShellArgs {
    fun forLeanback(): Array<String> =
        arrayOf(FlutterShellArgs.ARG_DISABLE_IMPELLER)
}
