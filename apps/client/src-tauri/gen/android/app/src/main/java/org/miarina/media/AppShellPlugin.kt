package org.miarina.media

import android.app.Activity
import app.tauri.annotation.Command
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.Plugin

/** App shell signals from the interface: `ready` ends the launch screen. */
@TauriPlugin
class AppShellPlugin(activity: Activity) : Plugin(activity) {
  @Command
  fun ready(invoke: Invoke) {
    Companion.ready = true
    invoke.resolve()
  }

  companion object {
    /** Read by MainActivity's splash screen condition (main thread). */
    @Volatile
    var ready = false
  }
}
