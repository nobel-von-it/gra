#!/bin/bash
set -e

PROJECT_NAME=$(grep '^name:' pubspec.yaml | awk '{print $2}')
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
ICON_PATH="assets/gra-icon.png"

BUILD_DIR="build/appimage"
DIST_DIR="dist"
APPDIR="$BUILD_DIR/AppDir"

echo "Сборка $PROJECT_NAME v$VERSION..."

mkdir -p "$BUILD_DIR" "$DIST_DIR"

flutter build linux --release

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/icons/hicolor/512x512/apps"

cp -r build/linux/x64/release/bundle/* "$APPDIR/usr/bin/"
cp "$ICON_PATH" "$APPDIR/usr/share/icons/hicolor/512x512/apps/${PROJECT_NAME}.png"
cp "$ICON_PATH" "$APPDIR/${PROJECT_NAME}.png"

cat > "$APPDIR/${PROJECT_NAME}.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Gra
Exec=gra
Icon=Gra
Categories=Utility;
EOF

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/gra" "$@"
EOF
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/gra"

cd "$BUILD_DIR"
for tool in linuxdeploy-x86_64.AppImage appimagetool-x86_64.AppImage; do
    if [ ! -f "$tool" ]; then
        echo "Загрузка $tool..."
        if [[ "$tool" == linuxdeploy* ]]; then
            wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
        else
            wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
        fi
        chmod +x "$tool"
    fi
done

echo "Раскладка зависимостей..."
./linuxdeploy-x86_64.AppImage --appdir AppDir --output none 2>&1 | grep -v "ERROR" || true

echo "Создание AppImage..."
ARCH=x86_64 ./appimagetool-x86_64.AppImage AppDir "${PROJECT_NAME}-${VERSION}-x86_64.AppImage"

mv "${PROJECT_NAME}-${VERSION}-x86_64.AppImage" "../../$DIST_DIR/"
cd ../..

echo ""
echo "Готово: $DIST_DIR/${PROJECT_NAME}-${VERSION}-x86_64.AppImage"
