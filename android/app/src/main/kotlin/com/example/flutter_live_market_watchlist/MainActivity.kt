package com.example.flutter_live_market_watchlist

import android.os.Handler
import android.os.Looper
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val tokenChannelName = "pulse/secure_token"
    private val connectivityChannelName = "pulse/connectivity"
    private val prefsFileName = "pulse_secure_prefs"
    private val tokenKey = "auth_token"

    private lateinit var connectivityManager: ConnectivityManager
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, tokenChannelName)
            .setMethodCallHandler { call, result ->
                try {
                    val prefs = securePrefs()
                    when (call.method) {
                        "save" -> {
                            val token = call.argument<String>("token")
                            prefs.edit().putString(tokenKey, token).apply()
                            result.success(null)
                        }
                        "read" -> result.success(prefs.getString(tokenKey, null))
                        "delete" -> {
                            prefs.edit().remove(tokenKey).apply()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("SECURE_STORAGE_ERROR", e.message, null)
                }
            }

        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, connectivityChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    events.success(isCurrentlyOnline())

                    val callback = object : ConnectivityManager.NetworkCallback() {
                        override fun onAvailable(network: Network) {
                            events.success(isCurrentlyOnline())
                        }

                        override fun onLost(network: Network) {
                            events.success(isCurrentlyOnline())
                        }

                        override fun onCapabilitiesChanged(
                            network: Network,
                            capabilities: NetworkCapabilities
                        ) {
                            events.success(
                                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                                    capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                            )
                        }
                    }
                    networkCallback = callback
                    connectivityManager.registerNetworkCallback(NetworkRequest.Builder().build(), callback, Handler(Looper.getMainLooper()))
                }

                override fun onCancel(arguments: Any?) {
                    networkCallback?.let { connectivityManager.unregisterNetworkCallback(it) }
                    networkCallback = null
                }
            })
    }

    private fun securePrefs() = EncryptedSharedPreferences.create(
        applicationContext,
        prefsFileName,
        MasterKey.Builder(applicationContext).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private fun isCurrentlyOnline(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
}
