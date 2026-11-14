#!/bin/bash
set -e
cd /e/UotanToolbox/build_tools/mods
BT='E:\UotanToolbox\build_tools'
BTLS="$BT\build-tools\android-14"
AJ="$BT\platform\android-34\android.jar"
JDK='E:/UotanToolbox/build_tools/jdk/jdk-17.0.2/bin'
export MSYS2_ARG_CONV_EXCL='*'
export JAVA_HOME='E:\UotanToolbox\build_tools\jdk\jdk-17.0.2'
export PATH="/e/UotanToolbox/build_tools/jdk/jdk-17.0.2/bin:$PATH"

rm -rf dex base.apk NoCell.apk classes.dex
mkdir -p dex

cmd /c "$BTLS\d8.bat --lib $AJ --min-api 24 --output dex out\com\yg\nocell\*.class"
echo "D8 OK"

cmd /c "$BTLS\aapt2.exe link -o base.apk -I $AJ --manifest AndroidManifest.xml --min-sdk-version 24 --target-sdk-version 34 -A assets"
echo "AAPT2 OK"

cp dex/classes.dex classes.dex
"$JDK/jar.exe" uf base.apk classes.dex
echo "JAR OK"

cmd /c "$BTLS\apksigner.bat sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android --out NoCell.apk base.apk"
echo "SIGN OK"

ls -l NoCell.apk
