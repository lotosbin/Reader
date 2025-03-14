import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            FeedListView()
                .tabItem {
                    Label("订阅", systemImage: "list.bullet")
                }
            
            ArticleListView()
                .tabItem {
                    Label("文章", systemImage: "doc.text")
                }
            
            KeywordGroupsView()
                .tabItem {
                    Label("关键词", systemImage: "tag")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
