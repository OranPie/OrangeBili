import SwiftUI
import OrangeBiliCore

public struct ContentView: View {
    private enum Tab: CaseIterable {
        case home
        case search
        case history
        case me

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .history: return "wrench.and.screwdriver.fill"
            case .me: return "person.fill"
            }
        }

        var title: String {
            switch self {
            case .home: return L10n.t("tab.home")
            case .search: return L10n.t("tab.search")
            case .history: return L10n.t("tab.tools")
            case .me: return L10n.t("tab.me")
            }
        }
    }

    @State private var selectedTab: Tab = .home
    @StateObject private var searchViewModel = SearchViewModel()
    @StateObject private var tabBarState = TabBarState()
    @EnvironmentObject private var toastManager: ToastManager

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
        #if os(watchOS)
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
            .environmentObject(tabBarState)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
        #elseif os(macOS)
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .navigationTitle("OrangeBili")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
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
            .environmentObject(tabBarState)
        }
        #else
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
                    .environmentObject(tabBarState)
            }
            .tabItem { Label(Tab.home.title, systemImage: Tab.home.icon) }
            .tag(Tab.home)

            NavigationStack {
                SearchView(viewModel: searchViewModel)
                    .environmentObject(tabBarState)
            }
            .tabItem { Label(Tab.search.title, systemImage: Tab.search.icon) }
            .tag(Tab.search)

            NavigationStack {
                HistoryView()
                    .environmentObject(tabBarState)
            }
            .tabItem { Label(Tab.history.title, systemImage: Tab.history.icon) }
            .tag(Tab.history)

            NavigationStack {
                MeView()
                    .environmentObject(tabBarState)
            }
            .tabItem { Label(Tab.me.title, systemImage: Tab.me.icon) }
            .tag(Tab.me)
        }
        #endif

            ToastOverlayView()
        }
    }

    #if os(watchOS)
    private var bottomBar: some View {
        VStack(spacing: 2) {
            if tabBarState.isCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tabBarState.isCollapsed = false
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 12)
                        .background(.black.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                if selectedTab == tab {
                                    Text(tab.title)
                                        .font(.system(size: 8, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 24)
                            .padding(.vertical, 1)
                            .foregroundStyle(selectedTab == tab ? Color.black : Color.white)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTab == tab ? Theme.accent : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .trailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            tabBarState.isCollapsed = true
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 2)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
    #endif
}
