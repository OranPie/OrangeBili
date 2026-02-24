import SwiftUI

struct ContentView: View {
    private enum Tab: String, CaseIterable {
        case home = "首页"
        case search = "搜索"
        case history = "工具"
        case me = "我的"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .history: return "wrench.and.screwdriver.fill"
            case .me: return "person.fill"
            }
        }
    }

    @State private var selectedTab: Tab = .home
    @State private var barCollapsed = false
    @StateObject private var searchViewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .search:
                    SearchView(viewModel: searchViewModel)
                case .history:
                    HistoryView()
                case .me:
                    MeView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 4) {
            if barCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        barCollapsed = false
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 16)
                        .background(.black.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(tab.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .padding(.vertical, 2)
                            .foregroundStyle(selectedTab == tab ? Color.black : Color.white)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == tab ? Color.white : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 5)
                .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 10))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        barCollapsed = true
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(height: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}
