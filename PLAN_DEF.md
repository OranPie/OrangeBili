# BiliWatch — Apple Watch 哔哩哔哩客户端 · 设计与实现方案

---

## 一、项目总览

### 1.1 项目目标

在 Apple Watch 上实现一个轻量级哔哩哔哩客户端，支持视频浏览、搜索、播放等核心功能，结合手腕场景优化交互体验。

### 1.2 功能分期规划

| 阶段 | 功能 | 说明 |
|------|------|------|
| **Phase 1 (MVP)** | ✅ 推荐/热门 · ✅ 搜索 · ✅ 视频播放 | 核心三件套，独立可用 |
| **Phase 2** | ✅ 评论查看 · ✅ UP主主页 · ✅ 本地历史 · ✅ 本地缓存 | 增强体验 |
| **Phase 3** | ✅ 扫码登录 · ✅ 收藏夹 · ✅ 云端历史 · ✅ 动态 | 完整功能 |

### 1.3 技术栈

```
平台目标:  watchOS 10.0+ / iOS 17.0+ (Companion)
语言:      Swift 5.9+
UI框架:    SwiftUI
架构:      MVVM + Service Layer
网络:      URLSession + async/await
播放器:    AVKit (AVPlayer)
本地存储:  SwiftData / FileManager
手机通信:  WatchConnectivity
IDE:       Xcode 15+
```

---

## 二、系统架构设计

### 2.1 整体架构

```
┌──────────────────────────────────────────────────┐
│                  Apple Watch App                  │
├────────────┬────────────┬────────────┬───────────┤
│  Views     │ ViewModels │  Services  │  Models   │
│ (SwiftUI)  │ (ObsObj)   │            │ (Codable) │
├────────────┴────────────┴─────┬──────┴───────────┤
│          Core Layer           │   Storage Layer   │
│  ┌───────────┐ ┌───────────┐ │ ┌───────────────┐ │
│  │ Network   │ │ AVPlayer  │ │ │  SwiftData    │ │
│  │ Manager   │ │ Manager   │ │ │  FileManager  │ │
│  └───────────┘ └───────────┘ │ └───────────────┘ │
├──────────────────────────────┴───────────────────┤
│              WatchConnectivity                    │
│         (与 iPhone Companion 通信)                 │
└──────────────────────────────────────────────────┘
         ↕ HTTPS                    ↕ Bluetooth/WiFi
┌──────────────────┐      ┌────────────────────────┐
│  BiliBili API    │      │   iPhone Companion App  │
│  api.bilibili.com│      │  (登录辅助/缓存中转)      │
└──────────────────┘      └────────────────────────┘
```

### 2.2 项目目录结构

```
BiliWatch/
├── BiliWatchApp.swift                 # App 入口
├── ContentView.swift                  # 主 TabView
│
├── Models/
│   ├── Video.swift                    # 视频模型
│   ├── VideoStream.swift              # 播放流模型
│   ├── Comment.swift                  # 评论模型
│   ├── User.swift                     # UP主/用户模型
│   ├── SearchResult.swift             # 搜索结果
│   └── Recommendation.swift           # 推荐模型
│
├── ViewModels/
│   ├── HomeViewModel.swift            # 推荐/热门
│   ├── SearchViewModel.swift          # 搜索
│   ├── VideoDetailViewModel.swift     # 视频详情
│   ├── PlayerViewModel.swift          # 播放控制
│   ├── CommentsViewModel.swift        # 评论
│   ├── UPProfileViewModel.swift       # UP主主页
│   └── HistoryViewModel.swift         # 历史记录
│
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift             # 推荐列表
│   │   └── VideoCardView.swift        # 视频卡片组件
│   ├── Search/
│   │   ├── SearchView.swift           # 搜索页
│   │   └── SearchResultRow.swift      # 搜索结果行
│   ├── Player/
│   │   └── VideoPlayerView.swift      # 播放器
│   ├── Detail/
│   │   └── VideoDetailView.swift      # 视频详情
│   ├── Comments/
│   │   └── CommentsView.swift         # 评论列表
│   ├── Profile/
│   │   ├── UPProfileView.swift        # UP主主页
│   │   └── MeView.swift              # 个人中心
│   └── Components/
│       ├── AsyncCachedImage.swift     # 异步缓存图片
│       ├── StatBadge.swift            # 数据徽章
│       └── LoadingView.swift          # 加载状态
│
├── Services/
│   ├── BiliAPI.swift                  # API 端点定义
│   ├── NetworkManager.swift           # 网络请求引擎
│   ├── PlayerManager.swift            # 播放器管理
│   ├── CacheManager.swift             # 缓存管理
│   ├── HistoryManager.swift           # 历史记录管理
│   └── AuthManager.swift             # 认证管理 (Phase 3)
│
├── Utils/
│   ├── Constants.swift                # 常量
│   ├── Extensions.swift               # 扩展
│   └── NumberFormatter+Bili.swift     # 数字格式化
│
└── BiliWatch-iPhone/                  # Companion App
    ├── CompanionApp.swift
    ├── LoginView.swift                # 扫码登录
    └── ConnectivityManager.swift      # WatchConnectivity
```

---

## 三、BiliBili API 接口文档

### 3.1 公共配置

```swift
enum BiliAPIConfig {
    static let baseURL = "https://api.bilibili.com"
    
    static let commonHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
        "Referer": "https://www.bilibili.com"
    ]
    
    /// 未登录状态可用的最高画质
    /// 16=360P, 32=480P, 64=720P(需登录)
    static let defaultQuality = 32
}
```

> ⚠️ BiliBili API 为非官方逆向接口，可能随时变更。CDN 资源**必须携带 Referer 头**。

### 3.2 搜索视频

