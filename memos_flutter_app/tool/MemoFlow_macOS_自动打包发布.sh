#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/Users/mr.han/Desktop/memoflow-main/memos_flutter_app"
DESKTOP_DIR="${HOME}/Desktop"
DESKTOP_APP="${DESKTOP_DIR}/MemoFlow.app"
DMG_STAGING="${DESKTOP_DIR}/MemoFlow-dmg"
DMG_PATH="${DESKTOP_DIR}/MemoFlow.dmg"
PRECHECK_SCRIPT="${APP_ROOT}/tool/preflight_macos_production_app.sh"
DMG_VALIDATE_SCRIPT="${APP_ROOT}/tool/validate_macos_dmg.sh"
ENTITLEMENTS="${APP_ROOT}/macos/Runner/Release.entitlements"
NOTARY_PROFILE="${NOTARY_PROFILE:-memoflow-notary}"

fail() {
  printf '\n失败: %s\n' "$*" >&2
  exit 1
}

step() {
  printf '\n==> %s\n' "$*"
}

ok() {
  printf 'OK: %s\n' "$*"
}

require_tool() {
  local tool="$1"
  if [[ "$tool" == /* ]]; then
    [[ -x "$tool" ]] || fail "找不到工具: $tool"
  elif ! command -v "$tool" >/dev/null 2>&1; then
    fail "找不到工具: $tool"
  fi
}

find_built_app() {
  local candidates=(
    "${APP_ROOT}/build/macos/Build/Products/Release-Runner/MemoFlow.app"
    "${APP_ROOT}/build/macos/Build/Products/Release/MemoFlow.app"
    "${HOME}/Library/Caches/memoflow-main-flutter-build/macos/Build/Products/Release-Runner/MemoFlow.app"
    "${HOME}/Library/Caches/memoflow-main-flutter-build/macos/Build/Products/Release/MemoFlow.app"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

step "检查本机工具"
require_tool flutter
require_tool security
require_tool /usr/bin/codesign
require_tool /usr/bin/ditto
require_tool /usr/bin/xattr
require_tool /usr/bin/hdiutil
require_tool /usr/bin/xcrun
require_tool /usr/sbin/spctl
require_tool /usr/libexec/PlistBuddy
require_tool /usr/bin/grep
require_tool /usr/bin/awk
require_tool /usr/bin/find

[[ -d "$APP_ROOT" ]] || fail "找不到项目目录: $APP_ROOT"
[[ -f "$ENTITLEMENTS" ]] || fail "找不到 entitlements: $ENTITLEMENTS"
[[ -x "$PRECHECK_SCRIPT" ]] || fail "找不到预检查脚本: $PRECHECK_SCRIPT"
[[ -x "$DMG_VALIDATE_SCRIPT" ]] || fail "找不到 DMG 验收脚本: $DMG_VALIDATE_SCRIPT"
ok "工具检查完成"

step "读取 Developer ID Application 证书"
CERT_SHA1="$(security find-identity -v -p codesigning | /usr/bin/awk '/Developer ID Application/ {print $2; exit}')"
[[ -n "$CERT_SHA1" ]] || fail "未找到 Developer ID Application 证书"
security find-identity -v -p codesigning | /usr/bin/grep "$CERT_SHA1"

step "编译 production macOS App"
cd "$APP_ROOT"
flutter clean
flutter pub get
flutter build macos --release --flavor Runner \
  --dart-define=MEMOFLOW_MACOS_DISTRIBUTION_CHANNEL=production

BUILT_APP="$(find_built_app)" || fail "编译后没有找到 MemoFlow.app"
ok "构建产物: $BUILT_APP"

step "编译产物预检查"
"$PRECHECK_SCRIPT" "$BUILT_APP"

step "重建桌面 App 和 DMG 工作目录"
rm -rf "$DESKTOP_APP"
rm -rf "$DMG_STAGING"
rm -f "$DMG_PATH"
/usr/bin/ditto --norsrc "$BUILT_APP" "$DESKTOP_APP"
/usr/bin/xattr -cr "$DESKTOP_APP"
[[ -d "$DESKTOP_APP" ]] || fail "桌面 App 拷贝失败: $DESKTOP_APP"
ok "桌面 App 已准备好"

step "给 App 签名"
printf '如果系统弹出钥匙串授权，请输入你的 Mac 登录密码并允许。\n'
/usr/bin/codesign --force --deep --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$CERT_SHA1" \
  "$DESKTOP_APP"
/usr/bin/codesign --verify --deep --strict --verbose=4 "$DESKTOP_APP"
"$PRECHECK_SCRIPT" "$DESKTOP_APP"
ok "App 签名检查完成"

step "制作 DMG"
mkdir -p "$DMG_STAGING"
/usr/bin/ditto --norsrc "$DESKTOP_APP" "$DMG_STAGING/MemoFlow.app"
ln -s /Applications "$DMG_STAGING/Applications"
/usr/bin/hdiutil create \
  -volname "MemoFlow" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
[[ -f "$DMG_PATH" ]] || fail "DMG 创建失败: $DMG_PATH"
ok "DMG 已创建: $DMG_PATH"

step "给 DMG 签名"
printf '如果系统弹出钥匙串授权，请输入你的 Mac 登录密码并允许。\n'
/usr/bin/codesign --force --timestamp \
  --sign "$CERT_SHA1" \
  "$DMG_PATH"
/usr/bin/codesign --verify --verbose=4 "$DMG_PATH"
ok "DMG 签名检查完成"

step "提交 DMG 公证"
printf '使用钥匙串公证配置: %s\n' "$NOTARY_PROFILE"
printf '如果系统弹出钥匙串授权，请输入你的 Mac 登录密码并允许。\n'
/usr/bin/xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

step "装订并验证公证票据"
/usr/bin/xcrun stapler staple "$DMG_PATH"
/usr/bin/xcrun stapler validate "$DMG_PATH"
ok "stapler 检查完成"

step "最终 DMG 验收"
"$DMG_VALIDATE_SCRIPT" "$DMG_PATH"

printf '\n全部完成。\n'
printf '最终 DMG: %s\n' "$DMG_PATH"
