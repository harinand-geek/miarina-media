package org.miarina.media

import android.annotation.SuppressLint
import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSArray
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import org.json.JSONArray
import java.io.ByteArrayOutputStream

/** Page area in CSS pixels of the app WebView; `fab` is the button label, null = hidden. */
@InvokeArg
class FrameArgs {
  var x: Double = 0.0
  var y: Double = 0.0
  var width: Double = 0.0
  var height: Double = 0.0
  var visible: Boolean = false
  var fab: String? = null
  /** Return a JPEG of the page before hiding it (drawn under the app's sheets and menus). */
  var snapshot: Boolean = false
}

@InvokeArg
class LoadArgs {
  lateinit var url: String
}

@InvokeArg
class ActionArgs {
  lateinit var action: String
}

/**
 * Built-in browser on Android (decision 0001, designs M1/M3): a native
 * WebView placed over the page area the React browser screen leaves free,
 * like the Media3 surface of NativePlayerPlugin.
 *
 * The visited page is untrusted: no JavaScript interface, no file or
 * content access, http(s) only, no popups, no native downloads. What it
 * reveals (`<video>`/`<audio>` sources of the top document, files it offers
 * for download) is queued raw, bounded, and classified by Rust
 * (`media_core::detect`), which polls `poll`. URLs to open are resolved and validated by Rust.
 *
 * Native views are drawn above the app WebView, so the floating download
 * button is native too, and the app hides the page while one of its own
 * sheets or menus covers it (`frame` with `visible = false`).
 */
@TauriPlugin
class BrowserPlugin(private val activity: Activity) : Plugin(activity) {
  private var host: WebView? = null
  private var page: WebView? = null
  private var fab: TextView? = null
  private var fullscreen: View? = null
  private var fullscreenCallback: WebChromeClient.CustomViewCallback? = null
  private var visible = false

  private val main = Handler(Looper.getMainLooper())
  private val scan = object : Runnable {
    override fun run() {
      scanPage()
      main.postDelayed(this, SCAN_INTERVAL_MS)
    }
  }

  // Written by WebView callbacks (some on its network thread), read by poll.
  private val lock = Any()
  private val observations = ArrayList<JSObject>()
  private var generation = 0
  private var progress = 0
  private var loading = false
  private var title = ""
  private var fabAction: String? = null

  override fun load(webView: WebView) {
    host = webView
  }

  @Command
  fun frame(invoke: Invoke) {
    val args = invoke.parseArgs(FrameArgs::class.java)
    val result = JSObject()
    val view = page
    if (args.snapshot && view != null && view.visibility == View.VISIBLE) {
      snapshot(view)?.let { result.put("snapshot", it) }
    }
    val show = args.visible && args.width > 0 && args.height > 0
    if (!show) {
      hide()
      invoke.resolve(result)
      return
    }
    val web = host
    val container = web?.parent as? ViewGroup
    if (web == null || container == null) {
      invoke.reject("The page view is not ready")
      return
    }
    val target = ensurePage(container)
    // CSS pixels are density-independent pixels (see NativePlayerPlugin).
    val density = activity.resources.displayMetrics.density
    target.layoutParams = target.layoutParams.also {
      it.width = (args.width * density).toInt()
      it.height = (args.height * density).toInt()
    }
    val left = web.left - container.paddingLeft + args.x.toFloat() * density
    val top = web.top - container.paddingTop + args.y.toFloat() * density
    target.translationX = left
    target.translationY = top
    if (target.visibility != View.VISIBLE) {
      target.visibility = View.VISIBLE
      target.onResume()
    }
    if (!visible) {
      visible = true
      main.removeCallbacks(scan)
      main.postDelayed(scan, SCAN_INTERVAL_MS)
    }
    placeFab(container, args.fab, left, top, args.width.toFloat() * density, args.height.toFloat() * density)
    invoke.resolve(result)
  }

  @Command
  fun load(invoke: Invoke) {
    val args = invoke.parseArgs(LoadArgs::class.java)
    val container = host?.parent as? ViewGroup
    if (container == null || !isWeb(args.url)) {
      invoke.reject("This address cannot be opened")
      return
    }
    ensurePage(container).loadUrl(args.url)
    invoke.resolve()
  }

  @Command
  fun action(invoke: Invoke) {
    val args = invoke.parseArgs(ActionArgs::class.java)
    val view = page
    when (args.action) {
      "back" -> when {
        fullscreen != null -> fullscreenCallback?.onCustomViewHidden()
        view?.canGoBack() == true -> view.goBack()
      }
      "forward" -> if (view?.canGoForward() == true) view.goForward()
      "reload" -> view?.reload()
      "stop" -> view?.stopLoading()
      // Start page: the app draws it; the page view stays for Back.
      "home" -> view?.loadUrl(BLANK)
      else -> {
        invoke.reject("Unknown browser action")
        return
      }
    }
    invoke.resolve()
  }

