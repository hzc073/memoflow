#!/usr/bin/env bash
set -euo pipefail

EXPECTED_BUNDLE_ID="${EXPECTED_BUNDLE_ID:-com.memoflow.hzc073}"
EXPECTED_KEYCHAIN_SERVICE="${EXPECTED_KEYCHAIN_SERVICE:-com.memoflow.hzc073.secure.production}"
LEGACY_KEYCHAIN_SERVICE="${LEGACY_KEYCHAIN_SERVICE:-flutter_secure_storage_service}"
DEFAULT_APP="/Users/mr.han/Library/Caches/memoflow-main-flutter-build/macos/Build/Products/Release-Runner/MemoFlow.app"
APP_PATH="${1:-$DEFAULT_APP}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
  printf '失败: %s\n' "$*" >&2
  exit 1
}

ok() {
  printf 'OK: %s\n' "$*"
}

warn() {
  printf '提醒: %s\n' "$*" >&2
}

require_executable() {
  local tool="$1"
  if [[ ! -x "$tool" ]]; then
    fail "找不到工具: $tool"
  fi
}

require_executable /usr/libexec/PlistBuddy
require_executable /usr/bin/codesign
require_executable /usr/bin/grep

if [[ ! -d "$APP_PATH" ]]; then
  fail "找不到 App: $APP_PATH"
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  fail "找不到 Info.plist: $INFO_PLIST"
fi

printf '检查 App: %s\n' "$APP_PATH"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
if [[ "$BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  fail "Bundle ID 不对。期望 ${EXPECTED_BUNDLE_ID}，实际 ${BUNDLE_ID}"
fi
ok "Bundle ID = $BUNDLE_ID"

if ! /usr/bin/grep -R -a -q -- "$EXPECTED_KEYCHAIN_SERVICE" "$APP_PATH"; then
  fail "没有在 App 中找到生产 Keychain service: $EXPECTED_KEYCHAIN_SERVICE"
fi
ok "已找到生产 Keychain service: $EXPECTED_KEYCHAIN_SERVICE"

if /usr/bin/grep -R -q -- "$LEGACY_KEYCHAIN_SERVICE" "$APP_ROOT/lib"; then
  fail "runtime 源码中仍引用旧 Keychain service: $LEGACY_KEYCHAIN_SERVICE"
fi
ok "runtime 源码未引用旧 Keychain service: $LEGACY_KEYCHAIN_SERVICE"

if /usr/bin/grep -R -a -q -- "$LEGACY_KEYCHAIN_SERVICE" "$APP_PATH"; then
  warn "打包后的二进制里包含旧 service 字符串。"
  warn "这通常来自 flutter_secure_storage 依赖包内置的默认常量；只要 runtime 源码未引用旧 service，且已找到生产 service，就不会按旧 service 读写。"
else
  ok "打包后的二进制中未发现旧 Keychain service 字符串"
fi

CODESIGN_DETAILS="$(/usr/bin/codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)"
IS_DEVELOPER_ID_SIGNED=false
if printf '%s\n' "$CODESIGN_DETAILS" | /usr/bin/grep -q '^Authority=Developer ID Application:' &&
  printf '%s\n' "$CODESIGN_DETAILS" | /usr/bin/grep -Eq '^TeamIdentifier=[A-Z0-9]+$'; then
  IS_DEVELOPER_ID_SIGNED=true
fi

ENTITLEMENTS="$(/usr/bin/codesign -d --entitlements :- "$APP_PATH" 2>&1 || true)"
if printf '%s\n' "$ENTITLEMENTS" | /usr/bin/grep -q 'com.apple.security.get-task-allow'; then
  if [[ "$IS_DEVELOPER_ID_SIGNED" == "true" ]]; then
    fail "Developer ID 签名后的 App 带有 debug entitlement: com.apple.security.get-task-allow"
  fi
  warn "当前 App 带有 get-task-allow，但它还不是 Developer ID 签名。"
  warn "请继续完成 App 签名；签名后脚本会再次检查并要求该 entitlement 消失。"
else
  ok "未发现 get-task-allow debug entitlement"
fi

if [[ "$IS_DEVELOPER_ID_SIGNED" == "true" ]]; then
  ok "App 已使用 Developer ID Application 签名"
  /usr/bin/codesign --verify --deep --strict --verbose=4 "$APP_PATH"
  ok "codesign verify 通过"
  printf '\n可以打开这个已签名 App 做启动预检:\n'
  printf '  open "%s"\n' "$APP_PATH"
else
  warn "当前 App 还不是 Developer ID Application 签名。"
  warn "如果你是在第 2 步编译后运行，这是正常的；不要直接打开这个未正式签名的 production build。"
  warn "请先完成第 4 步签名，然后再运行:"
  printf '  %s "%s"\n' "$0" "$HOME/Desktop/MemoFlow.app"
fi

printf '\n预检查完成。\n'
