package com.kree8designs.pocketquote

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Handle the splash screen transition.
        val splashScreen = installSplashScreen()

        // Explicitly enable edge-to-edge for Android 15 compatibility
        enableEdgeToEdge()

        super.onCreate(savedInstanceState)
    }
}