```
GET /x/web-interface/search/type
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `keyword` | string | ✅ | 搜索关键词 |
| `search_type` | string | ✅ | 固定 `video` |
| `page` | int | ❌ | 页码，默认1 |
| `page_size` | int | ❌ | 每页数，默认20，Watch建议10 |
| `order` | string | ❌ | 排序: 空=综合, `click`=播放, `pubdate`=新发布 |

**响应关键字段:**
```json
{
  "code": 0,
  "data": {
    "numResults": 1000,
    "pagesize": 10,
    "result": [
      {
        "bvid": "BV1xx411c7mD",
        "aid": 170001,
        "title": "视频标题（含<em>高亮</em>）",
        "author": "UP主名",
        "mid": 123456,
        "pic": "//i0.hdslb.com/bfs/archive/xxx.jpg",
        "play": 12345,
        "danmaku": 678,
        "duration": "12:34",
        "description": "简介"
      }
    ]
  }
}
```

### 3.3 视频详情

```
GET /x/web-interface/view
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `bvid` | string | ✅ | 视频 BV 号 |

**响应关键字段:**
```json
{
  "code": 0,
  "data": {
    "bvid": "BV1xx411c7mD",
    "aid": 170001,
    "cid": 279786,         // ← 播放必需
    "title": "视频标题",
    "desc": "视频简介",
    "pic": "封面URL",
    "duration": 754,        // 秒
    "owner": {
      "mid": 123456,
      "name": "UP主",
      "face": "头像URL"
    },
    "stat": {
      "view": 100000,
      "danmaku": 5000,
      "reply": 3000,
      "favorite": 8000,
      "coin": 6000,
      "like": 20000
    },
    "pages": [
      { "cid": 279786, "part": "P1标题", "page": 1, "duration": 754 }
    ]
  }
}
```

### 3.4 视频播放流 ⭐ (核心)

```
GET /x/player/playurl
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `bvid` | string | ✅ | BV号 |
| `cid` | int | ✅ | 视频cid (从详情获取) |
| `qn` | int | ❌ | 画质: 16=360P, 32=480P |
| `fnval` | int | ❌ | `0`=FLV合并流, `16`=DASH分离流 |
| `platform` | string | ❌ | `html5` 可获取MP4格式 |
| `high_quality` | int | ❌ | `1`=请求最高画质 |

**🎯 Watch 推荐请求策略:**

```
策略A (首选): fnval=0 & platform=html5 & qn=32
 → 返回 durl[] 合并流（MP4），AVPlayer 可直接播放

策略B (备选): fnval=16 & qn=32
 → 返回 DASH 分离流（video .m4s + audio .m4s）
 → 需手动合并或分别加载
```

**策略A 响应 (durl):**
```json
{
  "code": 0,
  "data": {
    "quality": 32,
    "durl": [
      {
        "url": "https://cn-hk-eq-bcache-01.bilivideo.com/...mp4",
        "backup_url": ["备用URL"],
        "size": 15000000,
        "length": 754000
      }
    ]
  }
}
```

**策略B 响应 (DASH):**
```json
{
  "data": {
    "dash": {
      "video": [
        {
          "id": 32,
          "baseUrl": "https://...video.m4s",
          "bandwidth": 500000,
          "codecid": 7,
          "codecs": "avc1.64001E",
          "width": 852,
          "height": 480
        }
      ],
      "audio": [
        {
          "id": 30216,
          "baseUrl": "https://...audio.m4s",
          "bandwidth": 67000,
          "codecs": "mp4a.40.2"
        }
      ]
    }
  }
}
```

### 3.5 推荐视频

```
GET /x/web-interface/index/top/rcmd
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `fresh_type` | int | ❌ | 固定 `4` |
| `ps` | int | ❌ | 数量，默认10 |

> 无需登录即可获取推荐。登录后返回个性化结果。

**备选 — 热门视频 (更稳定):**
```
GET /x/web-interface/popular?pn=1&ps=10
```

### 3.6 评论列表

```
GET /x/v2/reply/main
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `type` | int | ✅ | `1` = 视频评论 |
| `oid` | int | ✅ | 视频 aid |
| `mode` | int | ❌ | `0`=默认, `2`=时间, `3`=热度 |
| `next` | int | ❌ | 翻页游标 |
| `ps` | int | ❌ | 每页数量，Watch建议5-10 |

### 3.7 UP主信息

```
GET /x/space/wbi/acc/info?mid={uid}
```

> ⚠️ 此接口需要 **Wbi 签名**（见 3.10）

### 3.8 UP主投稿视频

```
GET /x/space/wbi/arc/search?mid={uid}&pn=1&ps=10
```

### 3.9 扫码登录 (Phase 3)

```
步骤1: GET /x/passport-login/web/qrcode/generate
  → 返回 { url, qrcode_key }
  → iPhone 端展示二维码

步骤2: GET /x/passport-login/web/qrcode/poll?qrcode_key=xxx
  → 轮询状态，成功后返回 Set-Cookie (SESSDATA, bili_jct等)
```

### 3.10 Wbi 签名算法

部分接口需要 Wbi 签名防爬。签名流程：

```swift
// 1. 从 /x/web-interface/nav 获取 wbi_img.img_url 和 sub_url
// 2. 提取 img_key 和 sub_key (URL 中的文件名去后缀)
// 3. 拼接 img_key + sub_key，按照固定 mixinKeyEncTab 重排取前32位 → mixin_key
// 4. 将请求参数 + wts(时间戳) 排序拼接，追加 mixin_key，取 MD5 → w_rid
// 5. 将 wts 和 w_rid 附加到请求参数中

// 简化：Phase 1/2 可暂时跳过需 Wbi 签名的接口，或硬编码临时 key
```

---

## 四、数据模型设计

### 4.1 核心 Models

```swift
import Foundation

// MARK: - 视频
struct BiliVideo: Codable, Identifiable, Hashable {
    let aid: Int
    let bvid: String
    let title: String
    let pic: String           // 封面URL
    let duration: Int         // 秒
    let desc: String?
    let owner: BiliOwner
    let stat: BiliStat?
    let cid: Int?             // 首P的cid（详情接口返回）
    let pages: [BiliPage]?
    
    var id: String { bvid }
    
    /// 格式化时长 "12:34"
    var durationText: String {
        let m = duration / 60
        let s = duration % 60
        return String(format: "%d:%02d", m, s)
    }
    
    /// https 封面
    var coverURL: URL? {
        URL(string: pic.hasPrefix("//") ? "https:\(pic)" : pic)
    }
}

