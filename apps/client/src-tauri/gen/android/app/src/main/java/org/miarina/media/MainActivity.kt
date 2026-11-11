package org.miarina.media

import android.graphics.Color
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import androidx.activity.OnBackPressedCallback
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

class MainActivity : TauriActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    // Launch screen until the interface has rendered (AppShellPlugin.ready),
    // so the user never sees an empty dark window. Capped in case the page fails.
    val launched = SystemClock.uptimeMillis()
    installSplashScreen().setKeepOnScreenCondition {
      !AppShellPlugin.ready && SystemClock.uptimeMillis() - launched < SPLASH_MAX_MS
    }
    // Dark-first design: light status/navigation bar icons on the app background.
    enableEdgeToEdge(
      statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
      navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
    )
    // Back on the last screen: go to the background like Home instead of
    // finishing, which would end the process and stop the music and the
    // downloads (CDC AND-05). Registered before Tauri's own callback, which
    // falls back to this one when the page does not handle Back.
    onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
      override fun handleOnBackPressed() {
        moveTaskToBack(true)
      }
    })
    super.onCreate(savedInstanceState)
    // Android 15 draws the app behind the system bars: keep the web content
    // inside them (the WebView in use does not expose safe-area insets).
    val content = findViewById<View>(android.R.id.content)
    ViewCompat.setOnApplyWindowInsetsListener(content) { view, insets ->
      val bars = insets.getInsets(
        WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
      )
      // The keyboard is handled by the WebView (adjustResize).
      val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
      view.setPadding(bars.left, bars.top, bars.right, maxOf(bars.bottom, ime.bottom))
      WindowInsetsCompat.CONSUMED
    }
  }

  private companion object {
    const val SPLASH_MAX_MS = 3_000L
  }
}
