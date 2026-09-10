# 声记 iOS 原生版

原生 SwiftUI 版本，不再依赖网页、Mac 后台或 HTTPS 隧道。

## 系统要求

- macOS
- Xcode 15 或更高版本
- iOS 16.0 或更高版本的 iPhone
- 免费 Apple ID 可以安装测试，但免费签名通常 7 天后失效
- 需要长期免维护安装时，使用付费 Apple Developer 账号

## 首次安装

1. 从 App Store 安装 Xcode。
2. 运行：

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   open ios/Shengji.xcodeproj
   ```

3. 在 Xcode 菜单中选择 `Settings > Accounts`，添加你的 Apple ID。
4. 选择左侧 `Shengji` 工程，再选择 `Shengji` Target。
5. 打开 `Signing & Capabilities`。
6. 勾选 `Automatically manage signing`，选择你的 Team。
7. 如果 Bundle Identifier 冲突，将它改成唯一值，例如 `com.yourname.shengji`。
8. 用数据线连接 iPhone，并在手机上信任这台电脑。
9. 在 Xcode 顶部选择你的 iPhone，然后点击 Run。

iPhone 首次运行时需要允许：

- 麦克风
- 语音识别

## 当前功能

- 原生录音和本地音频保存
- Apple Speech 中文语音转文字
- 自动归组
- 本地语音搜索
- 记录详情和录音播放
- 删除记录
- 所有数据保存在本机

## 支持范围

- 部署目标为 iOS 16.0
- 支持所有可升级到 iOS 16 及以上的 iPhone
- 所有 iPhone 宽度和高度均使用自适应布局
- 老于 iOS 16 的 iPhone 无法安装这一构建

## 签名说明

- 免费 Apple ID：通常 7 天有效，需要重新用 Xcode 安装。
- 付费开发者账号：开发签名通常有效期 1 年，到期前重新安装。
- App Store 上架不是只在自己手机上使用的必要条件。