struct BiliOwner: Codable, Hashable {
    let mid: Int
    let name: String
    let face: String          // 头像URL
}

struct BiliStat: Codable, Hashable {
    let view: Int?
    let danmaku: Int?
    let reply: Int?
    let favorite: Int?
    let coin: Int?
    let like: Int?
    
    /// 万/亿 格式化
    static func formatCount(_ n: Int?) -> String {
        guard let n = n else { return "0" }
        if n >= 100_000_000 { return String(format: "%.1f亿", Double(n)/1e8) }
        if n >= 10_000 { return String(format: "%.1f万", Double(n)/1e4) }
        return "\(n)"
    }
}

struct BiliPage: Codable, Hashable {
    let cid: Int
    let page: Int
    let part: String          // 分P标题
    let duration: Int
}

// MARK: - 评论
struct BiliComment: Codable, Identifiable {
    let rpid: Int             // 评论ID
    let content: CommentContent
    let member: CommentMember
    let like: Int
    let rcount: Int           // 回复数
    let ctime: Int            // 时间戳
    
    var id: Int { rpid }
    
    struct CommentContent: Codable {
        let message: String
    }
    struct CommentMember: Codable {
        let mid: String
        let uname: String
        let avatar: String
    }
}

// MARK: - UP主
struct BiliUPInfo: Codable {
    let mid: Int
    let name: String
    let face: String
    let sign: String          // 签名
    let follower: Int?        // 需从 stat 接口获取
    let level: Int?
}

// MARK: - 播放流
struct BiliPlayURL: Codable {
    let quality: Int
    let durl: [DurlItem]?
    let dash: DashInfo?
    
    struct DurlItem: Codable {
        let url: String
        let backupUrl: [String]?
        let size: Int
        let length: Int       // 毫秒
        
        enum CodingKeys: String, CodingKey {
            case url, size, length
            case backupUrl = "backup_url"
        }
    }
    
    struct DashInfo: Codable {
        let video: [DashStream]
        let audio: [DashStream]?
    }
    
    struct DashStream: Codable {
        let id: Int
        let baseUrl: String
        let bandwidth: Int
        let codecs: String
        let width: Int?
        let height: Int?
    }
}

// MARK: - 搜索结果
struct BiliSearchResult: Codable {
    let bvid: String
    let title: String         // 含 <em> 标签
    let author: String
    let mid: Int
    let pic: String
    let play: Int
    let duration: String      // "12:34" 格式
    let description: String?
    
    /// 去除HTML标签的标题
    var cleanTitle: String {
        title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

// MARK: - API 响应包装
struct BiliResponse<T: Codable>: Codable {
    let code: Int
    let message: String?
    let data: T?
}

// MARK: - 本地历史记录
struct WatchHistory: Codable, Identifiable {
    let bvid: String
    let title: String
    let cover: String
    let upName: String
    let duration: Int
    var progress: Int         // 已观看秒数
    let watchedAt: Date
    
    var id: String { bvid }
}
```

---

## 五、UI/UX 设计方案

### 5.1 导航结构 (TabView)

```
┌─────────────────────────────┐
│        BiliWatch App        │
├────────┬─────────┬──────────┤
│  🏠    │  🔍     │  👤      │
│  首页   │  搜索   │  我的    │
│ (推荐)  │        │(历史/设置)│
└────────┴─────────┴──────────┘
         ↓ 下钻
    ┌──────────┐
    │ 视频详情  │ → 播放器
    │          │ → 评论
    │          │ → UP主主页 → UP主视频列表
    └──────────┘
```

### 5.2 各页面设计

#### 🏠 首页 — 推荐/热门

```
┌──────────────────────┐
│  🔥 推荐             │  ← 标题栏
├──────────────────────┤
│ ┌──────────────────┐ │
│ │  ▓▓▓▓▓▓ 封面图   │ │  ← 圆角矩形封面 (全宽)
│ │  ▓▓▓▓▓▓▓▓▓▓▓▓▓  │ │
│ ├──────────────────┤ │
│ │ 视频标题最多两行.. │ │  ← .headline, 2行截断
│ │ 👤UP主  ▶12.3万  │ │  ← .caption2, 灰色
│ └──────────────────┘ │
│                      │  ← 间距 8pt
│ ┌──────────────────┐ │
│ │  ▓▓▓▓▓▓ 封面图   │ │
│ │  ...              │ │
│ └──────────────────┘ │
│                      │
│   ↻ 下拉/滚动加载更多 │  ← Digital Crown 滚动
└──────────────────────┘
```

#### 🔍 搜索

```
┌──────────────────────┐
│ ┌──────────────────┐ │
│ │ 🔍 搜索BiliBili   │ │  ← TextField，点击弹出系统输入
│ └──────────────────┘ │
├──────────────────────┤  ← 无输入时显示热搜
│  🔥 热搜榜           │
│  1. xxxxx            │
│  2. xxxxx            │
│  3. xxxxx            │
├──────────────────────┤  ← 输入后显示结果
│ ┌────┬─────────────┐ │
│ │ 封面│ 标题...     │ │  ← 紧凑行：左图右文
│ │ 图  │ UP主 ▶1.2万 │ │
│ └────┴─────────────┘ │
│ ┌────┬─────────────┐ │
│ │    │ ...          │ │
│ └────┴─────────────┘ │
└──────────────────────┘
```

#### 📺 视频详情

```
┌──────────────────────┐
│ ┌──────────────────┐ │
│ │  ▓▓▓▓▓ 封面 ▓▓▓  │ │  ← 大封面 + 时长标签
│ │  ▓▓▓▓▓▓▓  05:32  │ │
│ └──────────────────┘ │
│                      │
│ ▶ 播放视频           │  ← 主按钮，醒目蓝色/粉色
│                      │
│ 完整的视频标题可以    │  ← .headline，最多3行
│ 显示到三行截断...     │
│                      │
│ ┌──────────────────┐ │
│ │ 😊 UP名  >       │ │  ← 可点击跳转UP主页
│ └──────────────────┘ │
│                      │
│ ▶100w  💬3.2w  👍5w  │  ← 统计数据行
│                      │
│ 💬 查看评论 (3215)   │  ← 导航按钮
│                      │
│ 📋 简介              │
│ 这是视频简介内容...   │  ← 折叠，点击展开
└──────────────────────┘
```

#### ▶️ 播放器

```
┌──────────────────────┐
│                      │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │  ← 全屏视频
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │     Digital Crown = 音量
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │     点击 = 播放/暂停
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │     左滑 = 返回
│                      │
│  01:23 ━━━━━○─── 05:32│ ← 进度条 (可选叠加层)
└──────────────────────┘
```

#### 💬 评论

```
┌──────────────────────┐
│  💬 热门评论          │
├──────────────────────┤
│ 用户A                │  ← .caption, 蓝色
│ 这条评论的内容可以显  │  ← .body, 最多4行
│ 示多行文本...         │
│ 👍 1.2w              │  ← .caption2, 灰色
├──────────────────────┤
│ 用户B                │
│ 评论内容...           │
│ 👍 856               │
├──────────────────────┤
│       加载更多...     │
└──────────────────────┘
```

---

## 六、核心模块实现

### 6.1 网络层 — NetworkManager

```swift
import Foundation

actor NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let baseURL = "https://api.bilibili.com"
    private var cookies: [String: String] = [:]  // Phase 3: SESSDATA 等
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = BiliAPIConfig.commonHeaders
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 通用请求
    func request<T: Codable>(
        _ endpoint: String,
        params: [String: String] = [:],
        type: T.Type
    ) async throws -> T {
        var components = URLComponents(string: baseURL + endpoint)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        var request = URLRequest(url: components.url!)
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        
        // 附加登录 Cookie (Phase 3)
        if !cookies.isEmpty {
            let cookieString = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieString, forHTTPHeaderField: "Cookie")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResp = response as? HTTPURLResponse,
              200...299 ~= httpResp.statusCode else {
            throw BiliError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        let biliResp = try JSONDecoder().decode(BiliResponse<T>.self, from: data)
        
        guard biliResp.code == 0, let data = biliResp.data else {
            throw BiliError.apiError(biliResp.code, biliResp.message ?? "未知错误")
        }
        
        return data
    }
    
    // MARK: - 图片下载（带内存缓存）
    private var imageCache = NSCache<NSString, CacheableData>()
    
    func loadImage(from urlString: String) async throws -> Data {
        let key = urlString as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached.data
        }
        
        let url = URL(string: urlString.hasPrefix("//") ? "https:\(urlString)" : urlString)!
        let (data, _) = try await session.data(from: url)
        imageCache.setObject(CacheableData(data: data), forKey: key)
        return data
    }
}

// NSCache 需要 class 类型
final class CacheableData: NSObject {
    let data: Data
    init(data: Data) { self.data = data }
}

enum BiliError: LocalizedError {
    case httpError(Int)
    case apiError(Int, String)
    case noStream
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "网络错误 (\(code))"
        case .apiError(_, let msg): return msg
        case .noStream: return "无法获取视频流"
        case .invalidURL: return "无效的URL"
        }
    }
}
```

### 6.2 API 服务层

```swift
import Foundation

