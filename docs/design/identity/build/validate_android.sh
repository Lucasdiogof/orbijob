#!/usr/bin/env bash
# Validates the Android resources with the real aapt2 (apt package `aapt`) against an API 23 android.jar
# (apt package `libandroid-23-java`). This is a RESOURCE check, not an APK build: no Android SDK is available offline.
# values-v31/values-night-v31 use API 31 attributes that API 23 does not know, so they are compile-checked only.
set -euo pipefail
RES="$(cd "$(dirname "$0")/../../../../app/android/app/src/main/res" && pwd)"
JAR=/usr/lib/android-sdk/platforms/android-23/android.jar
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/res"; cp -r "$RES/." "$W/res/"; rm -rf "$W/res/values-v31" "$W/res/values-night-v31"
cat > "$W/AndroidManifest.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.lucksrei.orbijob">
  <application android:label="OrbiJob" android:icon="@mipmap/ic_launcher">
    <activity android:name=".MainActivity" android:theme="@style/LaunchTheme"/>
  </application>
</manifest>
XML
echo "== aapt2 compile (all res dirs incl. v31)"; aapt2 compile --dir "$RES" -o "$W/all.zip" && echo OK
echo "== aapt2 link (min-sdk 21, without v31 dirs)"
aapt2 compile --dir "$W/res" -o "$W/res.zip"
aapt2 link -I "$JAR" --manifest "$W/AndroidManifest.xml" --min-sdk-version 21 --target-sdk-version 23 -o "$W/out.apk" "$W/res.zip" && echo OK
echo "== resource table (icons, splash)"
aapt2 dump resources "$W/out.apk" | grep -E "mipmap/ic_launcher|drawable/(ic_launcher|splash|launch)|color/(ic_launcher|splash)|style/(Launch|Normal)" | sed 's/^ *//' | sort -u | head -40
echo "== adaptive icon xml"
aapt2 dump xmltree --file res/mipmap-anydpi-v26/ic_launcher.xml "$W/out.apk" 2>/dev/null || aapt2 dump xmltree "$W/out.apk" --file res/mipmap-anydpi-v26/ic_launcher.xml
echo "== API 31 splash attributes present in styles"
grep -h "windowSplashScreen" "$RES"/values-v31/styles.xml "$RES"/values-night-v31/styles.xml | sed 's/^ *//' | sort -u
