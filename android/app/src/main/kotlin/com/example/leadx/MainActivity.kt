package com.example.leadx

import android.content.Intent
import android.os.Bundle
import com.pusher.pushnotifications.PushNotifications
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerPusher()
    }

    override fun onNewIntent(intent: Intent) {
        // Required for Pusher to deliver notifications to the new activity
        super.onNewIntent(intent)
    }

    private fun registerPusher() {
        PushNotifications.start(applicationContext, "c144beef-40e3-468e-9b6b-3430167dec63")
        PushNotifications.addDeviceInterest("hello")
    }
}
