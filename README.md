# OrangeBili

OrangeBili 是一个面向 Apple Watch 的 Bilibili 轻量客户端（含 iOS Companion 工程）。

## 功能概览

- 首页热门与多类型搜索（视频 / UP 主 / 专栏）
- 视频详情、评论查看/回复/点赞、UP 主主页与内容分页
- 登录增强能力（可选）：二维码登录、我的主页、关注列表、云端收藏
- 本地能力：本地收藏、观看历史、离线下载与缓存管理
- UI 可调：全局字体、评论字体、视频卡片缩放、底部栏折叠

## 开发环境

- Xcode 16+
- watchOS Simulator SDK

## 构建（Watch）

```bash
xcodebuild -project "OrangeBili.xcodeproj" \
  -scheme "OrangeBili Watch App" \
  -configuration Debug \
  -sdk watchsimulator \
  -destination "generic/platform=watchOS Simulator" \
  -derivedDataPath "./DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

