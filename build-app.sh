#!/bin/bash
# ============================================
# 减脂助手 - 一键构建 & 生成 .app
# 每次修改代码后运行: ./build-app.sh
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/FatLossTracker.app"

echo "🔨 编译中..."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BINARY="$BIN_DIR/FatLossTracker"

echo "📦 生成 .app 包..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BINARY" "$APP_DIR/Contents/MacOS/FatLossTracker"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/FatLossTracker"
codesign --force --deep --sign - "$APP_DIR"

echo "✅ 完成！App 位置: $APP_DIR"
if [ -t 0 ]; then
    echo ""
    echo "💡 可以拖到桌面或应用程序文件夹"
    echo "🚀 要启动吗？输入 y"
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        open "$APP_DIR"
    fi
fi
