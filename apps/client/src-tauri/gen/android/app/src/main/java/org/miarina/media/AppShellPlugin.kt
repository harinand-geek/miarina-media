package org.miarina.media

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
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
 *   and the task of a tapped "Download complete" notification are kept
 *   until the interface takes them with `takeShared`.
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

  /**
   * Text on the clipboard, for the Paste button: the WebView refuses
   * navigator.clipboard to apps. Called on a tap, while the app has focus
   * (Android 10+ only allows reading then).
   */
  @Command
  fun readClipboard(invoke: Invoke) {
    val clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val text = clipboard.primaryClip
      ?.takeIf { it.itemCount > 0 }
      ?.getItemAt(0)
      ?.coerceToText(activity)
      ?.toString()
      ?.take(MAX_SHARED_CHARS)
    val result = JSObject()
    text?.let { result.put("text", it) }
    invoke.resolve(result)
  }

  /** The last shared text (once), or nothing. */
  @Command
  fun takeShared(invoke: Invoke) {
    val result = JSObject()
    shared?.let { result.put("text", it) }
    playTask?.let { result.put("playTask", it) }
    shared = null
    playTask = null
    invoke.resolve(result)
  }

  private fun capture(intent: Intent?) {
    if (intent == null) return
    intent.getStringExtra(EXTRA_PLAY_TASK)?.let {
      playTask = it.take(64)
      intent.removeExtra(EXTRA_PLAY_TASK)
    }
    if (intent.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return
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

    @Volatile
    private var playTask: String? = null

    /** Set by the "Download complete" notification (DownloadsPlugin). */
    const val EXTRA_PLAY_TASK = "org.miarina.media.extra.PLAY_TASK"

    private const val MAX_SHARED_CHARS = 4096
  }
}