  /** State and the observations queued since the last call (taken once). */
  @Command
  fun poll(invoke: Invoke) {
    val view = page
    val result = JSObject()
    synchronized(lock) {
      result.put("generation", generation)
      result.put("progress", progress)
      result.put("loading", loading)
      result.put("title", title)
      fabAction?.let { result.put("fab", it) }
      fabAction = null
      val items = JSArray()
      observations.forEach { items.put(it) }
      observations.clear()
      result.put("observations", items)
    }
    result.put("url", view?.url ?: "")
    result.put("canGoBack", view?.canGoBack() == true || fullscreen != null)
    result.put("canGoForward", view?.canGoForward() == true)
    invoke.resolve(result)
  }

  override fun onPause() {
    page?.onPause()
  }

  override fun onResume() {
    if (visible) page?.onResume()
  }

  override fun onDestroy() {
    main.removeCallbacks(scan)
    page?.let {
      (it.parent as? ViewGroup)?.removeView(it)
      it.destroy()
    }
    page = null
  }

  private fun hide() {
    if (!visible) return
    visible = false
    main.removeCallbacks(scan)
    fab?.visibility = View.GONE
    page?.let {
      // A hidden page must not keep playing out loud.
      it.evaluateJavascript(PAUSE_MEDIA, null)
      it.visibility = View.GONE
      it.onPause()
    }
  }

  @SuppressLint("SetJavaScriptEnabled")
  private fun ensurePage(container: ViewGroup): WebView {
    page?.let { return it }
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
    view.webViewClient = PageClient()
    view.webChromeClient = ChromeClient()
    // Files the page offers for download are reported, not saved: the app's
    // download manager handles them after analysis.
    view.setDownloadListener { url, _, _, mimeType, contentLength ->
      observe("download", url) {
        it.put("mime", mimeType ?: "")
        if (contentLength > 0) it.put("size", contentLength)
      }
    }
    view.visibility = View.GONE
    // Above the app WebView, below views added later (player surface).
    container.addView(view, FrameLayout.LayoutParams(0, 0))
    page = view
    return view
  }

  private fun placeFab(container: ViewGroup, label: String?, left: Float, top: Float, width: Float, height: Float) {
    if (label.isNullOrBlank() || fullscreen != null) {
      fab?.visibility = View.GONE
      return
    }
    val button = fab ?: createFab(container).also { fab = it }
    button.text = label.take(MAX_LABEL)
    button.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
    val margin = dp(16f)
    button.translationX = left + (width - button.measuredWidth) / 2
    val y = top + height - margin - button.measuredHeight
    if (button.visibility != View.VISIBLE) {
      // Enters with a 200 ms fade and 12 dp rise (design B).
      button.alpha = 0f
      button.translationY = y + dp(12f)
      button.visibility = View.VISIBLE
      button.animate().alpha(1f).translationY(y).setDuration(200).start()
    } else {
      button.animate().cancel()
      button.alpha = 1f
      button.translationY = y
    }
    button.bringToFront()
  }

