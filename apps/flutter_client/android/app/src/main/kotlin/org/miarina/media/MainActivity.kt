package org.miarina.media

import android.os.Bundle
import android.os.SystemClock
import android.view.animation.PathInterpolator
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  private var engine: Media3EnginePlugin? = null
  private var deviceMedia: DeviceMediaChannel? = null
  private var mediaProbe: MediaProbeChannel? = null
  private var openWith: OpenWithChannel? = null
  private var mediaTools: MediaToolsChannel? = null
  private var downloads: DownloadNotificationsChannel? = null
  private var browser: BrowserChannel? = null

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
    // HTTPS of the Rust core (Obtenir) checks the Android trust store.
    NativeBridge.init(this)
    super.onCreate(savedInstanceState)
  }

  override fun onFlutterUiDisplayed() {
    super.onFlutterUiDisplayed()
    uiShown = true
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    engine = Media3EnginePlugin(this, flutterEngine.dartExecutor.binaryMessenger, flutterEngine.renderer)
    deviceMedia = DeviceMediaChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    mediaProbe = MediaProbeChannel(flutterEngine.dartExecutor.binaryMessenger)
    openWith = OpenWithChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    mediaTools = MediaToolsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    downloads = DownloadNotificationsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    browser = BrowserChannel(this, flutterEngine.dartExecutor.binaryMessenger, flutterEngine.platformViewsController.registry)
  }

  override fun onPause() {
    super.onPause()
    browser?.onPause()
  }

  override fun onResume() {
    super.onResume()
    browser?.onResume()
  }

  // "Open with" while the app runs (singleTop): the new file plays.
  override fun onNewIntent(intent: android.content.Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    openWith?.onNewIntent(intent)
  }

  @Deprecated("Activity result API not used: one request at a time")
  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
  ) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    deviceMedia?.onPermissionsResult(requestCode)
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    engine?.dispose()
    engine = null
    deviceMedia?.dispose()
    deviceMedia = null
    mediaProbe?.dispose()
    mediaProbe = null
    openWith?.dispose()
    openWith = null
    mediaTools?.dispose()
    mediaTools = null
    downloads?.dispose()
    downloads = null
    browser?.dispose()
    browser = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  companion object {
    private const val SPLASH_MAX_MS = 3000L
    private const val SPLASH_EXIT_MS = 300L
  }
}
