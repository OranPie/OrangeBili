import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section("应用信息") {
                infoRow("应用名称", "OrangeBili")
                infoRow("平台", "watchOS")
                infoRow("版本", appVersionText)
                infoRow("构建号", buildText)
            }

            Section("核心功能") {
                bullet("热门、搜索、UP 主视频、评论浏览")
                bullet("详情页显示 BV/UP/统计数据")
                bullet("本地收藏、播放历史、BV 直达")
                bullet("离线缓存(API)与离线下载(视频)分离管理")
                bullet("播放器支持 ±10s、倍速、静音、重播、线路切换")
            }

            Section("数据与网络") {
                bullet("默认优先读取离线缓存，网络成功后自动刷新缓存")
                bullet("搜索/评论/UP 主接口使用 WBI 签名")
                bullet("封面与视频流自动优先使用 HTTPS")
            }

            Section("日志与排障") {
                bullet("全局日志可查看签名、请求、解码、重试过程")
                bullet("出现“couldn't be read”请先清空日志后复现，再反馈最新日志")
                bullet("若播放异常(绿屏/卡顿)，可切换线路后重试")
            }

            Section("说明") {
                Text("OrangeBili 为学习与体验用途，部分能力受接口策略与网络环境影响。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("建议搭配 iPhone Companion 使用，账号状态同步更稳定。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于 OrangeBili")
    }

    private var appVersionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var buildText: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundStyle(.secondary)
                .padding(.top, 5)
            Text(text)
                .font(.caption2)
        }
    }
}
