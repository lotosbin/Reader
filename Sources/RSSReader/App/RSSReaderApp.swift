import SwiftUI
import SwiftData

@main
struct RSSReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [RSSSource.self, Article.self, KeywordGroup.self])
    }
}
