import SwiftUI

struct MeView: View {
    @EnvironmentObject private var render: RenderSettings
    @EnvironmentObject private var apiBackend: BiliAPIBackend

    var body: some View {
        List {
            Section("账号（实验性）") {
                NavigationLink("Watch 扫码登录") {
                    QRLoginExperimentalView()
                }
                if let mid = apiBackend.loggedInMid {
                    NavigationLink("我的主页") {
                        UploaderView(mid: mid)
                    }
                    NavigationLink("我的关注") {
                        FollowingListView()
                    }
                    NavigationLink("云端收藏夹") {
                        CloudFavoritesView()
                    }
                    Button("退出登录", role: .destructive) {
                        Task { await apiBackend.clearLoginSession() }
                    }
                }
                NavigationLink("主页浏览历史") {
                    UploaderVisitHistoryView()
                }
                Text(apiBackend.isLoggedIn ? "登录状态：已登录（可选增强）" : "登录状态：未登录（当前接口可匿名访问）")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("未登录优先走非登录接口；登录后优先增强接口。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("渲染设置") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("字号缩放 \(String(format: "%.2f", render.textScale))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $render.textScale, in: 0.65 ... 1.35, step: 0.05)
                }

                Toggle("紧凑信息布局", isOn: $render.compactStats)

                HStack(spacing: 8) {
                    Text("简介行数")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        if render.detailDescriptionLines > 2 {
                            render.detailDescriptionLines -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)

                    Text("\(render.detailDescriptionLines)")
                        .font(.caption2)
                        .frame(minWidth: 16)

                    Button {
                        if render.detailDescriptionLines < 8 {
                            render.detailDescriptionLines += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("评论字号 \(String(format: "%.2f", render.commentTextScale))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $render.commentTextScale, in: 0.65 ... 1.4, step: 0.05)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("卡片缩放 \(String(format: "%.2f", render.videoCardScale))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $render.videoCardScale, in: 0.75 ... 1.05, step: 0.05)
                }
            }

            Section("关于") {
                NavigationLink("视频功能面板") {
                    VideoFeatureCompactView()
                }
                NavigationLink("关于 OrangeBili") {
                    AboutView()
                }
                Text("查看版本、功能说明与排障指南")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11))
        .navigationTitle("我的")
        .task {
            await apiBackend.refreshAuthState()
        }
    }
}