struct BiliService {
    private let network = NetworkManager.shared
    
    // MARK: - 推荐
    func fetchRecommendations(count: Int = 10) async throws -> [BiliVideo] {
        struct RcmdData: Codable {
            let item: [BiliVideo]
        }
        let data: RcmdData = try await network.request(
            "/x/web-interface/index/top/rcmd",
            params: ["fresh_type": "4", "ps": "\(count)"],
            type: RcmdData.self
        )
        return data.item
    }
    
    // MARK: - 热门
    func fetchPopular(page: Int = 1, size: Int = 10) async throws -> [BiliVideo] {
        struct PopData: Codable { let list: [BiliVideo] }
        let data: PopData = try await network.request(
            "/x/web-interface/popular",
            params: ["pn": "\(page)", "ps": "\(size)"],
            type: PopData.self
        )
        return data.list
    }
    
    // MARK: - 搜索
    func search(keyword: String, page: Int = 1) async throws -> [BiliSearchResult] {
        struct SearchData: Codable { let result: [BiliSearchResult]? }
        let data: SearchData = try await network.request(
            "/x/web-interface/search/type",
            params: [
                "keyword": keyword,
                "search_type": "video",
                "page": "\(page)",
                "page_size": "10"
            ],
            type: SearchData.self
        )
        return data.result ?? []
    }
    
    // MARK: - 视频详情
    func fetchVideoDetail(bvid: String) async throws -> BiliVideo {
        try await network.request(
            "/x/web-interface/view",
            params: ["bvid": bvid],
            type: BiliVideo.self
        )
    }
    
    // MARK: - 播放地址 ⭐
    func fetchPlayURL(bvid: String, cid: Int) async throws -> BiliPlayURL {
        // 策略A: 请求 HTML5 兼容的合并流 (MP4)
        let data: BiliPlayURL = try await network.request(
            "/x/player/playurl",
            params: [
                "bvid": bvid,
                "cid": "\(cid)",
                "qn": "32",           // 480P (Watch足够)
                "fnval": "0",          // durl合并流
                "platform": "html5",   // 请求MP4格式
                "high_quality": "1"
            ],
            type: BiliPlayURL.self
        )
        return data
    }
    
    // MARK: - 播放地址 DASH 备选
    func fetchPlayURLDash(bvid: String, cid: Int) async throws -> BiliPlayURL {
        try await network.request(
            "/x/player/playurl",
            params: [
                "bvid": bvid,
                "cid": "\(cid)",
                "qn": "32",
                "fnval": "16",         // DASH分离流
                "fnver": "0",
                "fourk": "0"
            ],
            type: BiliPlayURL.self
        )
    }
    
    // MARK: - 评论
    func fetchComments(aid: Int, next: Int = 0) async throws -> (comments: [BiliComment], nextPage: Int) {
        struct ReplyData: Codable {
            let replies: [BiliComment]?
            let cursor: Cursor?
            struct Cursor: Codable { let next: Int; let isEnd: Bool
                enum CodingKeys: String, CodingKey { case next; case isEnd = "is_end" }
            }
        }
        let data: ReplyData = try await network.request(
            "/x/v2/reply/main",
            params: [
                "type": "1",
                "oid": "\(aid)",
                "mode": "3",           // 热度排序
                "next": "\(next)",
                "ps": "10"
            ],
            type: ReplyData.self
        )
        return (data.replies ?? [], data.cursor?.next ?? 0)
    }
    
