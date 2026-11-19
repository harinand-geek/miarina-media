package org.miarina.media

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  private var engine: Media3EnginePlugin? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    engine = Media3EnginePlugin(this, flutterEngine.dartExecutor.binaryMessenger, flutterEngine.renderer)
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    engine?.dispose()
    engine = null
    super.cleanUpFlutterEngine(flutterEngine)
  }
}
