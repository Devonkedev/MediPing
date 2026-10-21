package com.devonkedev.remedi

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "remedi/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "schedule" -> {
                    AlarmHelper.schedule(
                        this,
                        call.argument<Int>("id")!!,
                        call.argument<Long>("time")!!,
                        call.argument<String>("title")!!,
                        call.argument<String>("body")!!,
                        call.argument<String>("repeat") ?: "none"
                    )
                    result.success(null)
                }

                "cancel" -> {
                    AlarmHelper.cancel(
                        this,
                        call.argument<Int>("id")!!
                    )
                    AlarmSoundPlayer.stop()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
