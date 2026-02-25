# Troubleshooting

## watchOS 崩溃：`Swift/Integers.swift:3268 Fatal error: Not enough bits to represent the passed value`

### 现象

- 进入登录态相关页面或刷新账号状态后闪退
- 日志包含 `Not enough bits to represent the passed value`

### 原因

watchOS 设备架构下 `Int` 位宽可能小于 iOS/macOS。若把超出范围的 `Int64/Double` 直接强转为 `Int`，运行时会触发 fatal error。

### 已修复点

- `BiliAuthStore.loggedInMid()` 不再直接 `Int(raw)`，改为有界解析（超范围返回 `nil`）
- `LossyInt` 解码不再使用可能触发 trap 的强转；对 `Int64/Double/String` 做安全边界处理

### 验证

- 重新登录后进入「我的」与需要账号态的页面
- 观察是否仍出现同类 fatal 日志
- 若无崩溃但账号相关接口不可用，检查服务端返回的 ID 是否超出本端 `Int` 范围

## watch 与 iOS 同步看起来“卡住”

### 快速排查

- 确认 iPhone 与 Watch 均已安装并启动对应 App
- 检查蓝牙/Wi-Fi 与前后台状态，确保 `WCSession` 可用
- 先在 iOS 侧打开 App，再触发 watch 侧同步动作（收藏/历史变更）

### 机制说明

- 可达时走 `sendMessage`（实时）
- 不可达时走 `updateApplicationContext`（最终一致）
- watch 侧有 1 秒防抖，连续变更不会逐条立刻发送

### 常见日志

- `WCSession has not been activated`
- `WCErrorCodeSessionNotActivated`

这通常表示 WatchConnectivity 还在启动阶段或配对链路尚未就绪。当前实现会在激活完成后再发送 application context，避免重复报错刷屏。

## 构建阶段出现大量 simulator 日志

- 常见于 Xcode / CoreSimulator 服务输出
- 如编译命令最终返回 `** BUILD SUCCEEDED **`，一般可忽略
- 若构建失败，请优先看第一条 Swift 编译错误而非 simulator 噪声
