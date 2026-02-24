# OrangeBili

OrangeBili 是一个面向 Apple Watch 的 Bilibili 轻量客户端（含 iOS Companion 工程）。

## 功能概览

- 首页热门与多类型搜索（视频 / UP 主 / 专栏）
- 视频详情（含 Tag）、评论查看/回复/点赞、UP 主主页与内容分页
- 登录增强能力（可选）：二维码登录、我的主页、关注列表、云端收藏
- 本地能力：本地收藏、观看历史、主页浏览历史、离线下载与缓存管理
- UI 可调：全局字体、评论字体、视频卡片缩放、底部栏折叠

## 项目结构

- `OrangeBili Watch App/`：主要 watchOS 客户端（UI、服务层、缓存、下载、登录）
- `OrangeBili/`：iOS Companion 与连接能力
- `tools/`：调试/测试脚本（如登录探测）
- `API.md`：接口调研与记录

## 运行与构建

### 环境要求

- Xcode 16+
- watchOS Simulator SDK
- （可选）GitHub CLI：发布仓库时使用

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

## 截图占位

> 可在后续补充到 `docs/screenshots/`，并替换为真实图片链接

- 首页：热门视频流
- 视频详情：统计 + Tag + 操作区
- 评论详情：点赞/回复/删除
- 我的：登录、关注、云端收藏、渲染设置
- 工具：本地收藏/云端收藏/历史/离线缓存

## 已知问题

- 在部分本地环境中，`CoreSimulatorService` 可能输出大量连接日志；通常不影响最终构建结果。
- iOS Companion 与 watchOS 能力仍在持续联调，部分体验以 watch 端优先。
- Bilibili 部分接口存在风控与签名变化，可能导致临时不可用。

## Roadmap

- [ ] 完善发布页与 changelog（版本化）
- [ ] 补齐截图与演示 GIF
- [ ] 增强评论交互（更多管理能力）
- [ ] 优化网络回退策略与错误提示
- [ ] 完善 iOS Companion 与 watch 端同步链路

## 贡献

欢迎提交 Issue / PR：

1. Fork 本仓库
2. 新建分支并提交修改
3. 发起 Pull Request
