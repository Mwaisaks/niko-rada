package com.nikorada.niko_rada

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var hybrid: HybridInferencePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        hybrid = HybridInferencePlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        hybrid?.dispose()
        hybrid = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