    // MARK: - UP主信息
    func fetchUPInfo(mid: Int) async throws -> BiliUPInfo {
        try await network.request(
            "/x/space/wbi/acc/info",
            params: ["mid": "\(mid)"],
            type: BiliUPInfo.self
        )
    }
    
    // MARK: - UP主视频
    func fetchUPVideos(mid: Int, page: Int = 1) async throws -> [BiliVideo] {
        struct ArcData: Codable {
            let list: ArcList
            struct ArcList: Codable { let vlist: [BiliVideo] }
        }
        let data: ArcData = try await network.request(
            "/x/space/wbi/arc/search",
            params: ["mid": "\(mid)", "pn": "\(page)", "ps": "10"],
            type: ArcData.self
        )
        return data.list.vlist
    }
}
```

### 6.3 视频播放器 ⭐⭐

```swift
import SwiftUI
import AVKit

// MARK: - PlayerManager
@Observable
class PlayerManager {
    var player: AVPlayer?
    var isLoading = true
    var error: String?
    var currentTime: Double = 0
    var totalDuration: Double = 0
    
    private let service = BiliService()
    private var timeObserver: Any?
    
    func loadVideo(bvid: String, cid: Int) async {
        isLoading = true
        error = nil
        
        do {
            // 策略A: HTML5 合并流
            let playURL = try await service.fetchPlayURL(bvid: bvid, cid: cid)
            
            if let durl = playURL.durl?.first {
                try await setupPlayer(url: durl.url, backupURLs: durl.backupUrl)
                return
            }
            
            // 策略B: DASH 分离流
            let dashURL = try await service.fetchPlayURLDash(bvid: bvid, cid: cid)
            if let videoStream = dashURL.dash?.video
                .filter({ $0.codecs.hasPrefix("avc") })  // 优先 H.264
                .sorted(by: { $0.bandwidth < $1.bandwidth })
                .first {
                try await setupPlayer(url: videoStream.baseUrl, backupURLs: nil)
                return
            }
            
            throw BiliError.noStream
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
    
    private func setupPlayer(url: String, backupURLs: [String]?) async throws {
        guard let videoURL = URL(string: url) else { throw BiliError.invalidURL }
        
        // ⭐ 关键: 设置 Referer，否则 CDN 403
        let headers: [String: String] = [
            "Referer": "https://www.bilibili.com",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
        ]
        
        let asset = AVURLAsset(
            url: videoURL,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        
        let playerItem = AVPlayerItem(asset: asset)
        
        await MainActor.run {
            self.player = AVPlayer(playerItem: playerItem)
            self.isLoading = false
            self.player?.play()
            observeProgress()
        }
    }
    
    private func observeProgress() {
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
            self?.totalDuration = self?.player?.currentItem?.duration.seconds ?? 0
        }
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
    }
}

// MARK: - 播放器视图
struct VideoPlayerView: View {
    let bvid: String
    let cid: Int
    let title: String
    
    @State private var playerManager = PlayerManager()
    @State private var showControls = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if playerManager.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("加载中...")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            } else if let error = playerManager.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        Task { await playerManager.loadVideo(bvid: bvid, cid: cid) }
                    }
                    .font(.caption)
                }
            } else if let player = playerManager.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if player.timeControlStatus == .playing {
                            player.pause()
                        } else {
                            player.play()
                        }
                    }
            }
        }
        .navigationBarHidden(true)
        // Digital Crown → 音量 (系统默认行为)
        .task {
            await playerManager.loadVideo(bvid: bvid, cid: cid)
        }
        .onDisappear {
            // 保存进度到历史
            saveProgress()
            playerManager.cleanup()
        }
    }
    
    private func saveProgress() {
        let progress = Int(playerManager.currentTime)
        HistoryManager.shared.updateProgress(bvid: bvid, progress: progress)
    }
}
```

### 6.4 首页视图

```swift
import SwiftUI

// MARK: - HomeViewModel
@Observable
class HomeViewModel {
    var videos: [BiliVideo] = []
    var isLoading = false
    var errorMessage: String?
    
    private let service = BiliService()
    
    func loadRecommendations() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            videos = try await service.fetchPopular(page: 1, size: 12)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func loadMore() async {
        let nextPage = (videos.count / 12) + 1
        do {
            let more = try await service.fetchPopular(page: nextPage, size: 12)
            videos.append(contentsOf: more)
        } catch {
            // 静默失败，保留现有内容
        }
    }
}

// MARK: - HomeView
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.videos.isEmpty {
                    ProgressView("加载推荐...")
                } else if let error = viewModel.errorMessage, viewModel.videos.isEmpty {
                    VStack(spacing: 8) {
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        Button("重试") { Task { await viewModel.loadRecommendations() } }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.videos) { video in
                                NavigationLink(value: video) {
                                    VideoCardView(video: video)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // 加载更多触发器
                            Color.clear.frame(height: 1)
                                .onAppear { Task { await viewModel.loadMore() } }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .navigationTitle("推荐")
            .navigationDestination(for: BiliVideo.self) { video in
                VideoDetailView(video: video)
            }
        }
        .task { await viewModel.loadRecommendations() }
    }
}

// MARK: - 视频卡片组件
struct VideoCardView: View {
    let video: BiliVideo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 封面图
            ZStack(alignment: .bottomTrailing) {
                AsyncCachedImage(url: video.coverURL)
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
                    .cornerRadius(8)
                
                // 时长标签
                Text(video.durationText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(4)
            }
            
            // 标题
            Text(video.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            // UP主 + 播放量
            HStack(spacing: 4) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 9))
                Text(video.owner.name)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                Text(BiliStat.formatCount(video.stat?.view))
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 异步缓存图片
struct AsyncCachedImage: View {
    let url: URL?
    @State private var imageData: Data?
    
    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        ProgressView().scaleEffect(0.5)
                    }
            }
        }
        .task(id: url) {
            guard let url = url else { return }
            imageData = try? await NetworkManager.shared.loadImage(from: url.absoluteString)
        }
    }
}
```

### 6.5 搜索视图

```swift
import SwiftUI