  private fun createFab(container: ViewGroup): TextView {
    val button = TextView(activity)
    val icon = ContextCompat.getDrawable(activity, R.drawable.ic_browser_download)?.mutate()
    icon?.setTint(FAB_INK)
    icon?.setBounds(0, 0, dp(22f).toInt(), dp(22f).toInt())
    button.setCompoundDrawables(icon, null, null, null)
    button.compoundDrawablePadding = dp(8f).toInt()
    button.setTextColor(FAB_INK)
    button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
    button.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
    button.gravity = Gravity.CENTER
    button.maxLines = 1
    button.minHeight = dp(52f).toInt()
    button.setPadding(dp(18f).toInt(), 0, dp(22f).toInt(), 0)
    button.background = GradientDrawable().apply {
      setColor(FAB_COLOR)
      cornerRadius = dp(26f)
    }
    button.elevation = dp(10f)
    button.isClickable = true
    button.isLongClickable = true
    button.contentDescription = "Download media found on this page"
    button.setOnClickListener { synchronized(lock) { fabAction = "tap" } }
    button.setOnLongClickListener {
      synchronized(lock) { fabAction = "hold" }
      true
    }
    button.visibility = View.GONE
    container.addView(button, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(52f).toInt()))
    return button
  }

  /** Lists `<video>`/`<audio>` sources; the result is page data, checked by Rust. */
  private fun scanPage() {
    val view = page ?: return
    if (!visible) return
    val scanned = synchronized(lock) { generation }
    view.evaluateJavascript(SCAN_MEDIA) { json ->
      val list = try {
        JSONArray(json ?: return@evaluateJavascript)
      } catch (_: Exception) {
        return@evaluateJavascript
      }
      for (i in 0 until minOf(list.length(), MAX_SCAN)) {
        val pair = list.optJSONArray(i) ?: continue
        val tag = pair.optString(0)
        val src = pair.optString(1)
        observe("element", src, scanned) { it.put("tag", tag) }
      }
    }
  }

  private fun observe(type: String, url: String?, at: Int? = null, fill: (JSObject) -> Unit = {}) {
    if (url.isNullOrEmpty() || url.length > MAX_URL) return
    synchronized(lock) {
      if (observations.size >= MAX_OBSERVATIONS) return
      val item = JSObject()
      item.put("type", type)
      item.put("url", url)
      item.put("generation", at ?: generation)
      fill(item)
      observations.add(item)
    }
  }

  /** A new document or a single-page-app navigation: detections restart. */
  private fun newPage() {
    synchronized(lock) {
      generation += 1
      observations.clear()
    }
  }

  private fun snapshot(view: WebView): String? {
    if (view.width <= 0 || view.height <= 0) return null
    return try {
      val scale = SNAPSHOT_SCALE
      val bitmap = Bitmap.createBitmap(
        (view.width * scale).toInt().coerceAtLeast(1),
        (view.height * scale).toInt().coerceAtLeast(1),
        Bitmap.Config.RGB_565,
      )
      val canvas = Canvas(bitmap)
      canvas.scale(scale, scale)
      canvas.translate(-view.scrollX.toFloat(), -view.scrollY.toFloat())
      view.draw(canvas)
      val out = ByteArrayOutputStream()
      bitmap.compress(Bitmap.CompressFormat.JPEG, 70, out)
      bitmap.recycle()
      "data:image/jpeg;base64," + Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    } catch (_: Throwable) {
      null
    }
  }

  private fun dp(value: Float) = value * activity.resources.displayMetrics.density

  private inner class PageClient : WebViewClient() {
    // App links (intent:, market:, tel:…) and every other scheme are refused.
    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
      !isWeb(request.url.toString())

    override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
      synchronized(lock) { loading = true }
    }

    override fun onPageFinished(view: WebView, url: String?) {
      synchronized(lock) {
        loading = false
        progress = 100
      }
      scanPage()
    }

    override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) {
      // Every committed navigation, including history pushes of single-page sites.
      if (!isReload && url != lastUrl) newPage()
      lastUrl = url
    }

    private var lastUrl: String? = null
  }

  private inner class ChromeClient : WebChromeClient() {
    override fun onProgressChanged(view: WebView, newProgress: Int) {
      synchronized(lock) { progress = newProgress.coerceIn(0, 100) }
    }

    override fun onReceivedTitle(view: WebView, title: String?) {
      synchronized(lock) { this@BrowserPlugin.title = (title ?: "").take(MAX_TITLE) }
    }

    // Full-screen video (the page's own player): over everything, Back leaves it.
    override fun onShowCustomView(view: View, callback: CustomViewCallback) {
      if (fullscreen != null) {
        callback.onCustomViewHidden()
        return
      }
      val decor = activity.window.decorView as ViewGroup
      view.setBackgroundColor(Color.BLACK)
      decor.addView(view, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
      fullscreen = view
      fullscreenCallback = callback
      fab?.visibility = View.GONE
    }

    override fun onHideCustomView() {
      fullscreen?.let { (it.parent as? ViewGroup)?.removeView(it) }
      fullscreen = null
      fullscreenCallback = null
    }
  }

  companion object {
    const val BLANK = "about:blank"
    private const val SCAN_INTERVAL_MS = 3_000L
    private const val MAX_OBSERVATIONS = 200
    private const val MAX_SCAN = 50
    private const val MAX_URL = 4096
    private const val MAX_TITLE = 300
    private const val MAX_LABEL = 40
    private const val SNAPSHOT_SCALE = 0.5f
    private val FAB_COLOR = Color.parseColor("#35C9BD")
    private val FAB_INK = Color.parseColor("#062320")

    private const val SCAN_MEDIA =
      "(function(){var o=[];document.querySelectorAll('video,audio').forEach(function(m){" +
        "var t=m.tagName.toLowerCase();if(m.currentSrc)o.push([t,m.currentSrc]);else if(m.src)o.push([t,m.src]);" +
        "m.querySelectorAll('source[src]').forEach(function(s){o.push([t,s.src])});});return o.slice(0,50);})()"

    private const val PAUSE_MEDIA =
      "document.querySelectorAll('video,audio').forEach(function(m){try{m.pause()}catch(e){}})"

    fun isWeb(url: String): Boolean {
      val scheme = Uri.parse(url).scheme?.lowercase()
      return scheme == "http" || scheme == "https" || url == BLANK
    }
  }
}
