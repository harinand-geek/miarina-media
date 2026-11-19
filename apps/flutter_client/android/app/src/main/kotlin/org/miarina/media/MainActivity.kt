package org.miarina.media

import android.os.Bundle
import android.os.SystemClock
import android.view.animation.PathInterpolator
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  private var engine: Media3EnginePlugin? = null

  @Volatile
  private var uiShown = false

  override fun onCreate(savedInstanceState: Bundle?) {
    // System splash (design_handoff_splash) until Flutter has drawn its first
    // frame, at most SPLASH_MAX_MS; then a 300 ms fade over the interface
    // already rendered underneath. With system animations off, it just goes.
    val launched = SystemClock.uptimeMillis()
    val splash = installSplashScreen()
    splash.setKeepOnScreenCondition {
      !uiShown && SystemClock.uptimeMillis() - launched < SPLASH_MAX_MS
    }
    splash.setOnExitAnimationListener { provider ->
      // Settings value rather than areAnimatorsEnabled(): minSdk is below 26.
      val animated = android.provider.Settings.Global.getFloat(
        contentResolver,
        android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,
        1f,
      ) > 0f
      if (!animated) {
        provider.remove()
        return@setOnExitAnimationListener
      }
      provider.view.animate()
        .alpha(0f)
        .setDuration(SPLASH_EXIT_MS)
        .setInterpolator(PathInterpolator(0.3f, 0f, 1f, 1f))
        .withEndAction { provider.remove() }
        .start()
    }
    super.onCreate(savedInstanceState)
  }

  override fun onFlutterUiDisplayed() {
    super.onFlutterUiDisplayed()
    uiShown = true
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    engine = Media3EnginePlugin(this, flutterEngine.dartExecutor.binaryMessenger, flutterEngine.renderer)
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    engine?.dispose()
    engine = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  companion object {
    private const val SPLASH_MAX_MS = 3000L
    private const val SPLASH_EXIT_MS = 300L
  }
}
