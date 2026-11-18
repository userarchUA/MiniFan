#!/bin/bash
# Сборка MiniFan (приложение + служба). Нужны Command Line Tools: xcode-select --install
set -e
cd "$(dirname "$0")"
if ! command -v swiftc >/dev/null 2>&1; then
  echo "Не найден swiftc. Установи инструменты разработчика:  xcode-select --install"; exit 1
fi
TARGET="x86_64-apple-macosx10.15"
rm -rf build; mkdir -p build

echo "▸ SMC (C)…"
clang -O2 -std=gnu11 -target $TARGET -c src/smc.c -o build/smc.o

echo "▸ служба minifand…"
swiftc -O -target $TARGET -import-objc-header src/smc.h -framework IOKit \
  src/Shared.swift daemon/main.swift build/smc.o -o build/minifand

echo "▸ приложение MiniFan…"
swiftc -O -target $TARGET -import-objc-header src/smc.h -framework IOKit \
  src/Shared.swift app/main.swift app/AppDelegate.swift app/Model.swift app/Views.swift build/smc.o \
  -o build/MiniFan

APP=build/MiniFan.app
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp build/MiniFan $APP/Contents/MacOS/MiniFan
cat > $APP/Contents/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MiniFan</string>
<key>CFBundleIdentifier</key><string>com.minifan.app</string>
<key>CFBundleName</key><string>MiniFan</string>
<key>CFBundleDisplayName</key><string>MiniFan</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>10.15</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PL

if [ -f tools/icon.png ] && command -v iconutil >/dev/null 2>&1; then
  echo "▸ иконка…"
  IS=build/AppIcon.iconset; mkdir -p $IS
  for s in 16 32 64 128 256 512; do
    sips -z $s $s tools/icon.png --out $IS/icon_${s}x${s}.png >/dev/null
    d=$((s*2)); sips -z $d $d tools/icon.png --out $IS/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns $IS -o $APP/Contents/Resources/AppIcon.icns || true
fi
codesign --force -s - $APP >/dev/null 2>&1 || true
echo "✓ Готово: build/MiniFan.app и build/minifand"
echo "  Дальше:  sudo ./install.sh"
