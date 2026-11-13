package org.miarina.media

import android.media.audiofx.Equalizer
import kotlin.math.ln
import kotlin.math.roundToInt

/**
 * Android equalizer (AND-10) on the audio session of the playback service:
 * applied to what plays, files are never modified. The page sends the six
 * gains of the shared model (dB, design screen 09: 60, 230, 910, 3,6k, 9k,
 * 14k Hz); each band of the device gets the gain interpolated at its centre
 * frequency (log scale), within the device's range. The setting is kept here
 * so it applies again when the service (re)creates its player.
 */
object MiarinaEqualizer {
  private val MODEL_HZ = doubleArrayOf(60.0, 230.0, 910.0, 3600.0, 9000.0, 14000.0)

  private var enabled = false
  private var gains = DoubleArray(MODEL_HZ.size)
  private var effect: Equalizer? = null
  private var session = 0

  /** `null` until a player session exists; then whether the device supports it. */
  @Volatile
  var supported: Boolean? = null
    private set

  @Synchronized
  fun set(on: Boolean, values: List<Double>) {
    enabled = on
    if (values.size == MODEL_HZ.size) gains = values.map { it.coerceIn(-12.0, 12.0) }.toDoubleArray()
    apply()
  }

  /** The service's player got (or changed) its audio session. */
  @Synchronized
  fun attach(audioSession: Int) {
    if (audioSession == session && effect != null) return
    release()
    session = audioSession
    if (audioSession == 0) return
    effect = try {
      Equalizer(0, audioSession).also { supported = it.numberOfBands > 0 }
    } catch (e: Exception) {
      supported = false
      null
    }
    apply()
  }

  @Synchronized
  fun release() {
    effect?.let {
      try {
        it.release()
      } catch (_: Exception) {
      }
    }
    effect = null
    session = 0
  }

  /** Gain of the model at `hz`, interpolated on a log-frequency scale. */
  private fun gainAt(hz: Double): Double {
    if (hz <= MODEL_HZ.first()) return gains.first()
    if (hz >= MODEL_HZ.last()) return gains.last()
    val i = MODEL_HZ.indexOfFirst { it >= hz }
    val lo = ln(MODEL_HZ[i - 1])
    val t = (ln(hz) - lo) / (ln(MODEL_HZ[i]) - lo)
    return gains[i - 1] + t * (gains[i] - gains[i - 1])
  }

  private fun apply() {
    val eq = effect ?: return
    try {
      if (!enabled) {
        eq.enabled = false
        return
      }
      val range = eq.bandLevelRange
      for (band in 0 until eq.numberOfBands) {
        val hz = eq.getCenterFreq(band.toShort()) / 1000.0
        val millibels = (gainAt(hz) * 100).roundToInt().coerceIn(range[0].toInt(), range[1].toInt())
        eq.setBandLevel(band.toShort(), millibels.toShort())
      }
      eq.enabled = true
    } catch (e: Exception) {
      // The effect was taken by a higher-priority app or released: next attach retries.
    }
  }
}
