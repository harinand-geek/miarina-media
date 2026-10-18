package org.miarina.media

import android.app.Activity
import android.content.Intent
import android.webkit.WebView
import app.tauri.annotation.Command
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin

/**
 * App shell signals between Android and the interface:
 * - `ready` ends the launch screen;
 * - text shared to the app ("Share → Miarina Media" from YouTube, Chrome…)
 *   is kept until the interface takes it with `takeShared`.
 */
@TauriPlugin
class AppShellPlugin(private val activity: Activity) : Plugin(activity) {
  override fun load(webView: WebView) {
    capture(activity.intent)
  }

  override fun onNewIntent(intent: Intent) {
    capture(intent)
  }

  @Command
  fun ready(invoke: Invoke) {
    Companion.ready = true
    invoke.resolve()
  }

  /** The last shared text (once), or nothing. */
  @Command
  fun takeShared(invoke: Invoke) {
    val result = JSObject()
    shared?.let { result.put("text", it) }
    shared = null
    invoke.resolve(result)
  }

  private fun capture(intent: Intent?) {
    if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return
    // Untrusted text from another app: bounded here, parsed and validated in Rust.
    shared = intent.getStringExtra(Intent.EXTRA_TEXT)?.take(MAX_SHARED_CHARS)
    // Handled once: a configuration change must not share it again.
    intent.action = null
  }

  companion object {
    /** Read by MainActivity's splash screen condition (main thread). */
    @Volatile
    var ready = false

    @Volatile
    private var shared: String? = null

    private const val MAX_SHARED_CHARS = 4096
  }
}
