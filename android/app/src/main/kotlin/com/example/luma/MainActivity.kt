package com.example.luma

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.TelephonyCallback
import android.telephony.TelephonyDisplayInfo
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingPermission: MethodChannel.Result? = null
    private var displayOverride = 0
    private var displayInfoCallback: Any? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handleCall)
        startDisplayInfoListener()
    }

    override fun onDestroy() {
        stopDisplayInfoListener()
        super.onDestroy()
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "describe" -> result.success(describeNetwork())
            "hasPermissions" -> result.success(missingPermissions().isEmpty())
            "requestPermissions" -> requestNetworkPermissions(result)
            else -> result.notImplemented()
        }
    }

    private fun describeNetwork(): Map<String, Any?> {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val capabilities = manager?.activeNetwork?.let { manager.getNetworkCapabilities(it) }
        val transport = when {
            capabilities == null -> "offline"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "vpn"
            else -> "unknown"
        }
        return mapOf(
            "transport" to transport,
            "ssid" to if (transport == "wifi") currentSsid() else null,
            "generation" to if (transport == "cellular") cellularGeneration() else null,
            "granted" to missingPermissions().isEmpty(),
        )
    }

    // getConnectionInfo() is deprecated from API 31 on, but its replacement
    // (NetworkCapabilities.getTransportInfo) needs a registered network
    // callback to reach the same SSID, and this path still works on every
    // supported release. Without the location / nearby-devices permission the
    // system hands back "<unknown ssid>" instead of throwing.
    @Suppress("DEPRECATION")
    private fun currentSsid(): String? = try {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val raw = wifi?.connectionInfo?.ssid?.trim('"')?.trim()
        if (raw.isNullOrEmpty() || raw.equals(UNKNOWN_SSID, ignoreCase = true)) null else raw
    } catch (_: SecurityException) {
        null
    }

    private fun cellularGeneration(): String? = try {
        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        if (telephony == null) {
            null
        } else if (isFiveGOverride()) {
            // 5G non-standalone rides on an LTE data connection, so the data
            // network type still reports LTE while the phone shows "5G".
            "5G"
        } else {
            generationOf(telephony.dataNetworkType)
        }
    } catch (_: SecurityException) {
        null
    }

    @Suppress("DEPRECATION")
    private fun generationOf(networkType: Int): String? = when (networkType) {
        TelephonyManager.NETWORK_TYPE_GPRS,
        TelephonyManager.NETWORK_TYPE_EDGE,
        TelephonyManager.NETWORK_TYPE_CDMA,
        TelephonyManager.NETWORK_TYPE_1xRTT,
        TelephonyManager.NETWORK_TYPE_IDEN,
        TelephonyManager.NETWORK_TYPE_GSM -> "2G"

        TelephonyManager.NETWORK_TYPE_UMTS,
        TelephonyManager.NETWORK_TYPE_EVDO_0,
        TelephonyManager.NETWORK_TYPE_EVDO_A,
        TelephonyManager.NETWORK_TYPE_EVDO_B,
        TelephonyManager.NETWORK_TYPE_HSDPA,
        TelephonyManager.NETWORK_TYPE_HSUPA,
        TelephonyManager.NETWORK_TYPE_HSPA,
        TelephonyManager.NETWORK_TYPE_HSPAP,
        TelephonyManager.NETWORK_TYPE_EHRPD,
        TelephonyManager.NETWORK_TYPE_TD_SCDMA -> "3G"

        TelephonyManager.NETWORK_TYPE_LTE,
        TelephonyManager.NETWORK_TYPE_IWLAN -> "4G"

        TelephonyManager.NETWORK_TYPE_NR -> "5G"

        else -> null
    }

    private fun isFiveGOverride(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return displayOverride >= TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_NR_NSA
    }

    private fun startDisplayInfoListener() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        if (displayInfoCallback != null) return
        if (checkSelfPermission(Manifest.permission.READ_PHONE_STATE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        try {
            val telephony =
                getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return
            val callback = DisplayInfoCallback()
            telephony.registerTelephonyCallback(mainExecutor, callback)
            displayInfoCallback = callback
        } catch (_: SecurityException) {
        }
    }

    private fun stopDisplayInfoListener() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val callback = displayInfoCallback as? TelephonyCallback ?: return
        displayInfoCallback = null
        try {
            val telephony =
                getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return
            telephony.unregisterTelephonyCallback(callback)
        } catch (_: SecurityException) {
        }
    }

    private fun requiredPermissions(): List<String> = buildList {
        add(Manifest.permission.READ_PHONE_STATE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            add(Manifest.permission.NEARBY_WIFI_DEVICES)
        } else {
            add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun missingPermissions(): List<String> = requiredPermissions().filter {
        checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
    }

    private fun requestNetworkPermissions(result: MethodChannel.Result) {
        val missing = missingPermissions()
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        if (pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST_CODE) return
        val result = pendingPermission
        pendingPermission = null
        startDisplayInfoListener()
        result?.success(missingPermissions().isEmpty())
    }

    private inner class DisplayInfoCallback :
        TelephonyCallback(), TelephonyCallback.DisplayInfoListener {
        override fun onDisplayInfoChanged(telephonyDisplayInfo: TelephonyDisplayInfo) {
            displayOverride = telephonyDisplayInfo.overrideNetworkType
        }
    }

    private companion object {
        const val CHANNEL = "luma/network_details"
        const val PERMISSION_REQUEST_CODE = 4711
        const val UNKNOWN_SSID = "<unknown ssid>"
    }
}
