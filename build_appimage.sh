#!/bin/bash
set -e

PROJECT_NAME="gra"
VERSION="0.1.0"
ICON_PATH="assets/gra-icon.png"

echo "- Сборка $PROJECT_NAME v$VERSION..."

flutter build linux --release

APPDIR="AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/icons/hicolor/512x512/apps"

cp -r build/linux/x64/release/bundle/* "$APPDIR/usr/bin/"

# ICON BEST PART
cp "$ICON_PATH" "$APPDIR/usr/share/icons/hicolor/512x512/apps/${PROJECT_NAME}.png"
cp "$ICON_PATH" "$APPDIR/${PROJECT_NAME}.png"

cat > "$APPDIR/${PROJECT_NAME}.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Gra
Exec=gra
Icon=gra
Categories=Utility;
EOF

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/gra" "$@"
EOF
chmod +x "$APPDIR/AppRun"
chmod +x "$APPDIR/usr/bin/gra"

for tool in linuxdeploy-x86_64.AppImage appimagetool-x86_64.AppImage; do
    [ ! -f "$tool" ] && wget -q "https://github.com/$(case $tool in linuxdeploy*) echo linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage ;; *) echo AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage ;; esac)" && chmod +x "$tool"
done

./linuxdeploy-x86_64.AppImage --appdir "$APPDIR" --output none 2>&1 | grep -v "ERROR" || true

ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APPDIR" "${PROJECT_NAME}-${VERSION}-x86_64.AppImage"

echo "Готово: ./${PROJECT_NAME}-${VERSION}-x86_64.AppImage"
