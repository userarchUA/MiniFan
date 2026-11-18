#!/bin/bash
# Полное удаление; вентилятор возвращается под управление системы.
if [ "$EUID" -ne 0 ]; then echo "Запусти так:  sudo ./uninstall.sh"; exit 1; fi
PLIST=/Library/LaunchDaemons/com.minifan.daemon.plist
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST" /usr/local/libexec/minifand
rm -rf /Applications/MiniFan.app
rm -f /Users/*/Library/LaunchAgents/com.minifan.app.plist
echo "Удалено. Настройки остались в /Library/Application Support/MiniFan (можно стереть вручную)."
