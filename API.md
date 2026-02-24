

# 哔哩哔哩 API 综合参考文档


B站API采用C/S架构，大多数接口为REST API和gRPC，少部分接口使用WebSocket；REST API接口请求数据格式通常为URL Query参数或JSON，返回数据格式通常为JSON或Protobuf，强制使用HTTPS协议。[[5]](https://github.com/chenshd/bilibili-api-collect)

本项目旨在对B站Web端、移动端以及TV端散落在世界各地的野生API进行收集整理，研究使用方法并对其进行说明，运用了黑箱法、控制变量法、JS逆向分析法、网络抓包法等研究办法。[[2]](https://app.readthedocs.org/projects/bilibili-api-collect/)

---

## 二、鉴权体系

### 2.1 Wbi 签名鉴权（2023年3月起）

自2023年3月起，Bilibili Web端部分接口开始采用WBI签名鉴权，表现在REST API请求时在Query param中添加了 `w_rid` 和 `wts` 字段。WBI签名鉴权独立于APP鉴权与其他Cookie鉴权，目前被认为是一种Web端风控手段。[[1]](https://socialsisteryi.github.io/bilibili-API-collect/docs/misc/sign/wbi.html)

经持续观察，大部分查询性接口都已经或准备采用WBI签名鉴权，请求WBI签名鉴权接口时，若签名参数 `w_rid` 与时间戳 `wts` 缺失、错误，会返回 `v_voucher`。[[2]](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/sign/wbi.md)

**签名流程：**

1. 从 nav 接口中获取 `img_url`、`sub_url` 两个字段的参数。注：这两个字段的值看似为存于BFS中的png图片url，实则只是经过伪装的实时Token，故无需且不能试图访问这两个url。[[1]](https://socialsisteryi.github.io/bilibili-API-collect/docs/misc/sign/wbi.html)
2. 截取其文件名，分别记为 `img_key`、`sub_key`。
3. 将 `img_key + sub_key` 拼合，通过特定的64位编码表（`mixinKeyEncTab`）打乱顺序，取前32位得到 `mixin_key`。
4. 将请求参数添加 `wts`（当前时间戳），按键名升序排序，过滤 value 中的 `!'()*` 字符。
5. 按键名升序排序后编码URL Query，拼接前面得到的 `mixin_key`，计算其MD5即为 `w_rid`。需要注意的是：如果参数值含中文或特殊字符等，编码字符字母应当大写。[[5]](https://github.com/SocialSisterYi/bilibili-API-collect/issues/919)

**注意事项：**
- 部分接口存在故意的脏数据污染（JSON Response错误码为0但是data只包含 `v_voucher` 之类的内容），部分接口使用各自特定的 `img_key`、`sub_key`（可能被硬编码在js文件内），而不是nav接口拿到的。[[5]](https://github.com/SocialSisterYi/bilibili-API-collect/issues/919)

### 2.2 Cookie 鉴权

Cookie中的关键字段：

| 字段 | 说明 | 获取方式 |
|------|------|----------|
| `SESSDATA` | 用户登录态凭证 | 登录成功后 Set-Cookie |
| `bili_jct` | CSRF Token，POST请求必须携带 | 登录成功后 Set-Cookie |
| `buvid3` | 设备唯一标识，搜索等接口必须 | 访问B站或调用 `/x/frontend/finger/spi` |
| `DedeUserID` | 用户UID | 登录成功后 Set-Cookie |
| `buvid4` | 设备标识(新) | 调用 `/x/frontend/finger/spi` |

### 2.3 APP 鉴权（早期/移动端）

早期请求地址为 `http://api.bilibili.com/` 开头，只支持GET方法。请求时必须设置UserAgent，格式必须为：`程序英文名称/版本 (联系邮箱)`，把接口所需所有参数拼接，按参数名称排序，最后再拼接上密钥App-Secret，做MD5加密。[[7]](https://qinshixixing.gitbooks.io/bilibiliapi/content/)

### 2.4 Cookie 刷新机制

Cookie不会自动刷新，需手动调用刷新接口。流程为：检查是否需刷新（`/x/passport-login/web/cookie/info`）→ 生成 CorrespondPath → 获取 `refresh_csrf` → 刷新Cookie → 确认更新 → SSO站点跨域登录。

---

## 三、视频相关 API

### 3.1 获取视频详细信息

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/web-interface/view` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录（登录可获取更多信息） |
| **Wbi** | 不需要 |
| **时代** | 现行 |

**请求参数：**

| 参数名 | 类型 | 说明 | 备注 | 必要性 |
|--------|------|------|------|--------|
| `aid` | num | 稿件avid | 与bvid任选其一 | 必要 |
| `bvid` | str | 稿件bvid | 与aid任选其一 | 必要 |

**返回结果（data 对象主要字段）：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `bvid` | str | BV号 |
| `aid` | num | AV号 |
| `videos` | num | 分P数量 |
| `tid` | num | 分区ID |
| `tname` | str | 分区名称 |
| `copyright` | num | 版权标志（1=自制，2=转载） |
| `pic` | str | 封面URL |
| `title` | str | 标题 |
| `pubdate` | num | 发布时间戳 |
| `desc` | str | 简介 |
| `duration` | num | 总时长(秒) |
| `owner` | obj | UP主信息（mid, name, face） |
| `stat` | obj | 状态数（view, danmaku, reply, favorite, coin, share, like） |
| `pages` | array | 分P列表 |
| `subtitle` | obj | 字幕信息 |

一般是以 `https://api.bilibili.com/x/web-interface/view` 开头的请求。[[5]](https://blog.csdn.net/h979985773/article/details/104237576)

### 3.2 获取视频详细信息（Wbi版）

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/web-interface/wbi/view` |
| **方法** | GET |
| **鉴权** | 🟡 登录可选 |
| **Wbi** | ✅ 需要 `w_rid` + `wts` |
| **时代** | 2023+ |

参数同上，额外需要 `w_rid` 和 `wts`。缺少签名参数会在数次请求后返回 `-403` 风控错误。

### 3.3 获取视频播放器信息

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/player/wbi/v2` |
| **方法** | GET |
| **鉴权** | 🟡 登录可选 |
| **Wbi** | ✅ 需要 |
| **时代** | 2023+（旧版 `/x/player/v2`） |

Web播放器的信息接口，提供正常播放需要的元数据，包括：智能防挡弹幕、字幕、章节看点等。[[3]](https://socialsisteryi.github.io/bilibili-API-collect/docs/video/player.html)

**请求参数：**

| 参数名 | 类型 | 说明 | 必要性 |
|--------|------|------|--------|
| `aid` | num | 稿件avid | 可选（与bvid二选一） |
| `bvid` | str | 稿件bvid | 可选 |
| `cid` | num | 视频cid | 必要 |
| `season_id` | num | 番剧season_id | 非必要 |
| `ep_id` | num | 剧集ep_id | 非必要 |

**返回结果主要字段：** `aid`, `bvid`, `cid`, `ip_info`（IP地理位置）, `login_mid`（当前登录用户UID，未登录为0）, `level_info`, `vip`, `subtitle`（字幕列表）, `view_point`（章节看点）, `dm_mask`（智能防挡弹幕）等。

### 3.4 获取视频流URL（Web端）

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/player/wbi/playurl` |
| **方法** | GET |
| **鉴权** | 🟡 登录可选（高画质需登录/大会员） |
| **Wbi** | ✅ 需要 |
| **时代** | 2023+（旧版 `/x/player/playurl`） |

获取720P及以上清晰度视频时需要登录（Cookie）；获取高帧率（1080P60）/ 高码率（1080P+）/ HDR / 杜比视界视频时需要有大会员的账号登录。获取url有效时间为120min，超时失效需要重新获取。[[7]](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/video/videostream_url.md)

**请求参数：**

| 参数名 | 类型 | 说明 | 备注 | 必要性 |
|--------|------|------|------|--------|
| `avid` | num | 稿件avid | 与bvid二选一 | 必要 |
| `bvid` | str | 稿件bvid | 与avid二选一 | 必要 |
| `cid` | num | 视频cid | | 必要 |
| `qn` | num | 清晰度 | 见下表 | 非必要 |
| `fnval` | num | 视频流格式 | 1=mp4, 16=dash | 非必要 |
| `fnver` | num | 恒为0 | | 非必要 |
| `fourk` | num | 是否允许4K | 0=否, 1=是 | 非必要 |

**清晰度qn值对照表：**

| qn | 清晰度 | 需要登录 | 需要大会员 |
|----|--------|---------|-----------|
| 6 | 240P | ❌ | ❌ |
| 16 | 360P | ❌ | ❌ |
| 32 | 480P | ❌ | ❌ |
| 64 | 720P | ✅ | ❌ |
| 74 | 720P60 | ✅ | ❌ |
| 80 | 1080P | ✅ | ❌ |
| 112 | 1080P+ | ✅ | ✅ |
| 116 | 1080P60 | ✅ | ✅ |
| 120 | 4K | ✅ | ✅ |
| 125 | HDR | ✅ | ✅ |
| 126 | 杜比视界 | ✅ | ✅ |
| 127 | 8K | ✅ | ✅ |

### 3.5 视频操作接口（均需登录）

| 操作 | URL | 方法 | 鉴权 | 关键参数 |
|------|-----|------|------|----------|
| 点赞 | `/x/web-interface/archive/like` | POST | 🔴 必须登录 | `aid`, `like`(1=赞/2=取消), `csrf` |
| 投币 | `/x/web-interface/coin/add` | POST | 🔴 必须登录 | `aid`, `multiply`(1或2), `select_like`(同时点赞), `csrf` |
| 收藏 | `/x/v3/fav/resource/deal` | POST | 🔴 必须登录 | `rid`(avid), `type`(2=视频), `add_media_ids`, `del_media_ids`, `csrf` |
| 一键三连 | `/x/web-interface/archive/like/triple` | POST | 🔴 必须登录 | `aid`, `csrf` |

> 💡 所有POST操作接口均需要Cookie中的 `SESSDATA` 和 `bili_jct`（作为csrf参数）。

### 3.6 视频播放上报

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/v2/history/report` |
| **方法** | POST |
| **鉴权** | 🔴 必须登录（APP或Cookie） |

认证方式：APP或Cookie（SESSDATA）。正文参数包括 `aid`（必要）, `cid`（必要，用于识别分P）, `progress`（观看进度，单位为秒，默认为0）, `platform`（可为android）, `csrf`（Cookie方式必要）。[[8]](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/video/report.md)

**错误码：** `0`=成功, `-101`=账号未登录, `-111`=csrf校验失败, `-400`=请求错误。

### 3.7 视频心跳上报

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/click-interface/web/heartbeat` |
| **方法** | POST |
| **鉴权** | 🔴 仅Cookie（SESSDATA） |

默认间隔15秒一次，亦可记录播放历史。该接口较为复杂，且参数计算方法均为推测。[[8]](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/video/report.md)参数包括 `aid`, `bvid`, `cid`, `played_time`, `realtime`, `start_ts`, `type`, `dt`, `play_type`, `csrf` 等。

### 3.8 获取视频合集信息

| 属性 | 值 |
|------|-----|
| **URL（旧）** | `https://api.bilibili.com/x/polymer/space/seasons_archives_list` |
| **URL（新）** | `https://api.bilibili.com/x/polymer/web-space/home/seasons_series` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |
| **Wbi** | 可选 |

旧接口不推荐使用，无鉴权验证。参数包括 `mid`（用户mid，必要）, `season_id`（视频合集ID，必要）, `sort_reverse`（排序方式）, `page_num`, `page_size`。[[6]](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/video/collection.md)

### 3.9 获取视频分P列表

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/player/pagelist` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：** `aid`（avid，必要）或 `bvid`。返回各分P的 `cid`, `page`（分P序号）, `part`（标题）, `duration`（时长）等。

### 3.10 【废弃】最早期视频信息接口

| 属性 | 值 |
|------|-----|
| **URL** | `http://api.bilibili.cn/view?id={aid}` |
| **方法** | GET |
| **鉴权** | 需AppKey签名 |
| **时代** | 2012-2017（已完全停用） |

域名为 `api.bilibili.cn`，返回XML/JSON格式，需要 `appkey` + `sign` 参数。

---

## 四、用户相关 API

### 4.1 获取用户详细信息（Wbi版）

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/space/wbi/acc/info` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |
| **Wbi** | ✅ 需要 |
| **时代** | 2023+（旧版 `/x/space/acc/info` 已废弃） |

**请求参数：**

| 参数名 | 类型 | 说明 | 必要性 |
|--------|------|------|--------|
| `mid` | num | 目标用户UID | 必要 |
| `w_rid` | str | Wbi签名 | 必要 |
| `wts` | num | 时间戳 | 必要 |

**返回结果主要字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `mid` | num | 用户UID |
| `name` | str | 昵称 |
| `sex` | str | 性别 |
| `face` | str | 头像URL |
| `sign` | str | 签名 |
| `rank` | num | 等级标识（10000=普通，20000=字幕君，25000=VIP，30000=真·职人） |
| `level` | num | 当前等级（0-6） |
| `official` | obj | 认证信息（role, title） |
| `vip` | obj | 大会员信息（type: 0=无/1=月度/2=年度，status: 0=无/1=有） |
| `fans_badge` | bool | 是否具有粉丝勋章 |
| `live_room` | obj | 直播间信息 |
| `pendant` | obj | 头像挂件 |

### 4.2 获取用户卡片信息

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/web-interface/card` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |
| **Wbi** | 不需要 |

**参数：** `mid`（必要），`photo`（bool，是否返回头图）。

返回 `card`（mid, name, fans, friend, attention, sign, level_info, vip）, `following`（是否关注）, `archive_count`（投稿数）。

> 💡 GET版不返回注册时间(regtime=0)。约有200次/3分钟频率限制。

### 4.3 获取自己的用户信息（导航栏）

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/web-interface/nav` |
| **方法** | GET |
| **鉴权** | 🔴 必须登录（未登录也可访问获取 wbi_img） |

**参数：** 无。

**返回结果主要字段：** `isLogin`, `mid`, `uname`, `face`, `level_info`, `vip`, `wallet`（bcoin_balance, coupon_balance）, `wbi_img`（`img_url`, `sub_url`，用于Wbi签名）。

> 💡 此接口也是获取Wbi签名密钥的来源。未登录时也可访问，返回 `isLogin: false` 及 `wbi_img`。

### 4.4 批量查询用户信息

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/polymer/pc-electron/v1/user/cards` |
| **方法** | GET |
| **鉴权** | 🔴 必须登录 |

**参数：** `uids`（UID列表，逗号分隔，最多50个）。超过50个返回错误码 `40143`。

### 4.5 关注/取关用户

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/relation/modify` |
| **方法** | POST |
| **鉴权** | 🔴 必须登录 |

**参数：** `fid`（目标UID）, `act`（1=关注, 2=取关, 3=悄悄关注, 5=拉黑, 6=取消拉黑）, `csrf`。

### 4.6 获取用户关系

| 接口 | URL | 说明 |
|------|-----|------|
| 关注列表 | `/x/relation/followings` | 需登录查看非自己的（🔴），自己的无需 |
| 粉丝列表 | `/x/relation/followers` | 🟢 无需登录 |
| 共同关注 | `/x/relation/same/followings` | 🔴 需登录 |
| 关系查询 | `/x/relation` | 🟡 登录可选 |

---

## 五、搜索相关 API

### 5.1 综合搜索（V2）

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/web-interface/wbi/search/all/v2` |
| **方法** | GET |
| **鉴权** | 🟡 登录可选 |
| **Wbi** | ✅ 需要 |
| **额外需求** | ⚠️ 需要Cookie中含 `buvid3`，Referer在 `.bilibili.com` 下 |

**请求参数：**

| 参数名 | 类型 | 说明 | 必要性 |
|--------|------|------|--------|
| `keyword` | str | 搜索关键词（需URL编码） | 必要 |
| `page` | num | 页码（默认1） | 非必要 |
| `page_size` | num | 每页数量（默认42） | 非必要 |

**返回结果主要字段：** `seid`, `page`, `pagesize`, `numResults`, `numPages`, `pageinfo`（各类型结果数量：video, bili_user, live_room, article, photo等）, `result`（结果数组）。

> ⚠️ `w_rid` 和 `wts` 是B站特有的WBI签名。[[10]](https://im.salty.fish/index.php/archives/revengr-bilibili-352.html)此外，User-Agent 也影响风控：如果使用一个常见浏览器的User Agent值，就可以过风控。[[10]](https://im.salty.fish/index.php/archives/revengr-bilibili-352.html)

### 5.2 分类搜索

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/web-interface/search/type` |
| **方法** | GET |
| **鉴权** | 🟡 登录可选 |
| **Wbi** | ✅ 需要 |

**请求参数：**

| 参数名 | 类型 | 说明 | 可选值 | 必要性 |
|--------|------|------|--------|--------|
| `search_type` | str | 搜索类型 | `video`/`media_bangumi`/`media_ft`/`live`/`live_room`/`live_user`/`article`/`topic`/`bili_user`/`photo` | 必要 |
| `keyword` | str | 搜索关键词 | | 必要 |
| `order` | str | 排序方式 | 视频: `totalrank`/`click`/`pubdate`/`dm`/`stow`/`scores`; 用户: `0`/`fans`/`level` | 非必要 |
| `duration` | num | 视频时长 | 0=全部, 1=0-10分, 2=10-30分, 3=30-60分, 4=60分+ | 非必要 |
| `tids` | num | 分区号 | 0=全部 | 非必要 |
| `page` | num | 页码 | | 非必要 |

**错误码：** `-400`=请求错误, `-412`=被拦截, `-1200`=目标类型不存在。

### 5.3 热搜相关

| 接口 | URL | 鉴权 | Wbi |
|------|-----|------|-----|
| 热搜榜(Web) | `/x/web-interface/wbi/search/square` | 🟢 | ✅ |
| 热搜榜(APP) | `https://app.bilibili.com/x/v2/search/trending/ranking` | 🟢 | ❌ |
| 默认搜索词 | `/x/web-interface/wbi/search/default` | 🟢 | ✅ |
| 搜索建议 | `/x/web-interface/search/suggest` | 🟢 | ❌ |

### 5.4 【废弃】早期搜索接口

| 属性 | 值 |
|------|-----|
| **URL** | `http://api.bilibili.cn/search` |
| **时代** | 2012-2017 |
| **鉴权** | 需AppKey + sign |

参数包括 `keyword`, `order`, `pagesize`, `page`, `appkey`, `sign`。

---

## 六、登录相关 API

### 6.1 二维码登录

**申请二维码：**

| 属性 | 值 |
|------|-----|
| **URL** | `https://passport.bilibili.com/x/passport-login/web/qrcode/generate` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

返回 `url`（二维码内容URL）和 `qrcode_key`（扫码密钥）。

**轮询二维码状态：**

| 属性 | 值 |
|------|-----|
| **URL** | `https://passport.bilibili.com/x/passport-login/web/qrcode/poll` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：** `qrcode_key`（来自generate接口）。

**返回 data.code 含义：**

| code | 含义 |
|------|------|
| 86101 | 未扫码 |
| 86090 | 已扫码未确认 |
| 86038 | 二维码过期 |
| 0 | 登录成功 |

> 💡 登录成功后，需从响应的 Set-Cookie 中提取 `SESSDATA`、`bili_jct`、`DedeUserID` 等。

### 6.2 密码登录

| 属性 | 值 |
|------|-----|
| **URL** | `https://passport.bilibili.com/x/passport-login/web/login` |
| **方法** | POST |
| **鉴权** | 🟢 无需登录 |
| **前置条件** | 需先获取人机验证参数并完成极验 |

**参数：** `username`, `password`（RSA加密后）, `keep`, `token`（验证Token）, `challenge`, `validate`, `seccode`（均来自极验）。

> 💡 密码需要RSA公钥加密。30分钟内错误5次会被禁止登录1小时。

### 6.3 短信验证码登录

| 属性 | 值 |
|------|-----|
| **URL** | `https://passport.bilibili.com/x/passport-login/web/login/sms` |
| **方法** | POST |
| **前置条件** | 需先调用发送短信接口 |

**参数：** `cid`（国际区号，86=中国大陆）, `tel`, `code`, `source`(`main_web`), `captcha_key`。

### 6.4 获取人机验证参数

| 属性 | 值 |
|------|-----|
| **URL** | `https://passport.bilibili.com/x/passport-login/captcha` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

返回 `type`(`geetest`), `token`（登录token）, `geetest`（`challenge`, `gt`）。获取到gt和challenge后，需在前端完成极验滑动验证。

### 6.5 Cookie刷新检查

| 属性 | 值 |
|------|-----|
| **URL** | `https://passport.bilibili.com/x/passport-login/web/cookie/info` |
| **方法** | GET |
| **鉴权** | 🔴 必须登录 |

返回 `refresh`（bool，是否需要刷新）, `timestamp`。

---

## 七、直播相关 API

### 7.1 获取直播间信息

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.live.bilibili.com/room/v1/Room/get_info` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：** `room_id`（直播间ID，支持短号）。

**返回主要字段：** `room_id`(真实房间号), `short_id`(短号), `uid`(主播UID), `title`, `live_status`(0=未开播, 1=直播中, 2=轮播中), `area_name`, `online`, `description`, `background`。

### 7.2 直播间初始化

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.live.bilibili.com/room/v1/Room/room_init` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：** `id`（直播间号，可以是短号）。返回真实 `room_id`, `short_id`, `uid`, `live_status`, `is_hidden`, `is_locked`, `encrypted`。

### 7.3 获取直播流地址

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.live.bilibili.com/room/v1/Room/playUrl` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：**

| 参数名 | 类型 | 说明 | 备注 | 必要性 |
|--------|------|------|------|--------|
| `cid` | num | 真实房间号 | 非短号 | 必要 |
| `quality` | num | 清晰度 | 2=流畅, 3=高清, 4=原画 | 非必要 |
| `platform` | str | 平台 | `web`=http-flv, `h5`=hls | 非必要 |

### 7.4 获取直播弹幕WebSocket信息

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：** `id`（直播间号）。返回 `token`（连接Token）和 `host_list`（包含host, port, wss_port, ws_port）。

### 7.5 直播弹幕WebSocket协议

普通未加密的WebSocket连接：`ws://broadcastlv.chat.bilibili.com:2244/sub`。使用SSL的WebSocket连接：`wss://broadcastlv.chat.bilibili.com/sub`。[[3]](https://github.com/lovelyyoshino/Bilibili-Live-API/blob/master/API.WebSocket.md)

**数据包格式：** 封包头部16个字节用于标识数据包的长度及类型，字节序均为大端模式。[[7]](https://daidr.me/archives/code-526.html)

| 偏移 | 长度 | 说明 |
|------|------|------|
| 0 | 4 bytes | 数据包总长度 |
| 4 | 2 bytes | 头部长度（固定16） |
| 6 | 2 bytes | 协议版本（0=JSON, 1=心跳/认证, 2=zlib压缩, 3=brotli压缩） |
| 8 | 4 bytes | 操作码 |
| 12 | 4 bytes | sequence（固定1） |
| 16 | - | 有效负载 |

**操作码：**

| 操作码 | 说明 | 方向 |
|--------|------|------|
| 2 | 心跳 | 客户端→服务端 |
| 3 | 心跳回应（人气值） | 服务端→客户端 |
| 5 | 通知（弹幕等） | 服务端→客户端 |
| 7 | 认证（进入房间） | 客户端→服务端 |
| 8 | 认证回应 | 服务端→客户端 |

客户端建立连接后，需要在5秒内发出加入房间（认证）的数据包，否则会被服务器强制断开连接；30秒要发送一个心跳包。[[7]](https://daidr.me/archives/code-526.html)[[10]](https://www.bilibili.com/read/cv14101053/)

**认证包JSON格式：**

```json
{
  "uid": 0,
  "roomid": 直播间真实ID,
  "protover": 3,
  "buvid": "buvid3值",
  "platform": "web",
  "type": 2,
  "key": "从getDanmuInfo获取的token"
}
```

**常见弹幕cmd类型：** `DANMU_MSG`(弹幕), `SEND_GIFT`(礼物), `COMBO_SEND`(连击礼物), `WELCOME`(欢迎), `ROOM_REAL_TIME_MESSAGE_UPDATE`(粉丝数更新), `SUPER_CHAT_MESSAGE`(SC), `GUARD_BUY`(上舰), `ENTRY_EFFECT`(进场特效)。

### 7.6 获取直播间主播信息

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.live.bilibili.com/live_user/v1/Master/info` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：** `uid`（主播UID）。

---

## 八、弹幕相关 API

### 8.1 获取实时弹幕（protobuf）

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/v2/dm/web/seg.so` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |
| **返回格式** | Protobuf 二进制 |

B站更新了弹幕的加载逻辑，现在是在最开始加载一个protobuf格式文件seg.so，时长大概6分钟。若视频时长大于6分钟，则在播放器里视频时间超过6分钟时加载第2个分片。[[8]](https://blog.csdn.net/malu_record/article/details/133207870)

**参数：**

| 参数名 | 类型 | 说明 | 必要性 |
|--------|------|------|--------|
| `type` | num | 弹幕类型 | 必要（1=视频弹幕） |
| `oid` | num | 视频cid | 必要 |
| `segment_index` | num | 分段序号（从1开始） | 必要 |

**Protobuf解析后字段：** `id`, `progress`(出现时间ms), `mode`(1=滚动, 4=底部, 5=顶部, 6=逆向, 7=精准定位, 8=高级), `fontsize`(25=普通, 36=大), `color`(十进制颜色值), `content`(弹幕内容), `ctime`, `midHash`(用户CRC32 Hash)。

### 8.2 获取历史弹幕

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/v2/dm/web/history/seg.so` |
| **方法** | GET |
| **鉴权** | 🔴 必须登录 |

**参数：** `type`(1), `oid`(cid), `date`(日期，格式 `2023-01-01`)。

### 8.3 【经典】获取弹幕XML

| 属性 | 值 |
|------|-----|
| **URL** | `https://comment.bilibili.com/{cid}.xml` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |
| **时代** | 经典（仍可用） |

直接将cid替换到URL路径中即可。返回gzip压缩的XML数据。

**XML `<d>` 标签 `p` 属性格式：** `出现时间(秒), 模式, 字号, 颜色(十进制), 发送时间戳, 弹幕池(0=普通/1=字幕/2=特殊), 用户CRC32Hash, 弹幕ID`。

### 8.4 发送弹幕

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/v2/dm/post` |
| **方法** | POST |
| **鉴权** | 🔴 必须登录 |

**参数：**

| 参数名 | 类型 | 说明 | 必要性 |
|--------|------|------|--------|
| `type` | num | 1=视频弹幕 | 必要 |
| `oid` | num | 视频cid | 必要 |
| `msg` | str | 弹幕内容 | 必要 |
| `aid` | num | 稿件avid | 必要 |
| `progress` | num | 出现时间(ms) | 必要 |
| `color` | num | 颜色(十进制) | 非必要 |
| `fontsize` | num | 字号(25=普通, 36=大) | 非必要 |
| `mode` | num | 模式(1=滚动, 4=底部, 5=顶部) | 非必要 |
| `csrf` | str | CSRF Token | 必要 |

---

## 九、评论相关 API

### 9.1 获取评论列表

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/v2/reply` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

错误码：`0`=成功, `-400`=请求错误, `-404`=无此项, `12002`=评论区已关闭, `12009`=评论主体的type不合法。[[8]](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/comment/list.md)

**请求参数：**

| 参数名 | 类型 | 说明 | 备注 | 必要性 |
|--------|------|------|------|--------|
| `type` | num | 资源类型 | 见下表 | 必要 |
| `oid` | num | 资源ID | 视频用avid | 必要 |
| `sort` | num | 排序 | 0=按时间, 1=按点赞, 2=按回复 | 非必要 |
| `pn` | num | 页码 | | 非必要 |
| `ps` | num | 每页数量 | 最大20 | 非必要 |
| `nohot` | num | 不显示热评 | 0=显示, 1=不显示 | 非必要 |

**评论区类型type对照表：**

type=17 是动态（纯文字动态 & 分享），type=11是相簿（图片动态），type=12是专栏。[[6]](https://blog.csdn.net/weixin_45734205/article/details/109845427)

| type | 资源类型 |
|------|----------|
| 1 | 视频 |
| 11 | 相簿（图片动态） |
| 12 | 专栏 |
| 14 | 音频 |
| 17 | 动态 |
| 33 | 课程 |

### 9.2 获取评论列表（游标版）

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/v2/reply/main` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

使用游标翻页方式，返回 `cursor`（含 `next`, `prev`, `is_end`, `all_count`, `pagination_reply.next_offset`）。

### 9.3 发送评论

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/v2/reply/add` |
| **方法** | POST |
| **鉴权** | 🔴 必须登录 |

**参数：** `type`, `oid`, `message`（评论内容）, `root`（根评论rpid，回复时填）, `parent`（父评论rpid，回复时填）, `csrf`。

### 9.4 评论操作

| 操作 | URL | 方法 | 关键参数 |
|------|-----|------|----------|
| 点赞 | `/x/v2/reply/action` | POST | `type`, `oid`, `rpid`, `action`(0=取消/1=点赞), `csrf` |
| 点踩 | `/x/v2/reply/hate` | POST | `type`, `oid`, `rpid`, `action`, `csrf` |
| 删除 | `/x/v2/reply/del` | POST | `type`, `oid`, `rpid`, `csrf` |
| 置顶 | `/x/v2/reply/top` | POST | `type`, `oid`, `rpid`, `action`, `csrf` |

---

## 十、动态相关 API

### 10.1 获取用户空间动态

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/space` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：**

| 参数名 | 类型 | 说明 | 必要性 |
|--------|------|------|--------|
| `host_mid` | num | 目标用户UID | 必要 |
| `offset` | str | 偏移值（用于翻页，来自上一页返回） | 非必要 |
| `features` | str | 特性标识 | 非必要 |

部分动态相关接口请求存在 `features` 参数，主要用于控制返回结果中的 `modules` 中的内容。[[4]](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/opus/features.md)

返回 `items`（动态列表，含 `id_str`, `modules`）, `offset`（下一页偏移值）, `has_more`。

### 10.2 获取关注动态流

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all` |
| **方法** | GET |
| **鉴权** | 🔴 必须登录 |

**参数：** `type`(`all`/`video`/`article`), `offset`。

### 10.3 获取动态详情

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/x/polymer/web-dynamic/v1/detail` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：** `id`（动态ID）。

### 10.4 【旧版】获取用户动态

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.vc.bilibili.com/dynamic_svr/v1/dynamic_svr/space_history` |
| **时代** | 旧版（仍部分可用） |

---

## 十一、私信/消息 API

### 11.1 发送私信

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.vc.bilibili.com/web_im/v1/web_im/send_msg` |
| **方法** | POST |
| **鉴权** | 🔴 必须登录 |

错误码包括：`0`=成功, `-101`=账号未登录, `-400`=请求错误, `21007`=消息过长, `21015`=只有绑定手机号才能发送, `21046`=频率太高请在24小时后再发, `21047`=对方主动回复或关注你前最多发送1条消息, `25003`=因对方隐私设置暂无法发送。[[4]](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/message/private_msg.md)

### 11.2 获取会话列表

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.vc.bilibili.com/session_svr/v1/session_svr/get_sessions` |
| **方法** | GET |
| **鉴权** | 🔴 必须登录 |

参数 `session_type=2&sort_rule=2`。也可通过 `fetch_session_msgs` 接口指定 `talker_id` 和 `begin_seqno`/`end_seqno` 获取指定会话消息。[[2]](https://www.bilibili.com/read/cv6251591/)

### 11.3 获取未读消息数

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.vc.bilibili.com/session_svr/v1/session_svr/single_unread` |
| **方法** | GET |
| **鉴权** | 🔴 必须登录 |

返回 `unfollow_unread`, `follow_unread`, `dustbin_unread` 等。

---

## 十二、音频相关 API

### 12.1 获取歌曲信息

| 属性 | 值 |
|------|-----|
| **URL** | `https://www.bilibili.com/audio/music-service-c/web/song/info` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：** `sid`（歌曲ID）。返回 `id`, `uid`, `uname`, `title`, `cover`, `intro`, `duration`, `lyric`(歌词URL), `statistic`(play, collect, comment, share)。

### 12.2 获取音频流URL

| 属性 | 值 |
|------|-----|
| **URL** | `https://www.bilibili.com/audio/music-service-c/web/url` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录（高音质需大会员） |

**参数：** `sid`, `privilege`（0=128K, 1=192K, 2=320K需大会员）。返回 `cdns`（音频流URL数组）, `size`。

---

## 十三、番剧/影视 API

### 13.1 获取番剧详情

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/pgc/view/web/season` |
| **方法** | GET |
| **鉴权** | 🟢 无需登录 |

**参数：** `season_id`（番剧ssid）或 `ep_id`（剧集epid），至少提供一个。

**返回主要字段：** `season_id`, `title`, `cover`, `evaluate`, `episodes`（每集含 ep_id, title, aid, cid, badge）, `stat`(views, danmakus, coins), `rating`(score, count)。

### 13.2 获取番剧播放流

| 属性 | 值 |
|------|-----|
| **URL** | `https://api.bilibili.com/pgc/player/web/playurl` |
| **方法** | GET |
| **鉴权** | 🟡 登录可选（大会员专享内容需大会员） |

**参数：** `avid`, `cid`（必要）, `ep_id`, `qn`, `fnval`。

---

## 十四、排行榜/推荐 API

| 接口名 | URL | 鉴权 | Wbi | 说明 |
|--------|-----|------|-----|------|
| 热门视频 | `/x/web-interface/popular` | 🟢 | ❌ | 参数: `ps`, `pn` |
| 每周必看 | `/x/web-interface/popular/series/one` | 🟢 | ❌ | 参数: `number`(期数) |
| 入站必刷 | `/x/web-interface/popular/precious` | 🟢 | ❌ | 参数: `page_size`, `page` |
| 分区排行 | `/x/web-interface/ranking` | 🟢 | ❌ | 参数: `rid`(分区号), `day`(1/3/7) |
| 首页推荐 | `/x/web-interface/index/top/rcmd` | 🟡 | ✅ | 登录后返回个性化推荐 |

---

## 十五、工具/杂项 API

| 接口名 | URL | 方法 | 鉴权 | 说明 |
|--------|-----|------|------|------|
| 服务器时间戳 | `/x/report/click/now` | GET | 🟢 | 返回 `data.now` |
| 获取buvid | `/x/frontend/finger/spi` | GET | 🟢 | 返回 `b_3`(buvid3), `b_4`(buvid4) |
| 表情列表 | `/x/emote/user/panel/web` | GET | 🟡 | 参数: `business`(`reply`/`dynamic`) |
| 视频分区列表 | `/x/web-interface/archive/type` | GET | 🟢 | 所有分区信息 |
| 检查昵称可用 | `/x/relation/stat` | GET | 🟢 | 参数: `vmid` |

### AV号与BV号互转

B站于2020年3月启用BV号体系。AV号与BV号之间的转换可通过本地算法实现，无需调用API。多个开源库已实现此算法，基于特定的编码表和位运算。

---

## 十六、官方开放平台

"哔哩哔哩开放平台"是一个基于哔哩哔哩强大内容社区生态的开放平台，旨在为机构、UP主和品牌服务商提供基础服务能力、行业定制化解决方案以及个性化服务。由服务使用方的应用程序发起，以Restful风格为主、通过公网HTTP协议调用哔哩哔哩开放平台。[[1]](https://www.explinks.com/api/scd20240709052919a4a3d7)

官方开放平台地址：`https://openhome.bilibili.com/`，提供身份认证、应用接入、集成开发等服务。与本文档中的"野生API"不同，官方开放平台需要申请接入资质。

---

## 十七、常见错误码汇总

| 错误码 | 含义 |
|--------|------|
| 0 | 成功 |
| -1 | 应用程序不存在或已被封禁 |
| -2 | Access Key 错误 |
| -3 | API校验密匙错误 / 系统错误 |
| -4 | 调用方对该Method没有权限 |
| -101 | 账号未登录 |
| -102 | 账号被封停 |
| -111 | csrf校验失败 |
| -400 | 请求错误 |
| -403 | 访问权限不足（风控） |
| -404 | 无此项 |
| -412 | 请求被拦截（风控） |
| -352 | 风控校验失败（需Wbi签名/设备指纹） |
| -799 | 请求过于频繁 |
| 62002 | 稿件不可见 |
| 62004 | 稿件审核中 |

---

## 十八、第三方SDK/工具库

bilibili-api 是一个用Python写的调用Bilibili各种API的库，范围涵盖视频、音频、直播、动态、专栏、用户、番剧等。还附加：AV号与BV号互转、连接直播弹幕Websocket服务器、视频弹幕反查等。[[6]](https://pypi.org/project/bilibili-api/)

主要库列表：

| 语言 | 库名 | 安装方式 |
|------|------|----------|
| Python | bilibili-api-python | `pip install bilibili-api-python` |
| Go | CuteReimu/bilibili | Go Module |
| Kotlin/Java | czp3009/bilibili-api | Maven/Gradle |
| Rust | SpenserCai/rust-video-downloader | Cargo |
| JavaScript | bili-api (npm) | `npm install bili-api` |

---

## 十九、注意事项与最佳实践

1. **User-Agent**：务必使用真实浏览器的UA，否则会触发风控(-352/-412)。
2. **请求频率**：过快请求会导致IP被封或返回-799，建议控制在合理范围内。
3. **Cookie维护**：搜索类接口需要Cookie中含 `buvid3`，建议先访问B站首页获取完整Cookie。
4. **Wbi签名**：大部分查询性接口已强制要求Wbi签名，`img_key` 和 `sub_key` 会定期变化，需动态获取。
5. **Referer**：部分接口需要Referer在 `.bilibili.com` 域名下，下载视频流时需设置Referer为 `https://www.bilibili.com`。
6. **Protobuf解析**：新版弹幕接口返回protobuf二进制数据，需要对应的proto定义文件进行解析。
7. **CSRF Token**：所有POST操作接口均需要 `csrf` 参数，值为Cookie中的 `bili_jct`。

---

> 📚 **参考来源：** [SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect) · [Nemo2011/bilibili-api](https://github.com/Nemo2011/bilibili-api) · [7rikka/bilibili-api-docs](https://github.com/7rikka/bilibili-api-docs) · [Bilibili API 第三方文档](https://qinshixixing.gitbooks.io/bilibiliapi/) · [哔哩哔哩开放平台](https://openhome.bilibili.com/) · [lovelyyoshino/Bilibili-Live-API](https://github.com/lovelyyoshino/Bilibili-Live-API)

---
Learn more:
1. [获取bilibili直播弹幕的WebSocket协议-CSDN博客](https://blog.csdn.net/xfgryujk/article/details/80306776)
2. [WBI 签名 | BAC Document](https://socialsisteryi.github.io/bilibili-API-collect/docs/misc/sign/wbi.html)
3. [哔哩哔哩开放平台API接口介绍及对接 -超全API平台-幂简集成](https://www.explinks.com/api/scd20240709052919a4a3d7)
4. [bilibili-API-collect - Read the Docs Community](https://app.readthedocs.org/projects/bilibili-api-collect/)
5. [GitHub - xfgryujk/blivedm: 获取bilibili直播弹幕，使用WebSocket协议，支持web端和B站直播开放平台两种接口](https://github.com/xfgryujk/blivedm)
6. [bilibili-API-collect/docs/misc/sign/wbi.md at master · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/sign/wbi.md)
7. [程序实现自动回复私信所需（附扫码登录）接口 - 哔哩哔哩](https://www.bilibili.com/read/cv6251591/)
8. [Bilibili API 第三方文档 · bilibiliapi](https://qinshixixing.gitbooks.io/bilibiliapi/)
9. [GitHub - SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
10. [播放器 | BAC Document](https://socialsisteryi.github.io/bilibili-API-collect/docs/video/player.html)
11. [Bilibili-Live-API/API.WebSocket.md at master · lovelyyoshino/Bilibili-Live-API](https://github.com/lovelyyoshino/Bilibili-Live-API/blob/master/API.WebSocket.md)
12. [WBI 签名算法更新 · Issue #885 · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/issues/885)
13. [GitHub - Pieceleaf/bilibili-API-collect: 哔哩哔哩-API收集整理【不断更新中....】](https://github.com/Pieceleaf/bilibili-API-collect)
14. [bilibili-API-collect/docs/opus/features.md at master · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/opus/features.md)
15. [b站直播弹幕获取 nodejs版 上 - 哔哩哔哩](https://www.bilibili.com/read/cv4086432/)
16. [bilibili-API-collect/docs/misc/sign/wbi.md at master · xcg340122/bilibili-API-collect](https://github.com/xcg340122/bilibili-API-collect/blob/master/docs/misc/sign/wbi.md)
17. [bilibili-API-collect/docs/message/private\_msg.md at master · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/message/private_msg.md)
18. [开平管理中心 - 哔哩哔哩开放平台- Bilibili](https://openhome.bilibili.com/doc)
19. [GitHub - chenshd/bilibili-api-collect: Bilibili API Collect](https://github.com/chenshd/bilibili-api-collect)
20. [GitHub - rinnein/bilibili-API-collect: 哔哩哔哩-API收集整理【不断更新中....】](https://github.com/rinnein/bilibili-API-collect)
21. [哔哩哔哩bilibili 部分接口\_哔哩哔哩汅api网站-CSDN博客](https://blog.csdn.net/h979985773/article/details/104237576)
22. [GitHub - czp3009/bilibili-live-api: bilibili 直播弹幕协议 API Java 版(deprecated)](https://github.com/czp3009/bilibili-live-api)
23. [WBI 签名相关问题 · Issue #919 · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/issues/919)
24. [哔哩哔哩开放平台](https://openhome.bilibili.com/)
25. [bilibili-API-collect/docs/video/collection.md at master · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/video/collection.md)
26. [bilibili-api · PyPI](https://pypi.org/project/bilibili-api/)
27. [B站动态评论API详细指南-CSDN博客](https://blog.csdn.net/weixin_45734205/article/details/109845427)
28. [bilibili-api 开发文档](https://nemo2011.github.io/bilibili-api/)
29. [网页端接口大部分都换成wbi，需要w\_rid了 · Issue #631 · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/issues/631)
30. [bilibili-API-collect/docs/video/videostream\_url.md at master · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/video/videostream_url.md)
31. [Bilibili API 第三方文档 · bilibiliapi](https://qinshixixing.gitbooks.io/bilibiliapi/content/)
32. [解锁Bilibili API：从入门到精通的全攻略-CSDN博客](https://blog.csdn.net/ndAbsAfaqwdav/article/details/144296985)
33. [B站直播弹幕ws协议分析 - 戴兜的小屋](https://daidr.me/archives/code-526.html)
34. [Github](https://github.com/SocialSisterYi/bilibili-API-collect/diffs/0?base_sha=11d42851ae07fd95f8af37a354c672f07f999ad2&head_user=stmtc233&name=master&pull_number=1034&qualified_name=refs/heads/master&sha1=11d42851ae07fd95f8af37a354c672f07f999ad2&sha2=ba3ad83261d3f4a74f48cb6ced30a27b537017ba&short_path=59df5fa&unchanged=expanded&w=false)
35. [bilibili-API-collect/docs/video/report.md at master · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/video/report.md)
36. [bilibili-api · GitHub Topics · GitHub](https://github.com/topics/bilibili-api)
37. [bilibili-API-collect/docs/comment/list.md at master · SocialSisterYi/bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/comment/list.md)
38. [Websocket获取B站直播间弹幕教程 — 哔哩哔哩直播开放平台\_b站开放平台-CSDN博客](https://blog.csdn.net/malu_record/article/details/133207870)
39. [GitHub - Miuzarte/Wbi: Bilibili wbi sign / 哔哩哔哩wbi鉴权签名, Standard libraries only / 纯原生库实现](https://github.com/Miuzarte/Wbi)
40. [GitHub：哔哩哔哩的API调用模块\_bilibili是否提供了公开的api-CSDN博客](https://blog.csdn.net/qq_39248703/article/details/108605673)
41. [GitHub - 7rikka/bilibili-api-docs: 自己整理的一些哔哩哔哩接口文档](https://github.com/7rikka/bilibili-api-docs)
42. [哔哩哔哩直播开放文档](https://open-live.bilibili.com/document/doc&tool/api/websocket.html)
43. [bilibili首页推荐视频接口w\_rid、wts参数逆向分析\_b站接口-CSDN博客](https://blog.csdn.net/weixin_52807972/article/details/131700890)
44. [GitHub - alittlehuaji/bilibili-api-collect-mirror: 哔哩哔哩-API收集整理【不断更新中....】](https://github.com/alittlehuaji/bilibili-api-collect-mirror)
45. [【亲测免费】 探秘Bilibili API：一个强大的二次元世界接口工具-CSDN博客](https://blog.csdn.net/gitblog_00041/article/details/138026511)
46. [探索B站API宝藏：SocialSisterYi/bilibili-API-collect-CSDN博客](https://blog.csdn.net/gitblog_00054/article/details/136832931)
47. [使用JavaScript中的WebSocket获取b站直播间弹幕 - BiliBili](https://www.bilibili.com/read/cv14101053/)
48. [浅度剖析B站的新 -352 风控策略 - A Salty Blog](https://im.salty.fish/index.php/archives/revengr-bilibili-352.html)
49. [bilibili-api-python · PyPI](https://pypi.org/project/bilibili-api-python/)
