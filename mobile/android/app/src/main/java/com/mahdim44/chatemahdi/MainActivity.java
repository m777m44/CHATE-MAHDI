package com.mahdim44.chatemahdi;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.widget.Toast;

import androidx.core.content.FileProvider;

import java.io.File;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/**
 * MainActivity hosts a private MethodChannel used by the in-app updater.
 *
 * Steps performed natively (Android 8+ requires explicit consent to install
 * packages that did not come from a store):
 *  1. canRequestPackageInstalls() -> canInstall()
 *  2. ACTION_MANAGE_UNKNOWN_APP_SOURCES -> requestInstallPermission()
 *  3. FileProvider Uri + ACTION_VIEW (package-archive installer) -> installApk()
 *
 * Installing through the system installer (never silently) is what lets the
 * update replace the current app while keeping all user data.
 */
public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.mahdim44.chatemahdi/install";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "canInstall":
                            result.success(canRequestInstall());
                            break;
                        case "requestInstallPermission":
                            requestInstallPermission();
                            result.success(true);
                            break;
                        case "installApk":
                            String path = call.argument("path");
                            installApk(path, result);
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    private boolean canRequestInstall() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return getPackageManager().canRequestPackageInstalls();
        }
        return true;
    }

    private void requestInstallPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Uri packageUri = Uri.parse("package:" + getPackageName());
            Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, packageUri);
            startActivity(intent);
        }
    }

    private void installApk(String path, MethodChannel.Result result) {
        try {
            File apkFile = new File(path);
            if (!apkFile.exists() || apkFile.length() == 0) {
                result.error("APK_INVALID", "Downloaded APK is missing or empty", null);
                return;
            }
            Uri apkUri = FileProvider.getUriForFile(
                    this, getPackageName() + ".fileprovider", apkFile);
            Intent install = new Intent(Intent.ACTION_VIEW);
            install.setDataAndType(apkUri, "application/vnd.android.package-archive");
            install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            install.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(install);
            result.success(true);
        } catch (Exception e) {
            result.error("INSTALL_FAILED", e.getMessage(), null);
        }
    }
}
