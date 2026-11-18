#!/bin/bash
# Устанавливает службу управления вентилятором и приложение.
set -e
if [ "$EUID" -ne 0 ]; then echo "Запусти так:  sudo ./install.sh"; exit 1; fi
cd "$(dirname "$0")"
[ -f build/minifand ] || { echo "Сначала выполни ./build.sh"; exit 1; }

PLIST=/Library/LaunchDaemons/com.minifan.daemon.plist
SUP="/Library/Application Support/MiniFan"
launchctl unload "$PLIST" 2>/dev/null || true

mkdir -p /usr/local/libexec "$SUP"
install -m 755 -o root -g wheel build/minifand /usr/local/libexec/minifand
chown root:admin "$SUP"; chmod 775 "$SUP"
if [ ! -f "$SUP/config.json" ]; then cp default-config.json "$SUP/config.json"; fi
chown root:admin "$SUP/config.json"; chmod 664 "$SUP/config.json"

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.minifan.daemon</string>
<key>ProgramArguments</key><array><string>/usr/local/libexec/minifand</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>StandardOutPath</key><string>/var/log/minifan.log</string>
<key>StandardErrorPath</key><string>/var/log/minifan.log</string>
</dict></plist>
PL
chown root:wheel "$PLIST"; chmod 644 "$PLIST"
launchctl load -w "$PLIST"

rm -rf /Applications/MiniFan.app
ditto build/MiniFan.app /Applications/MiniFan.app
echo "✓ Установлено. Открой MiniFan из Программ (или: open -a MiniFan)."
echo "  Лог службы: /var/log/minifan.log"
