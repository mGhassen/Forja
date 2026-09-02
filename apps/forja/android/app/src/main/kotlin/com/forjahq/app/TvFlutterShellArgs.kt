package com.forjahq.app

import io.flutter.embedding.engine.FlutterShellArgs

/**
 * Android TV Flutter engine flags.
 *
 * Skia (`--enable-impeller=false`) fixed MediaKit black video on early Impeller
 * but corrupts glyph/icon atlases on leanback GLES (garbage text/icons, crashes).
 * Impeller + OpenGLES keeps text sharp; MediaKit stays on `vo=mediacodec_embed`
 * so frames do not need Impeller EGL presentation.
 */
object TvFlutterShellArgs {
    const val IMPELLER_BACKEND_OPENGLES = "--impeller-backend=opengles"

    fun forLeanback(): Array<String> =
        arrayOf(
            FlutterShellArgs.ARG_ENABLE_IMPELLER,
            IMPELLER_BACKEND_OPENGLES,
        )
}
