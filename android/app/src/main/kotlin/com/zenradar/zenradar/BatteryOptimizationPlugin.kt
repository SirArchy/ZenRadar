package com.zenradar.zenradar

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.content.ComponentName
import android.app.AlarmManager
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class BatteryOptimizationPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "battery_optimization")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "isIgnoringBatteryOptimizations" -> {
                result.success(isIgnoringBatteryOptimizations())
            }
            "requestIgnoreBatteryOptimizations" -> {
                requestIgnoreBatteryOptimizations()
                result.success(null)
            }
            "canScheduleExactAlarms" -> {
                result.success(canScheduleExactAlarms())
            }
            "requestExactAlarmPermission" -> {
                requestExactAlarmPermission()
                result.success(null)
            }
            "getManufacturer" -> {
                result.success(Build.MANUFACTURER)
            }
            "openBatteryOptimizationSettings" -> {
                openBatteryOptimizationSettings()
                result.success(null)
            }
            "openManufacturerSpecificSettings" -> {
                openManufacturerSpecificSettings()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            true
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent().apply {
                    action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            } catch (e: Exception) {
                // Fallback to general battery optimization settings
                openBatteryOptimizationSettings()
            }
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent().apply {
                    action = Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            } catch (e: Exception) {
                // Fallback to general alarm settings
                openGeneralSettings()
            }
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent().apply {
                action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            openGeneralSettings()
        }
    }

    private fun openManufacturerSpecificSettings() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        
        when {
            manufacturer.contains("xiaomi") -> openXiaomiSettings()
            manufacturer.contains("huawei") -> openHuaweiSettings()
            manufacturer.contains("samsung") -> openSamsungSettings()
            manufacturer.contains("oppo") -> openOppoSettings()
            manufacturer.contains("vivo") -> openVivoSettings()
            manufacturer.contains("oneplus") -> openOnePlusSettings()
            manufacturer.contains("motorola") -> openMotorolaSettings()
            else -> openBatteryOptimizationSettings()
        }
    }

    private fun openXiaomiSettings() {
        val intents = listOf(
            // MIUI Auto-start management
            Intent().apply {
                component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
            },
            // MIUI Power settings
            Intent().apply {
                component = ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
            },
            // Alternative MIUI settings
            Intent().apply {
                component = ComponentName("com.miui.securitycenter", "com.miui.powercenter.PowerSettings")
            }
        )
        
        tryOpenIntents(intents)
    }

    private fun openHuaweiSettings() {
        val intents = listOf(
            // Huawei Protected Apps
            Intent().apply {
                component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
            },
            // Huawei Battery optimization
            Intent().apply {
                component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
            },
            // Honor settings
            Intent().apply {
                component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity")
            }
        )
        
        tryOpenIntents(intents)
    }

    private fun openSamsungSettings() {
        val intents = listOf(
            // Samsung Device Care
            Intent().apply {
                component = ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")
            },
            // Samsung Smart Manager
            Intent().apply {
                component = ComponentName("com.samsung.android.sm_cn", "com.samsung.android.sm.ui.ram.AutoRunActivity")
            },
            // Alternative Samsung settings
            Intent().apply {
                component = ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity")
            }
        )
        
        tryOpenIntents(intents)
    }

    private fun openOppoSettings() {
        val intents = listOf(
            // OPPO Auto-start management
            Intent().apply {
                component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.FakeActivity")
            },
            // OPPO Battery optimization
            Intent().apply {
                component = ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")
            }
        )
        
        tryOpenIntents(intents)
    }

    private fun openVivoSettings() {
        val intents = listOf(
            // Vivo Auto-start management
            Intent().apply {
                component = ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
            },
            // Vivo iManager
            Intent().apply {
                component = ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")
            }
        )
        
        tryOpenIntents(intents)
    }

    private fun openOnePlusSettings() {
        val intents = listOf(
            // OnePlus Battery optimization
            Intent().apply {
                component = ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")
            },
            // OnePlus Auto-start management
            Intent().apply {
                component = ComponentName("com.oplus.battery", "com.oplus.battery.optimize.BatteryOptimizeActivity")
            }
        )
        
        tryOpenIntents(intents)
    }

    private fun openMotorolaSettings() {
        val intents = listOf(
            // Motorola Battery optimization
            Intent().apply {
                component = ComponentName("com.motorola.android.settings", "com.motorola.android.settings.battery.BatteryOptimizationSettings")
            }
        )
        
        tryOpenIntents(intents)
    }

    private fun tryOpenIntents(intents: List<Intent>) {
        for (intent in intents) {
            try {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
                return // Successfully opened
            } catch (e: Exception) {
                // Continue to next intent
            }
        }
        
        // If all manufacturer-specific intents fail, fallback to general settings
        openBatteryOptimizationSettings()
    }

    private fun openGeneralSettings() {
        try {
            val intent = Intent().apply {
                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                data = Uri.parse("package:${context.packageName}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            // Last resort - open main settings
            val intent = Intent().apply {
                action = Settings.ACTION_SETTINGS
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
