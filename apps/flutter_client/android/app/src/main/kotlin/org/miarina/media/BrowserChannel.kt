package org.miarina.media

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.platform.PlatformViewRegistry
import org.json.JSONArray

/**
 * Built-in browser on Android (decision 0001, design_handoff_android_v2
 * screen 02), ported from BrowserPlugin of the Tauri app: one native
 * WebView per tab, shown inside the Flutter screen through the platform
 * view "org.miarina.media/browser_page" (so Flutter draws the floating
 * download button and its sheets over the page).
 *
 * The tab rules live in the Rust core: it sends orders (load, close, show,
 * back, forward, reload, stop, scan) through Dart on
 * "org.miarina.media/browser", and this class reports what the pages do
 * ("report": started, finished, moved, title, found), checked and bounded
 * by the core.
 *
 * The visited page is untrusted: no JavaScript interface, no file or
 * content access, http(s) only, no popups, no native downloads (a file it
 * offers is reported and analyzed by the app's engine).
 */
class BrowserChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
  registry: PlatformViewRegistry,
) : MethodChannel.MethodCallHandler {
  private val channel = MethodChannel(messenger, "org.miarina.media/browser")
  private val main = Handler(Looper.getMainLooper())
  private val pages = HashMap<Int, WebView>()

  /** The page area of the browser screen, while the screen is shown. */
  private var host: FrameLayout? = null

  /** The tab whose page is shown (0: none). */
  private var shown = 0
  private var fullscreen: View? = null
  private var fullscreenCallback: WebChromeClient.CustomViewCallback? = null

  init {
    channel.setMethodCallHandler(this)
    registry.registerViewFactory(VIEW_TYPE, Factory())
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    exitFullscreen()
    pages.values.forEach {
      (it.parent as? ViewGroup)?.removeView(it)
      it.destroy()
    }
    pages.clear()
    host = null
  }

  fun onPause() {
    pages.values.forEach { it.onPause() }
  }

  fun onResume() {
    pages[shown]?.takeIf { host != null }?.onResume()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "command") {
      result.notImplemented()
      return
    }
    val tab = call.argument<Int>("tab") ?: 0
    val url = call.argument<String>("url") ?: ""
    when (call.argument<String>("action")) {
      "load" -> if (tab > 0 && isWeb(url)) page(tab).loadUrl(url)
      "close" -> close(tab)
      "show" -> show(tab)
      "back" -> when {
        fullscreen != null -> exitFullscreen()
        pages[tab]?.canGoBack() == true -> pages[tab]?.goBack()
      }
      "forward" -> pages[tab]?.takeIf { it.canGoForward() }?.goForward()
      "reload" -> pages[tab]?.reload()
      "stop" -> pages[tab]?.stopLoading()
      "scan" -> scan(tab)
      else -> {
        result.error("args", "unknown browser order", null)
        return
      }
    }
    result.success(null)
  }

  private fun report(tab: Int, type: String, fill: (HashMap<String, Any?>) -> Unit) {
    val args = HashMap<String, Any?>()
    args["tab"] = tab
    args["type"] = type
    fill(args)
    channel.invokeMethod("report", args)
  }

  /** Shows the page of `tab` in the screen's page area (0: none). */
  private fun show(tab: Int) {
    val previous = shown
    shown = tab
    if (previous != tab) {
      pages[previous]?.let {
        // A hidden page must not keep playing out loud.
        it.evaluateJavascript(PAUSE_MEDIA, null)
        it.onPause()
      }
    }
    attach()
  }

  /** Puts the shown page, and only it, in the page area. */
  private fun attach() {
    val area = host
    val page = pages[shown]
    for ((id, view) in pages) {
      if (id != shown || area == null) {
        if (view.parent != null) (view.parent as ViewGroup).removeView(view)
      }
    }
    if (area == null || page == null) return
    if (page.parent !== area) {
      (page.parent as? ViewGroup)?.removeView(page)
      area.addView(
        page,
        FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
      )
    }
    page.onResume()
  }

  private fun close(tab: Int) {
    val page = pages.remove(tab) ?: return
    (page.parent as? ViewGroup)?.removeView(page)
    page.destroy()
    if (shown == tab) shown = 0
  }

  private fun scan(tab: Int) {
    val page = pages[tab] ?: return
    page.evaluateJavascript(SCAN_MEDIA) { json ->
      val list = try {
        JSONArray(json ?: return@evaluateJavascript)
      } catch (_: Exception) {
        return@evaluateJavascript
      }
      for (i in 0 until minOf(list.length(), MAX_SCAN)) {
        val pair = list.optJSONArray(i) ?: continue
        val src = pair.optString(1)
        if (src.isEmpty() || src.length > MAX_URL) continue
        report(tab, "found") {
          it["kind"] = "element"
          it["url"] = src
          it["detail"] = pair.optString(0)
        }
      }
    }
  }

  @SuppressLint("SetJavaScriptEnabled")
  private fun page(tab: Int): WebView {
    pages[tab]?.let { return it }
    val view = WebView(activity)
    view.settings.apply {
      javaScriptEnabled = true
      domStorageEnabled = true
      allowFileAccess = false
      allowContentAccess = false
      mediaPlaybackRequiresUserGesture = true
      mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
      setSupportMultipleWindows(false)
      javaScriptCanOpenWindowsAutomatically = false
      loadWithOverviewMode = true
      useWideViewPort = true
      builtInZoomControls = true
      displayZoomControls = false
      setGeolocationEnabled(false)
    }
    view.setBackgroundColor(Color.WHITE)
    view.webViewClient = PageClient(tab)
    view.webChromeClient = ChromeClient(tab)
    // Files the page offers for download are reported, not saved: the
    // app's download manager handles them after analysis.
    view.setDownloadListener { url, _, _, _, _ ->
      if (url != null && url.length <= MAX_URL) {
        report(tab, "found") {
          it["kind"] = "download"
          it["url"] = url
          it["detail"] = ""
        }
      }
    }
    pages[tab] = view
    attach()
    return view
  }

  private fun exitFullscreen() {
    fullscreenCallback?.onCustomViewHidden()
    fullscreen?.let { (it.parent as? ViewGroup)?.removeView(it) }
    fullscreen = null
    fullscreenCallback = null
  }

  private inner class PageClient(private val tab: Int) : WebViewClient() {
    /** Stream manifests reported for the current document (bounded). */
    @Volatile
    private var requests = 0

    // App links (intent:, market:, tel:…) and every other scheme are refused.
    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
      !isWeb(request.url.toString())

    override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
      requests = 0
      report(tab, "started") { it["url"] = url ?: "" }
    }

    override fun onPageFinished(view: WebView, url: String?) {
      report(tab, "finished") {
        it["ok"] = true
        it["back"] = view.canGoBack()
        it["forward"] = view.canGoForward()
      }
    }

    override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
      if (!request.isForMainFrame) return
      report(tab, "finished") {
        it["ok"] = false
        it["back"] = view.canGoBack()
        it["forward"] = view.canGoForward()
      }
    }

    override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) {
      // Every committed navigation, including history pushes of single-page sites.
      if (url == null || isReload) return
      report(tab, "moved") {
        it["url"] = url
        it["back"] = view.canGoBack()
        it["forward"] = view.canGoForward()
      }
    }

    // Network thread: only stream manifests (HLS, DASH) are worth a look;
    // the request itself goes on untouched.
    override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
      val url = request.url
      val path = url.path?.lowercase() ?: return null
      if ((path.endsWith(".m3u8") || path.endsWith(".mpd")) && requests < MAX_REQUESTS) {
        requests += 1
        val text = url.toString()
        if (text.length <= MAX_URL) {
          main.post {
            report(tab, "found") {
              it["kind"] = "request"
              it["url"] = text
              it["detail"] = ""
            }
          }
        }
      }
      return null
    }
  }

  private inner class ChromeClient(private val tab: Int) : WebChromeClient() {
    override fun onReceivedTitle(view: WebView, title: String?) {
      report(tab, "title") { it["title"] = (title ?: "").take(MAX_TITLE) }
    }

    // Full-screen video (the page's own player): over everything, Back leaves it.
    override fun onShowCustomView(view: View, callback: CustomViewCallback) {
      if (fullscreen != null) {
        callback.onCustomViewHidden()
        return
      }
      val decor = activity.window.decorView as ViewGroup
      view.setBackgroundColor(Color.BLACK)
      decor.addView(
        view,
        FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
      )
      fullscreen = view
      fullscreenCallback = callback
    }

    override fun onHideCustomView() {
      fullscreen?.let { (it.parent as? ViewGroup)?.removeView(it) }
      fullscreen = null
      fullscreenCallback = null
    }
  }

  /** The page area of the browser screen. */
  private inner class Factory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
      val area = FrameLayout(context)
      area.setBackgroundColor(Color.WHITE)
      host = area
      attach()
      return object : PlatformView {
        override fun getView(): View = area

        override fun dispose() {
          // The pages live on (tabs keep their place); only the area goes.
          area.removeAllViews()
          if (host === area) {
            host = null
            pages[shown]?.let {
              it.evaluateJavascript(PAUSE_MEDIA, null)
              it.onPause()
            }
          }
        }
      }
    }
  }

  companion object {
    const val VIEW_TYPE = "org.miarina.media/browser_page"
    private const val MAX_SCAN = 50
    private const val MAX_REQUESTS = 20
    private const val MAX_URL = 4096
    private const val MAX_TITLE = 300

    private const val SCAN_MEDIA =
      "(function(){var o=[];document.querySelectorAll('video,audio').forEach(function(m){" +
        "var t=m.tagName.toLowerCase();if(m.currentSrc)o.push([t,m.currentSrc]);else if(m.src)o.push([t,m.src]);" +
        "m.querySelectorAll('source[src]').forEach(function(s){o.push([t,s.src])});});return o.slice(0,50);})()"

    private const val PAUSE_MEDIA =
      "document.querySelectorAll('video,audio').forEach(function(m){try{m.pause()}catch(e){}})"

    fun isWeb(url: String): Boolean {
      val scheme = Uri.parse(url).scheme?.lowercase()
      return scheme == "http" || scheme == "https"
    }
  }
}
