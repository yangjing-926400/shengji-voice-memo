#!/bin/zsh
set -e
export PATH="$HOME/.local/bin:$PATH"
clear
printf '\n声记 PWA 固定部署：连接 GitHub\n\n'
printf '接下来会自动打开浏览器。\n'
printf '请登录你的 GitHub 账号，并在浏览器中输入终端显示的设备代码。\n'
printf '不要把设备代码发送到对话里。\n\n'
gh auth login --hostname github.com --git-protocol https --web
printf '\nGitHub 登录完成。请回到 Codex 告诉我“GitHub 已连接”。\n'
read -r '?按回车键关闭窗口……'
