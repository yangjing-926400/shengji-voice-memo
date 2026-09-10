#!/bin/zsh
set -e
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
clear
printf '\n声记云构建：连接 GitHub\n\n'
printf '接下来会打开浏览器。请登录或免费注册 GitHub，并输入终端显示的设备代码。\n'
printf '不要把密码或设备代码发送到对话里。\n\n'
if ! gh auth status >/dev/null 2>&1; then
  gh auth login --hostname github.com --git-protocol https --web
fi

git add .
git commit -m "Update Shengji app" >/dev/null 2>&1 || true

REPO_NAME="shengji-voice-memo"
if git remote get-url origin >/dev/null 2>&1; then
  git push -u origin main
else
  if gh repo view "$REPO_NAME" >/dev/null 2>&1; then
    REPO_NAME="shengji-voice-memo-$(date +%s)"
  fi
  gh repo create "$REPO_NAME" --public --source=. --remote=origin --push
fi

REPO_URL=$(gh repo view --json url --jq .url)
printf '\n代码已上传：%s\n' "$REPO_URL"
printf '打开 Actions 页面：%s/actions\n' "$REPO_URL"
printf '\n请回到 Codex 告诉我“GitHub 已连接”。\n'
read -r '?按回车键关闭窗口……'