@Observable
class SearchViewModel {
    var query = ""
    var results: [BiliSearchResult] = []
    var isSearching = false
    var hasSearched = false
    
    private let service = BiliService()
    private var searchTask: Task<Void, Never>?
    
    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        searchTask?.cancel()
        searchTask = Task {
            isSearching = true
            hasSearched = true
            do {
                results = try await service.search(keyword: trimmed)
            } catch {
                if !Task.isCancelled { results = [] }
            }
            isSearching = false
        }
    }
}

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                // 搜索框
                Section {
                    TextField("搜索BiliBili", text: $viewModel.query)
                        .onSubmit { viewModel.search() }
                }
                
                // 搜索结果
                if viewModel.isSearching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if viewModel.results.isEmpty && viewModel.hasSearched {
                    Section {
                        Text("未找到相关视频")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                } else {
                    Section {
                        ForEach(viewModel.results, id: \.bvid) { result in
                            NavigationLink(value: result.bvid) {
                                SearchResultRow(result: result)
                            }
                        }
                    }
                }
            }
            .navigationTitle("搜索")
            .navigationDestination(for: String.self) { bvid in
                // 从 bvid 加载完整详情
                VideoDetailLoadingView(bvid: bvid)
            }
        }
    }
}

struct SearchResultRow: View {
    let result: BiliSearchResult
    
