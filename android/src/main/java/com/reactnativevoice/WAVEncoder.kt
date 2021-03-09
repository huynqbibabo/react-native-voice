package com.reactnativevoice

import android.media.AudioFormat
import java.io.File
import java.io.RandomAccessFile

data class WaveConfig(
  var sampleRate: Int = 16000,
  var channels: Int = AudioFormat.CHANNEL_IN_MONO,
  var audioEncoding: Int = AudioFormat.ENCODING_PCM_16BIT,
  var audioLengthInSeconds: Int = 15
)

internal fun bitPerSample(audioEncoding: Int) = when (audioEncoding) {
  AudioFormat.ENCODING_PCM_8BIT -> 8
  AudioFormat.ENCODING_PCM_16BIT -> 16
  else -> 16
}

internal class WaveHeaderWriter(private val file: File, private val waveConfig: WaveConfig) {

  fun writeHeader() {
    val inputStream = file.inputStream()

    val totalAudioLen = inputStream.channel.size() - 44
    val totalDataLen = totalAudioLen + 36
    val channels = if (waveConfig.channels == AudioFormat.CHANNEL_IN_MONO)
      1
    else
      2

    val sampleRate = waveConfig.sampleRate.toLong()
    val byteRate =
      (bitPerSample(waveConfig.audioEncoding) * waveConfig.sampleRate * channels / 8).toLong()
    val header = getWavFileHeaderByteArray(
      totalAudioLen,
      totalDataLen,
      sampleRate,
      channels,
      byteRate,
      bitPerSample(waveConfig.audioEncoding)
    )

    val randomAccessFile = RandomAccessFile(file, "rw")
    randomAccessFile.seek(0)
    randomAccessFile.write(header)
    randomAccessFile.close()
  }

  private fun getWavFileHeaderByteArray(
    totalAudioLen: Long, totalDataLen: Long, longSampleRate: Long,
    channels: Int, byteRate: Long, bitsPerSample: Int
  ): ByteArray {
    val header = ByteArray(44)
    header[0] = 'R'.toByte()
    header[1] = 'I'.toByte()
    header[2] = 'F'.toByte()
    header[3] = 'F'.toByte()
    header[4] = (totalDataLen and 0xff).toByte()
    header[5] = (totalDataLen shr 8 and 0xff).toByte()
    header[6] = (totalDataLen shr 16 and 0xff).toByte()
    header[7] = (totalDataLen shr 24 and 0xff).toByte()
    header[8] = 'W'.toByte()
    header[9] = 'A'.toByte()
    header[10] = 'V'.toByte()
    header[11] = 'E'.toByte()
    header[12] = 'f'.toByte()
    header[13] = 'm'.toByte()
    header[14] = 't'.toByte()
    header[15] = ' '.toByte()
    header[16] = 16
    header[17] = 0
    header[18] = 0
    header[19] = 0
    header[20] = 1
    header[21] = 0
    header[22] = channels.toByte()
    header[23] = 0
    header[24] = (longSampleRate and 0xff).toByte()
    header[25] = (longSampleRate shr 8 and 0xff).toByte()
    header[26] = (longSampleRate shr 16 and 0xff).toByte()
    header[27] = (longSampleRate shr 24 and 0xff).toByte()
    header[28] = (byteRate and 0xff).toByte()
    header[29] = (byteRate shr 8 and 0xff).toByte()
    header[30] = (byteRate shr 16 and 0xff).toByte()
    header[31] = (byteRate shr 24 and 0xff).toByte()
    header[32] = (channels * (bitsPerSample / 8)).toByte()
    header[33] = 0
    header[34] = bitsPerSample.toByte()
    header[35] = 0
    header[36] = 'd'.toByte()
    header[37] = 'a'.toByte()
    header[38] = 't'.toByte()
    header[39] = 'a'.toByte()
    header[40] = (totalAudioLen and 0xff).toByte()
    header[41] = (totalAudioLen shr 8 and 0xff).toByte()
    header[42] = (totalAudioLen shr 16 and 0xff).toByte()
    header[43] = (totalAudioLen shr 24 and 0xff).toByte()
    return header
  }
}
