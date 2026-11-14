package com.yg.nocell;

import android.net.wifi.ScanResult;
import android.net.wifi.WifiManager;
import android.telephony.CellInfo;
import android.telephony.TelephonyManager;

import java.util.ArrayList;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XC_MethodReplacement;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage.LoadPackageParam;

public class Hook implements IXposedHookLoadPackage {

    private static final String TAG = "NoCell >> ";
    private static final double LAT = 39.90291980847999;
    private static final double LNG = 116.39380286659247;

    @Override
    public void handleLoadPackage(LoadPackageParam lp) {
        if (!"com.tencent.mm".equals(lp.packageName)) return;

        XposedBridge.log(TAG + "attach " + lp.packageName);

        // ---------- 系统基站 / WiFi 指纹 ----------
        rep(TelephonyManager.class, "getAllCellInfo", null, new ArrayList<CellInfo>());
        rep(TelephonyManager.class, "getCellLocation", null, null);
        rep(WifiManager.class, "getScanResults", null, new ArrayList<ScanResult>());
        repStr("android.net.wifi.WifiInfo", "getBSSID", "02:00:00:00:00:00");
        repStr("android.net.wifi.WifiInfo", "getSSID", "<unknown ssid>");
        repStr("android.net.wifi.WifiInfo", "getMacAddress", "02:00:00:00:00:00");

        // ---------- 腾讯定位 SDK ----------
        hookTencent(lp);
        probeTencent(lp);

        XposedBridge.log(TAG + "ready");
    }

    private void hookTencent(LoadPackageParam lp) {
        String[] names = {
                "com.tencent.map.geolocation.sapp.TencentLocation",
                "com.tencent.map.geolocation.sapp.TencentLocationImpl",
                "com.tencent.map.geolocation.sapp.TencentLocation_sapp"
        };
        for (String cn : names) {
            Class<?> c;
            try {
                c = Class.forName(cn, false, lp.classLoader);
            } catch (Throwable t) {
                XposedBridge.log(TAG + "no class " + cn);
                continue;
            }
            all(c, "getLatitude", LAT);
            all(c, "getLongitude", LNG);
            all(c, "getAccuracy", 3f);
            all(c, "getAltitude", 44d);
            all(c, "getSpeed", 0f);
            all(c, "getBearing", 0f);
            all(c, "getCity", "北京市");
            all(c, "getProvince", "北京市");
            all(c, "getDistrict", "东城区");
            all(c, "getStreet", "东长安街");
            all(c, "getAddress", "北京市东城区东长安街天安门");
            all(c, "getName", "天安门");
            all(c, "getProvider", "gps");
            XposedBridge.log(TAG + "spoofed " + cn);
        }
    }

    private void probeTencent(LoadPackageParam lp) {
        String[] mgrs = {
                "com.tencent.map.geolocation.sapp.TencentLocationManager",
                "com.tencent.map.geolocation.sapp.TencentLocationUtils"
        };
        for (String cn : mgrs) {
            try {
                Class<?> c = Class.forName(cn, false, lp.classLoader);
                int n = 0;
                for (final java.lang.reflect.Method m : c.getDeclaredMethods()) {
                    try {
                        XposedBridge.hookMethod(m, new XC_MethodHook() {
                            @Override
                            protected void beforeHookedMethod(MethodHookParam p) {
                                StringBuilder sb = new StringBuilder("CALL " + m.getName() + " args:");
                                for (Object a : p.args) {
                                    sb.append(" [").append(a == null ? "null" : a.getClass().getName()).append("]");
                                }
                                XposedBridge.log(TAG + sb.toString());
                            }
                        });
                        n++;
                    } catch (Throwable ignored) {
                    }
                }
                XposedBridge.log(TAG + "probe " + cn + " methods=" + c.getDeclaredMethods().length + " hooked=" + n);
            } catch (Throwable t) {
                XposedBridge.log(TAG + "probe miss " + cn);
            }
        }
    }

    private void all(Class<?> c, String method, final Object value) {
        try {
            XposedBridge.hookAllMethods(c, method, new XC_MethodReplacement() {
                @Override
                protected Object replaceHookedMethod(MethodHookParam param) {
                    return value;
                }
            });
        } catch (Throwable ignored) {
        }
    }

    private void rep(Class<?> cls, String method, Class<?>[] params, Object result) {
        try {
            XC_MethodHook cb = new XC_MethodReplacement() {
                @Override
                protected Object replaceHookedMethod(MethodHookParam param) {
                    return result;
                }
            };
            if (params == null || params.length == 0) {
                XposedHelpers.findAndHookMethod(cls, method, cb);
            } else {
                Object[] args = new Object[params.length + 1];
                System.arraycopy(params, 0, args, 0, params.length);
                args[params.length] = cb;
                XposedHelpers.findAndHookMethod(cls, method, args);
            }
            XposedBridge.log(TAG + "hooked " + cls.getSimpleName() + "." + method);
        } catch (Throwable t) {
            XposedBridge.log(TAG + "skip " + cls.getSimpleName() + "." + method);
        }
    }

    private void repStr(String clsName, String method, final String value) {
        try {
            Class<?> cls = Class.forName(clsName);
            XposedHelpers.findAndHookMethod(cls, method, new XC_MethodReplacement() {
                @Override
                protected Object replaceHookedMethod(MethodHookParam param) {
                    return value;
                }
            });
            XposedBridge.log(TAG + "hooked " + clsName + "." + method);
        } catch (Throwable t) {
            XposedBridge.log(TAG + "skip " + clsName + "." + method);
        }
    }
}