    var body: some View {
        HStack(spacing: 8) {
            // 缩略图
            AsyncCachedImage(url: URL(string: result.pic.hasPrefix("//") ? "https:\(result.pic)" : result.pic))
                .frame(width: 60, height: 38)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.cleanTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                
                HStack(spacing: 3) {
                    Text(result.author)
                    Text("·")
                    Text(result.duration)
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
```

### 6.6 视频详情视图

```swift
struct VideoDetailView: View {
    let video: BiliVideo
    @State private var detail: BiliVideo?
    @State private var isLoading = true
    
    private let service = BiliService()
    
    var displayVideo: BiliVideo { detail ?? video }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // 封面
                ZStack(alignment: .bottomTrailing) {
                    AsyncCachedImage(url: displayVideo.coverURL)
                        .aspectRatio(16/9, contentMode: .fill)
                        .cornerRadius(10)
                    
                    Text(displayVideo.durationText)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                        .padding(6)
                }
                
                // ▶ 播放按钮
                if let cid = displayVideo.cid ?? displayVideo.pages?.first?.cid {
                    NavigationLink {
                        VideoPlayerView(
                            bvid: displayVideo.bvid,
                            cid: cid,
                            title: displayVideo.title
                        )
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                            Text("播放视频")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .background(Color.pink)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                // 标题
                Text(displayVideo.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(3)
                
                // UP主（可跳转）
                NavigationLink {
                    UPProfileView(mid: displayVideo.owner.mid)
                } label: {
                    HStack(spacing: 6) {
                        AsyncCachedImage(url: URL(string: displayVideo.owner.face))
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                        Text(displayVideo.owner.name)
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                
                // 统计数据
                if let stat = displayVideo.stat {
                    HStack(spacing: 12) {
                        StatBadge(icon: "play.fill", value: stat.view)
                        StatBadge(icon: "text.bubble.fill", value: stat.reply)
                        StatBadge(icon: "hand.thumbsup.fill", value: stat.like)
                    }
                    .padding(.vertical, 4)
                }
                
                // 评论入口
                NavigationLink {
                    CommentsView(aid: displayVideo.aid)
                } label: {
                    HStack {
                        Image(systemName: "text.bubble")
                        Text("查看评论")
                        Spacer()
                        if let count = displayVideo.stat?.reply {
                            Text(BiliStat.formatCount(count))
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.system(size: 13))
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                
                // 简介
                if let desc = displayVideo.desc, !desc.isEmpty {
                    DisclosureGroup("简介") {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 加载完整详情以获取 cid
            if video.cid == nil {
                detail = try? await service.fetchVideoDetail(bvid: video.bvid)
            }
            // 记录到历史
            HistoryManager.shared.addToHistory(video: displayVideo)
        }
    }
}

// MARK: - 统计徽章
struct StatBadge: View {
    let icon: String
    let value: Int?
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(BiliStat.formatCount(value))
                .font(.system(size: 10))
        }
        .foregroundStyle(.secondary)
    }
}
```

### 6.7 评论视图

```swift
@Observable
class CommentsViewModel {
    var comments: [BiliComment] = []
    var isLoading = false
    var nextPage = 0
    var hasMore = true
    
    private let service = BiliService()
    
    func loadComments(aid: Int) async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let result = try await service.fetchComments(aid: aid, next: nextPage)
            comments.append(contentsOf: result.comments)
            nextPage = result.nextPage
            hasMore = !result.comments.isEmpty
        } catch { hasMore = false }
        isLoading = false
    }
}

struct CommentsView: View {
    let aid: Int
    @State private var viewModel = CommentsViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.comments) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    Text(comment.member.uname)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.blue)
                    
                    Text(comment.content.message)
                        .font(.system(size: 12))
                        .lineLimit(5)
                    
                    HStack {
                        Image(systemName: "hand.thumbsup")
                        Text(BiliStat.formatCount(comment.like))
                        if comment.rcount > 0 {
                            Text("· \(comment.rcount)回复")
                        }
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            
            if viewModel.hasMore {
                Button("加载更多") {
                    Task { await viewModel.loadComments(aid: aid) }
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("评论")
        .task { await viewModel.loadComments(aid: aid) }
    }
}
```

### 6.8 缓存管理

```swift
import Foundation

actor CacheManager {
    static let shared = CacheManager()
    
    private let fileManager = FileManager.default
    
    private var cacheDir: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BiliCache", isDirectory: true)
    }
    
    private var videoCacheDir: URL {
        cacheDir.appendingPathComponent("Videos", isDirectory: true)
    }
    
    init() {
        try? fileManager.createDirectory(at: videoCacheDir, withIntermediateDirectories: true)
    }
    
    // MARK: - 视频缓存
    
    /// 下载视频到本地
    func cacheVideo(bvid: String, url: URL, headers: [String: String]) async throws -> URL {
        let localURL = videoCacheDir.appendingPathComponent("\(bvid).mp4")
        
        guard !fileManager.fileExists(atPath: localURL.path) else {
            return localURL  // 已缓存
        }
        
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        let (tempURL, _) = try await URLSession.shared.download(for: request)
        try fileManager.moveItem(at: tempURL, to: localURL)
        
        return localURL
    }
    
    /// 检查是否已缓存
    func isCached(bvid: String) -> Bool {
        fileManager.fileExists(atPath: videoCacheDir.appendingPathComponent("\(bvid).mp4").path)
    }
    
    /// 获取缓存视频路径
    func cachedVideoURL(bvid: String) -> URL? {
        let url = videoCacheDir.appendingPathComponent("\(bvid).mp4")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
    
    // MARK: - 缓存清理
    
    /// 获取缓存总大小 (bytes)
    func totalCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: videoCacheDir, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
    
    /// 清除所有视频缓存
    func clearVideoCache() throws {
        try fileManager.removeItem(at: videoCacheDir)
        try fileManager.createDirectory(at: videoCacheDir, withIntermediateDirectories: true)
    }
    
    /// 自动清理超限缓存 (默认200MB限制)
    func autoCleanIfNeeded(limit: Int64 = 200 * 1024 * 1024) throws {
        guard totalCacheSize() > limit else { return }
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: videoCacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }
        
        // 按修改时间排序，删除最旧的
        let sorted = files.sorted {
            let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return d1 < d2
        }
        
        var currentSize = totalCacheSize()
        for file in sorted where currentSize > limit {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            try? fileManager.removeItem(at: file)
            currentSize -= Int64(size)
        }
    }
}
```

### 6.9 本地历史记录

```swift
import Foundation

@Observable
class HistoryManager {
    static let shared = HistoryManager()
    
    private(set) var history: [WatchHistory] = []
    private let maxItems = 50
    private let storageKey = "bili_watch_history"
    
    init() { load() }
    
    func addToHistory(video: BiliVideo) {
        // 去重
        history.removeAll { $0.bvid == video.bvid }
        
        let item = WatchHistory(
            bvid: video.bvid,
            title: video.title,
            cover: video.pic,
            upName: video.owner.name,
            duration: video.duration,
            progress: 0,
            watchedAt: Date()
        )
        
        history.insert(item, at: 0)
        if history.count > maxItems { history.removeLast() }
        save()
    }
    
    func updateProgress(bvid: String, progress: Int) {
        guard let idx = history.firstIndex(where: { $0.bvid == bvid }) else { return }
        history[idx].progress = progress
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([WatchHistory].self, from: data)
        else { return }
        history = items
    }
}
```

### 6.10 主入口 & TabView

```swift
import SwiftUI

@main
struct BiliWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(0)
            
            SearchView()
                .tag(1)
            
            MeView()
                .tag(2)
        }
        .tabViewStyle(.verticalPage)   // watchOS 10+ 垂直分页
    }
}

// MARK: - 我的页面
struct MeView: View {
    @State private var history = HistoryManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                // 历史记录
                Section("最近观看") {
                    if history.history.isEmpty {
                        Text("暂无记录").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(history.history.prefix(5)) { item in
                            NavigationLink {
                                VideoDetailLoadingView(bvid: item.bvid)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(2)
                                    HStack(spacing: 4) {
                                        Text(item.upName)
                                        if item.progress > 0 {
                                            Text("· 看到\(item.progress / 60):\(String(format: "%02d", item.progress % 60))")
                                        }
                                    }
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // 缓存管理
                Section("设置") {
                    NavigationLink {
                        CacheSettingsView()
                    } label: {
                        Label("缓存管理", systemImage: "internaldrive")
                            .font(.system(size: 13))
                    }
                }
            }
            .navigationTitle("我的")
        }
    }
}

// MARK: - 从 bvid 加载详情的过渡页
struct VideoDetailLoadingView: View {
    let bvid: String
    @State private var video: BiliVideo?
    @State private var error: String?
    
    var body: some View {
        Group {
            if let video = video {
                VideoDetailView(video: video)
            } else if let error = error {
                VStack {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Button("重试") { Task { await load() } }
                }
            } else {
                ProgressView("加载中...")
            }
        }
        .task { await load() }
    }
    
    private func load() async {
        do {
            video = try await BiliService().fetchVideoDetail(bvid: bvid)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### 6.11 WatchConnectivity (iPhone 配合)

```swift
// Watch 端
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable = false
    @Published var loginCookies: [String: String]?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // 请求 iPhone 登录
    func requestLogin() {
        WCSession.default.sendMessage(
            ["action": "requestLogin"],
            replyHandler: nil
        )
    }
    
    // 接收 iPhone 传来的登录凭证
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let cookies = message["loginCookies"] as? [String: String] {
            DispatchQueue.main.async {
                self.loginCookies = cookies
                // 存储到 AuthManager
            }
        }
    }
    
    // 请求 iPhone 缓存视频并传输
    func requestVideoCache(bvid: String, url: String) {
        WCSession.default.sendMessage(
            ["action": "cacheVideo", "bvid": bvid, "url": url],
            replyHandler: nil
        )
    }
    
    // WCSessionDelegate required
    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.isReachable = s.isReachable }
    }
}
```

```swift
// iPhone Companion 端 (简要)
class PhoneConnectivityManager: NSObject, WCSessionDelegate {
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        
        switch action {
        case "requestLogin":
            // 展示 BiliBili 登录二维码 UI
            NotificationCenter.default.post(name: .showLoginQR, object: nil)
            
        case "cacheVideo":
            // 下载视频并通过 WCSession.transferFile 传输到 Watch
            if let url = message["url"] as? String, let bvid = message["bvid"] as? String {
                downloadAndTransfer(bvid: bvid, urlString: url)
            }
            
        default: break
        }
    }
    
    private func downloadAndTransfer(bvid: String, urlString: String) {
        // 下载视频 → 存到临时文件 → WCSession.default.transferFile(fileURL, metadata:)
    }
    
    // Required delegates...
    func session(_ s: WCSession, activationDidCompleteWith: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
}
```

---

## 七、开发计划与里程碑

```
┌─────────────────────────────────────────────────────────────────┐
│  Phase 1 · MVP (预计 2-3 周)                                     │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐                       │
│  │ 推荐/热门 │  │   搜索    │  │  视频播放  │                       │
│  │  列表浏览 │  │ 语音/手写 │  │  AVPlayer │                       │
│  └─────────┘  └──────────┘  └──────────┘                       │
│  + 网络层 + 数据模型 + 基础UI组件                                   │
├─────────────────────────────────────────────────────────────────┤
│  Phase 2 · 增强 (预计 2 周)                                      │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │ 评论查看 │  │  UP主主页 │  │ 本地历史  │  │ 视频缓存  │         │
│  └─────────┘  └──────────┘  └──────────┘  └──────────┘         │
│  + Wbi签名 + 缓存管理 + 进度记忆                                   │
├─────────────────────────────────────────────────────────────────┤
│  Phase 3 · 完整 (预计 2-3 周)                                    │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │ 扫码登录 │  │  收藏夹   │  │ 云端历史  │  │  动态     │         │
│  │(iPhone辅助)│ │ (需登录) │  │ (需登录)  │  │ (需登录)  │         │
│  └─────────┘  └──────────┘  └──────────┘  └──────────┘         │
│  + WatchConnectivity + iPhone Companion App                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 八、关键技术难点与解决方案

### 8.1 视频格式兼容性

| 问题 | 方案 |
|------|------|
| BiliBili 默认返回 FLV 格式 | 使用 `platform=html5` 参数请求 MP4 格式 |
| DASH 分离流需合并 | 优先使用 durl 合并流；DASH 做 fallback |
| CDN 返回 403 | **必须** 设置 `Referer` 和 `User-Agent` Header |
| 高清需要登录 | 360P/480P 无需登录，完全够用 (Watch 屏幕小) |

### 8.2 电量与性能优化

```
策略:
├── 视频默认 480P (qn=32)，节省带宽和解码功耗
├── 图片缓存到内存，减少重复网络请求
├── 列表使用 LazyVStack 按需加载
├── 每次加载数量限制 (10条/页)
├── 离开播放器立即释放 AVPlayer
└── 后台不保持网络连接
```

### 8.3 小屏幕交互优化

```
策略:
├── 封面图全宽展示，最大化视觉信息
├── 标题最多2-3行，避免信息过载
├── 使用 Digital Crown 自然滚动
├── 播放器全屏，最大化观看面积
├── 评论限制行数，避免长评刷屏
├── UP主入口简洁明确，一键跳转
└── 搜索支持语音输入，减少打字痛苦
```

### 8.4 网络可靠性

```swift
// 重试机制
func requestWithRetry<T: Codable>(
    _ endpoint: String,
    params: [String: String],
    type: T.Type,
    maxRetries: Int = 2
) async throws -> T {
    var lastError: Error?
    for attempt in 0...maxRetries {
        do {
            if attempt > 0 {
                try await Task.sleep(for: .seconds(Double(attempt)))
            }
            return try await request(endpoint, params: params, type: type)
        } catch {
            lastError = error
            if Task.isCancelled { throw error }
        }
    }
    throw lastError!
}
```

### 8.5 Xcode 项目配置要点

```
1. File → New Project → watchOS → App
2. Watch-only App (或带 Companion, Phase 3 需要)
3. Bundle ID: com.yourname.BiliWatch
4. Deployment Target: watchOS 10.0

Info.plist 添加:
  - NSAppTransportSecurity → NSAllowsArbitraryLoads = YES
    (B站CDN域名较多，逐个添加不现实)

Build Settings:
  - SWIFT_VERSION = 5.9
  - TARGETED_DEVICE_FAMILY = 4 (Watch)

Capabilities:
  - Background Modes → Audio (后台音频播放)
  - Background Modes → Background URL Sessions (后台下载缓存)
```

---

## 九、接口调用速查表

```
功能        HTTP                                                  Auth  Phase
─────────────────────────────────────────────────────────────────────────────
推荐视频    GET /x/web-interface/index/top/rcmd?ps=10              ❌     1
热门视频    GET /x/web-interface/popular?pn=1&ps=10                ❌     1
搜索视频    GET /x/web-interface/search/type?keyword=&search_type=video  ❌  1
视频详情    GET /x/web-interface/view?bvid=                        ❌     1
播放地址    GET /x/player/playurl?bvid=&cid=&qn=32&platform=html5 ❌     1
评论列表    GET /x/v2/reply/main?type=1&oid=&mode=3               ❌     2
UP主信息    GET /x/space/wbi/acc/info?mid=              (Wbi签名)  ❌     2
UP主视频    GET /x/space/wbi/arc/search?mid=&pn=1       (Wbi签名)  ❌     2
生成二维码  GET /x/passport-login/web/qrcode/generate              ❌     3
轮询登录    GET /x/passport-login/web/qrcode/poll?qrcode_key=     ❌     3
收藏列表    GET /x/v3/fav/folder/created/list-all?up_mid=         ✅     3
收藏内容    GET /x/v3/fav/resource/list?media_id=&pn=1            ✅     3
历史记录    GET /x/web-interface/history/cursor                    ✅     3
用户动态    GET /x/polymer/web-dynamic/v1/feed/space?host_mid=    ❌     3
─────────────────────────────────────────────────────────────────────────────
Base URL: https://api.bilibili.com
所有请求须带: Referer: https://www.bilibili.com
```

---

> **总结**: Phase 1 聚焦 **推荐 + 搜索 + 播放** 三大核心闭环，保证 Apple Watch 上"发现内容→找到想看的→直接播放"的完整体验。后续迭代逐步丰富社交功能（评论/UP主）和个人功能（登录/收藏/历史），始终以**手腕场景下的轻量、快捷**为设计原则。
