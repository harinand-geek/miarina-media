package org.miarina.media

import android.content.Context
import android.util.Log

/**
 * The Rust core (libmiarina_bridge.so) seen from Kotlin. Its HTTPS client
 * checks certificates with the Android trust store, which needs the JVM and
 * the app context first (android_tls.rs); without it the first request of
 * Obtenir would panic.
 */
object NativeBridge {
  @Volatile
  private var ready = false

  @JvmStatic
  private external fun initTls(context: Context)

  /** Once per process, before Flutter starts. */
  fun init(context: Context) {
    if (ready) return
    try {
      System.loadLibrary("miarina_bridge")
      initTls(context.applicationContext)
      ready = true
    } catch (e: Throwable) {
      Log.e("Miarina", "TLS verifier not initialized", e)
    }
  }
}
