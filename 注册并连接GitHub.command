#!/bin/zsh
set -e
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
clear

printf '\n第一步：注册或登录 GitHub\n\n'
printf '浏览器即将打开 GitHub 注册页面。\n'
printf '请使用自己的邮箱注册，密码只在浏览器中输入，不要发到对话里。\n\n'
open 'https://github.com/signup'

printf '完成邮箱验证并登录 GitHub 后，回到这个终端。\n'
read -r '?按回车继续……'

printf '\n第二步：授权这台 Mac\n\n'
printf '终端会显示一个设备代码，请按提示在浏览器中粘贴。\n'
read -r '?准备好后按回车继续……'

gh auth login --hostname github.com --git-protocol https --web

printf '\n第三步：自动上传项目\n\n'
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
printf '\n成功，项目已上传：%s\n' "$REPO_URL"
printf '云端编译页面：%s/actions\n' "$REPO_URL"
printf '\n请回到 Codex 告诉我“GitHub 已连接”。\n'
read -r '?按回车键关闭窗口……'
