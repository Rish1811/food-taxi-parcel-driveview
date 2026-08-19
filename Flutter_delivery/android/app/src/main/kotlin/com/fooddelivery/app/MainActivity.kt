package com.k9bharat.delivery

import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app.fooddelivery/unlock"
    private val ONLINE_CHANNEL = "app.fooddelivery/rider_online"
    private val READINESS_CHANNEL = "app.fooddelivery/device_readiness"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "unlockScreen") {
                unlockScreen()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, READINESS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "manufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> {
                        result.success(requestIgnoreBatteryOptimizations())
                    }
                    "hasAutoStartSettings" -> result.success(resolveAutoStartIntent() != null)
                    "openAutoStartSettings" -> result.success(openAutoStartSettings())
                    "openAppSettings" -> {
                        startActivitySafely(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            )
                        )
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ONLINE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Failures are reported rather than thrown: going online must
                    // not be blocked by the service. A rider whose OEM refuses the
                    // foreground service still needs to take orders — they just
                    // lose the keep-alive guarantee.
                    "start" -> {
                        try {
                            RiderOnlineService.start(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        try {
                            RiderOnlineService.stop(applicationContext)
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Whether the OS has been told to stop dozing this app.
     *
     * Without the exemption Android puts the process into Doze when the screen has
     * been off for a while and defers our work regardless of the foreground
     * service, which is how riders "went online" and then quietly stopped being
     * offered orders overnight.
     */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (isIgnoringBatteryOptimizations()) return true

        // The direct-request dialog is the one-tap path, but Play policy makes it
        // available only to apps that justify it, and some ROMs remove it outright.
        // Fall back to the battery-optimisation list, then to app details, so the
        // button always lands the rider somewhere useful instead of doing nothing.
        val direct = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName"),
        )
        if (startActivitySafely(direct)) return true
        if (startActivitySafely(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))) return true
        return startActivitySafely(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            )
        )
    }

    /**
     * The OEM "autostart" / "background run" screen, which is a separate thing from
     * battery optimisation and is the single biggest reason a foreground service
     * still gets killed on Xiaomi, Oppo, Vivo, Realme and Huawei.
     *
     * There is no public API for it. These component names are the documented-by-
     * community paths per vendor, and they move between ROM versions — hence
     * resolving before launching, and reporting honestly when none exists so the UI
     * can hide the step rather than offering a button that does nothing.
     */
    private fun resolveAutoStartIntent(): Intent? {
        val candidates = listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.letv.android.letvsafe" to "com.letv.android.letvsafe.AutobootManageActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.asus.mobilemanager" to "com.asus.mobilemanager.entry.FunctionActivity",
            "com.samsung.android.lool" to "com.samsung.android.sm.ui.battery.BatteryActivity",
        )

        for ((pkg, cls) in candidates) {
            val intent = Intent().setComponent(ComponentName(pkg, cls))
            if (packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) != null) {
                return intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
        return null
    }

    private fun openAutoStartSettings(): Boolean {
        val intent = resolveAutoStartIntent() ?: return false
        return startActivitySafely(intent)
    }

    /**
     * Settings screens vary wildly by ROM and some throw on launch even after
     * resolving. Never let that take the app down — the caller reports failure and
     * the UI tells the rider to find the setting manually.
     */
    private fun startActivitySafely(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun unlockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or 
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }
}
