#!/bin/zsh
set -e
cd "$(dirname "$0")"
TARGET_URL="${1:-}"
OUTPUT="${2:-声记.shortcut}"
if [[ -z "$TARGET_URL" ]]; then
  echo "用法: ./build.sh https://example.com/ 声记.shortcut" >&2
  exit 2
fi
NODE="/Users/mac/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
export NODE_PATH="$(pwd)/node_modules"
"$NODE" build.js "$TARGET_URL" /tmp/shengji-shortcut-unsigned.shortcut
/usr/bin/shortcuts sign --mode anyone --input /tmp/shengji-shortcut-unsigned.shortcut --output "$OUTPUT"
echo "已生成: $(pwd)/$OUTPUT"
