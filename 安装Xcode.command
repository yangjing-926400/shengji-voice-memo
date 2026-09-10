#!/bin/zsh
set -e
clear
printf '\n正在准备安装 Xcode 26.2\n\n'
printf '接下来会要求输入你的 Apple ID。\n'
printf '密码输入时不会显示字符，这是正常的。\n'
printf '如果出现双重认证验证码，请按提示输入。\n\n'
printf '不要关闭这个终端窗口，下载会显示进度并支持断点续传。\n\n'
"$HOME/.local/bin/xcodes" install 26.2 --select --experimental-unxip
printf '\nXcode 安装流程结束。请回到 Codex，把终端最后三行告诉我。\n'
read -r '?按回车键关闭窗口……'
