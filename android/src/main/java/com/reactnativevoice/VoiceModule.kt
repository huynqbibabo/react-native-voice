package com.reactnativevoice

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import java.io.File
import java.io.FileOutputStream
import java.util.*
import kotlin.collections.ArrayList

class VoiceModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

  private var speech: SpeechRecognizer? = null
  private var locale: String? = null
  private var mTempFiles: MutableMap<String, String> = HashMap()
  private var waveConfig: WaveConfig = WaveConfig()

  private var workingFile: File? = null
  private var outputStream: FileOutputStream? = null
  private var speechResult: ArrayList<String>? = null

  private val moduleStates = object {
    var none: String = "NONE"
    var recording: String = "RECORDING"
    var recognizing: String = "RECOGNIZING"
  }

  private val moduleEvents = object {
    var onVoiceStart: String = "onVoiceStart"
    var onVoice: String = "onVoice"
    var onVoiceEnd: String = "onVoiceEnd"
    var onError: String = "onError"
    var onSpeechRecognized = "onSpeechRecognized"
    var onModuleStateChange = "onModuleStateChange"
  }

  private var state = moduleStates.none
  private var _channel: Double? = null
  private var sentence: String? = null

  override fun getName(): String {
    return TAG
  }

  private fun getLocale(locale: String?): String {
    return if (locale != null && locale != "") {
      locale
    } else Locale.getDefault().toString()
  }

  private fun startListening(opts: ReadableMap) {
    if (speech != null) {
      speech!!.destroy()
      speech = null

    }
    speech = if (opts.hasKey("RECOGNIZER_ENGINE")) {
      when (opts.getString("RECOGNIZER_ENGINE")) {
        "GOOGLE" -> {
          SpeechRecognizer.createSpeechRecognizer(
            reactApplicationContext,
            ComponentName.unflattenFromString("com.google.android.googlequicksearchbox/com.google.android.voicesearch.serviceapi.GoogleRecognitionService")
          )
        }
        else -> SpeechRecognizer.createSpeechRecognizer(reactApplicationContext)
      }
    } else {
      SpeechRecognizer.createSpeechRecognizer(reactApplicationContext)
    }
    speech?.setRecognitionListener(mRecognitionListener)
    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)

    // Load the intent with options from JS
    val iterator = opts.keySetIterator()
    while (iterator.hasNextKey()) {
      when (val key = iterator.nextKey()) {
        "EXTRA_LANGUAGE_MODEL" -> when (opts.getString(key)) {
          "LANGUAGE_MODEL_FREE_FORM" -> intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
          "LANGUAGE_MODEL_WEB_SEARCH" -> intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_WEB_SEARCH)
          else -> intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        }
        "EXTRA_MAX_RESULTS" -> {
          val extras = opts.getDouble(key)
          intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, extras.toInt())
        }
        "EXTRA_PARTIAL_RESULTS" -> {
          intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, opts.getBoolean(key))
        }
        "EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS" -> {
          val extras = opts.getDouble(key)
          intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, extras.toInt())
        }
        "EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS" -> {
          val extras = opts.getDouble(key)
          intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, extras.toInt())
        }
        "EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS" -> {
          val extras = opts.getDouble(key)
          intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, extras.toInt())
        }
      }
    }
    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, getLocale(locale))
    speech?.startListening(intent)
  }

  @ReactMethod
  fun start(channel: Double, textToScore: String, opts: ReadableMap, promise: Promise) {

    locale = opts.getString("locale")
    val mainHandler = Handler(reactApplicationContext!!.mainLooper)
    mainHandler.post {
      try {
        startListening(opts)
        _channel = channel
        state = moduleStates.recording
        sentence = textToScore

        workingFile?.delete()
        workingFile = null
        workingFile = buildFile()
        outputStream = workingFile?.outputStream()

        promise.resolve(true)
        emitStateChangeEvent()
      } catch (e: Exception) {
        promise.reject("-1", e.message)
        handleErrorEvent(e)
      }
    }
  }

  @ReactMethod
  fun stop(channel: Double, promise: Promise) {
    _channel = channel
    val mainHandler = Handler(reactApplicationContext!!.mainLooper)
    mainHandler.post {
      try {
        speech?.stopListening()
        outputStream?.close()

        promise.resolve(true)

        if (speechResult != null) {
          state = moduleStates.recognizing
          emitStateChangeEvent()
          recognize()
        } else {
          state = moduleStates.none
          emitStateChangeEvent()
        }
      } catch (e: Exception) {
        promise.reject("-1", e.message)
        handleErrorEvent(e)
      }
    }
  }

  @ReactMethod
  fun cancel(channel: Double, promise: Promise) {
    _channel = channel
    speechResult = null
    val mainHandler = Handler(reactApplicationContext!!.mainLooper)
    mainHandler.post {
      try {
        speech?.cancel()
        outputStream?.close()
        releaseResources()
        state = moduleStates.none
        promise.resolve(true)
        emitStateChangeEvent()
      } catch (e: Exception) {
        promise.reject("-1", e.message)
        handleErrorEvent(e)
      }
    }
  }

  @ReactMethod
  fun release(promise: Promise) {
    val mainHandler = Handler(reactApplicationContext!!.mainLooper)
    speechResult = null
    mainHandler.post {
      if (speech != null) {
        speech!!.destroy()
      }
      speech = null
      speechResult = null
      workingFile = null
      outputStream = null
      val path = reactApplicationContext.externalCacheDir?.absolutePath + "/AudioCacheFiles/"
      val pathAsFile = File(path)

      if (pathAsFile.isDirectory) {
        pathAsFile.delete()
      }
      promise.resolve(true)
    }
  }

  @ReactMethod
  fun isSpeechAvailable(promise: Promise) {
    val self = this
    val mainHandler = Handler(reactApplicationContext!!.mainLooper)
    mainHandler.post {
      try {
        val isSpeechAvailable = SpeechRecognizer.isRecognitionAvailable(self.reactApplicationContext)
        promise.resolve(isSpeechAvailable)
      } catch (e: Exception) {
        promise.reject("-1", e.message)
        handleErrorEvent(e)
      }
    }
  }

  @ReactMethod
  fun getSpeechRecognitionServices(promise: Promise) {
    val services = reactApplicationContext!!.packageManager
      .queryIntentServices(Intent(RecognitionService.SERVICE_INTERFACE), 0)
    val serviceNames = Arguments.createArray()
    for (service in services) {
      serviceNames.pushString(service.serviceInfo.packageName)
    }
    promise.resolve(serviceNames)
  }

  @ReactMethod
  fun getState(promise: Promise) {
    promise.resolve(state)
  }

  private fun recognize() {

    val levenshteinWordList = Levenshtein(sentence!!, speechResult!!).scoreSentence()
    Handler(Looper.getMainLooper()).postDelayed({
      workingFile?.let { WaveHeaderWriter(it, waveConfig).writeHeader() }
//      for ((key, value) in speechResult) {
//        Log.i(TAG, "recognize: $key - $value")
//      }
      val response: WritableMap = WritableNativeMap()
      response.putString("text", sentence)
      response.putString("fidelityClass", "CORRECT")
      val wordScoreList: WritableArray = WritableNativeArray()
      var summaryQualityScore = 0
      var transcript = ""
      for (levenshteinWord in levenshteinWordList) {
        val wordScore: WritableMap = WritableNativeMap()
        wordScore.putString("word", levenshteinWord.wordScore?.word)
        wordScore.putDouble("qualityScore", levenshteinWord.wordScore!!.percentageOfTextMatch.toDouble())
        wordScore.putDouble("levenshteinScore", levenshteinWord.wordScore!!.levenshteinDistance.toDouble())
        summaryQualityScore += levenshteinWord.wordScore!!.percentageOfTextMatch
        transcript += "${levenshteinWord.wordScore?.transcript} "
        wordScoreList.pushMap(wordScore)
      }

      response.putString("transcript", transcript)
      response.putDouble("qualityScore", (summaryQualityScore / levenshteinWordList.size).toDouble())
      response.putArray("wordScoreList", wordScoreList)

      val event = Arguments.createMap()
      event.putString("filePath", workingFile?.absolutePath)
      event.putMap("response", response)
      event.putDouble("channel", _channel!!)
      sendEvent(moduleEvents.onSpeechRecognized, event)
      state = moduleStates.none
      workingFile = null
      speechResult = null
      emitStateChangeEvent()
    }, 1000)
  }

  private fun isPermissionGranted(): Boolean {
    val permission = Manifest.permission.RECORD_AUDIO
    val res = reactApplicationContext.checkCallingOrSelfPermission(permission)
    return res == PackageManager.PERMISSION_GRANTED
  }

  private fun sendEvent(eventName: String, params: WritableMap?) {
    reactApplicationContext
      ?.getJSModule(RCTDeviceEventEmitter::class.java)
      ?.emit(eventName, params)
  }

  private val mRecognitionListener: RecognitionListener = object : RecognitionListener {
    override fun onReadyForSpeech(arg0: Bundle?) {
      val event = Arguments.createMap()
      event.putBoolean("error", false)
      sendEvent("onSpeechStart", event)
    }

    override fun onBeginningOfSpeech() {
      val event = Arguments.createMap()
      sendEvent(moduleEvents.onVoiceStart, event)
    }

    override fun onRmsChanged(rmsdB: Float) {
      val event = Arguments.createMap()
      event.putDouble("value", rmsdB.toDouble())
      sendEvent(moduleEvents.onVoice, event)
    }

    override fun onBufferReceived(buffer: ByteArray?) {
      val bufferSize = AudioRecord.getMinBufferSize(
        16000,
        AudioFormat.CHANNEL_IN_MONO,
        AudioFormat.ENCODING_PCM_16BIT
      )

      val data = ByteArray(bufferSize)
      outputStream?.write(data)
    }

    override fun onEndOfSpeech() {
      Log.i(TAG, "onEndOfSpeech: ")
      val event = Arguments.createMap()
      sendEvent(moduleEvents.onVoiceEnd, event)
    }

    override fun onError(errorCode: Int) {
      val errorMessage = String.format("%d/%s", errorCode, getErrorText(errorCode))
      val event = Arguments.createMap()
      event.putString("message", errorMessage)
      event.putDouble("channel", _channel!!)
      sendEvent(moduleEvents.onError, event)
    }

    override fun onResults(results: Bundle) {
      val matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
//      val scores = results.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
      Log.i(TAG, "onResults: $matches")
      speechResult = matches

      outputStream?.close()

      if (speechResult != null) {
        state = moduleStates.recognizing
        emitStateChangeEvent()
        recognize()
      } else {
        state = moduleStates.none
        emitStateChangeEvent()
      }
    }

    override fun onPartialResults(results: Bundle) {
      val matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
      Log.i(TAG, "onPartialResults: $matches")
//      if (matches != null) {
//        for (result in matches) {
//          arr.pushString(result)
//        }
//      }

    }

    override fun onEvent(eventType: Int, params: Bundle?) {
      TODO("Not yet implemented")
    }

  }

  private fun getErrorText(errorCode: Int): String {
    return when (errorCode) {
      SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
      SpeechRecognizer.ERROR_CLIENT -> "Client side error"
      SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
      SpeechRecognizer.ERROR_NETWORK -> "Network error"
      SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
      SpeechRecognizer.ERROR_NO_MATCH -> "No match"
      SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RecognitionService busy"
      SpeechRecognizer.ERROR_SERVER -> "error from server"
      SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
      else -> "Didn't understand, please try again."
    }
  }

  private fun buildFile(): File {
    val path = reactApplicationContext.externalCacheDir?.absolutePath + "/AudioCacheFiles/"
    val pathAsFile = File(path)

    if (!pathAsFile.isDirectory) {
      pathAsFile.mkdir()
    }
    val fileId = System.currentTimeMillis().toString()
    val filePath = "$path/$fileId.wav"
    mTempFiles[fileId] = filePath
    return File(filePath)
  }

  private fun releaseResources() {
    outputStream?.close()
    outputStream = null
    workingFile?.delete()
    workingFile = null
    state = moduleStates.none
  }

  private fun handleErrorEvent(throwable: Throwable) {
    throwable.printStackTrace()
    speech?.stopListening()
    releaseResources()

    sendJSErrorEvent(throwable.message)

    state = moduleStates.none
    emitStateChangeEvent()
  }

  private fun emitStateChangeEvent() {
    val params = Arguments.createMap()
    params.putString("state", state)
    params.putDouble("channel", _channel!!)
    sendJSEvent(moduleEvents.onModuleStateChange, params)
  }

  private fun sendJSErrorEvent(message: String?) {
    val params = Arguments.createMap()
    params.putString("message", message)
    params.putDouble("channel", _channel!!)
    sendJSEvent(moduleEvents.onError, params)
  }

  private fun sendJSEvent(
    eventName: String,
    params: WritableMap
  ) {
    reactApplicationContext
      .getJSModule(RCTDeviceEventEmitter::class.java)
      .emit(eventName, params)
  }

  companion object {
    private const val TAG = "Voice"
  }
}
