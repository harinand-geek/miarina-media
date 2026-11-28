package org.miarina.media

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Where the music goes (decision 0013, proposal 9: one equalizer per
 * output): Bluetooth, a wired or USB headset, or the phone's speaker, in
 * the order Android routes media. Says "changed" when a device comes or
 * goes. Channel org.miarina.media/audio_route; no permission needed.
 */
class AudioRouteChannel(context: Context, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  private val channel = MethodChannel(messenger, "org.miarina.media/audio_route")
  private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
  private var last: Map<String, String>? = null

  private val bluetooth = buildSet {
    add(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP)
    if (Build.VERSION.SDK_INT >= 28) add(AudioDeviceInfo.TYPE_HEARING_AID)
    if (Build.VERSION.SDK_INT >= 31) {
      add(AudioDeviceInfo.TYPE_BLE_HEADSET)
      add(AudioDeviceInfo.TYPE_BLE_SPEAKER)
    }
  }

  private val wired = buildSet {
    add(AudioDeviceInfo.TYPE_WIRED_HEADSET)
    add(AudioDeviceInfo.TYPE_WIRED_HEADPHONES)
    add(AudioDeviceInfo.TYPE_USB_DEVICE)
    add(AudioDeviceInfo.TYPE_LINE_ANALOG)
    add(AudioDeviceInfo.TYPE_AUX_LINE)
    if (Build.VERSION.SDK_INT >= 26) add(AudioDeviceInfo.TYPE_USB_HEADSET)
  }

  private val callback = object : AudioDeviceCallback() {
    override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) = changed()
    override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) = changed()
  }

  init {
    channel.setMethodCallHandler(this)
    audio.registerAudioDeviceCallback(callback, Handler(Looper.getMainLooper()))
  }

  private fun changed() {
    val now = current()
    if (now != last) {
      last = now
      channel.invokeMethod("changed", now)
    }
  }

  private fun current(): Map<String, String> {
    val outputs = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    outputs.firstOrNull { it.type in bluetooth }?.let {
      return mapOf("kind" to "bluetooth", "name" to it.productName.toString())
    }
    outputs.firstOrNull { it.type in wired }?.let {
      return mapOf("kind" to "wired", "name" to it.productName.toString())
    }
    return mapOf("kind" to "speaker", "name" to "")
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "current" -> {
        val now = current()
        last = now
        result.success(now)
      }
      else -> result.notImplemented()
    }
  }

  fun dispose() {
    audio.unregisterAudioDeviceCallback(callback)
    channel.setMethodCallHandler(null)
  }
}
