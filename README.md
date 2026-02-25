# OrangeBili

OrangeBili 是一个以 watchOS 为核心的 Bilibili 轻量客户端，包含 iOS Companion 与 tvOS 适配界面。

## 功能概览

- 首页热门与多类型搜索（视频 / UP 主 / 专栏）
- 视频详情（Tag、统计、评论入口、UP 主入口）
- 评论能力（查看、回复、点赞、删除）
- 登录增强能力（二维码登录、我的主页、关注列表、云端收藏）
- 本地能力（收藏、观看历史、UP 浏览历史、离线下载与缓存管理）
- 跨端同步（watchOS <-> iOS：历史、收藏、账号态）
- 多端 UI 适配（watchOS / iOS / tvOS）与可调渲染参数

## 项目结构

- `OrangeBili Watch App/`：watchOS App 与 WatchConnectivity 桥接发送端
- `OrangeBili/`：iOS Companion App 与 WatchConnectivity 接收/合并端
- `OrangeBiliShared/`：共享核心（API、模型、存储、ViewModel、跨端 SwiftUI 视图）
- `tools/`：调试脚本（如登录探测）
- `API.md`：接口调研记录
- `docs/TROUBLESHOOTING.md`：常见问题与排查

## 构建与运行

### 环境要求

- Xcode 16+
- watchOS / iOS / tvOS Simulator SDK

### 构建（watchOS）

```bash
xcodebuild -project "OrangeBili.xcodeproj" \
  -scheme "OrangeBili Watch App" \
  -configuration Debug \
  -sdk watchsimulator \
  -destination "generic/platform=watchOS Simulator" \
  -derivedDataPath "./DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

### 构建（iOS Companion）

```bash
xcodebuild -project "OrangeBili.xcodeproj" \
  -scheme "OrangeBili" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "./DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

### 构建（tvOS）

```bash
xcodebuild -project "OrangeBili.xcodeproj" \
  -scheme "OrangeBiliTV" \
  -configuration Debug \
  -sdk appletvsimulator \
  -destination "generic/platform=tvOS Simulator" \
  -derivedDataPath "./DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## 跨端同步说明（watchOS 与 iOS）

- watch 侧通过 `WatchCompanionSyncer` 监听历史/收藏/登录状态并做防抖同步
- iOS 侧 `CompanionConnectivityManager` 接收后 merge 到本地 Store
- 消息通道：优先 `sendMessage`（可达）回退 `updateApplicationContext`（不可达）
- 同步命令：`syncHistory` / `syncFavorites` / `syncAccount` / `requestAuthState`

## UI 适配说明

- tvOS 卡片/按钮/标签使用平台缩放，详情页封面与文本做了额外放大
- 详情页标签在 tvOS 为单行水平滚动，避免多行焦点跳转
- watchOS 优先保证可读性与低干扰布局

## 已知问题

- 部分环境下 `CoreSimulatorService` 日志较多，通常不影响构建产物
- Bilibili 接口风控或签名策略波动时，可能出现临时请求失败
- 若遇到 watchOS 整型崩溃或同步卡住，请先查看 `docs/TROUBLESHOOTING.md`

## Roadmap

- [ ] 发布页与 changelog 版本化
- [ ] 补充截图与演示 GIF
- [ ] 增强评论管理能力
- [ ] 优化网络回退与错误提示
- [ ] 完善跨端同步观测与诊断日志

## 贡献

欢迎 Issue / PR：

1. Fork 仓库
2. 新建分支并提交修改
3. 发起 Pull Request
