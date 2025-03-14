import SwiftUI
import SwiftData

struct ArticleListView: View {
    @StateObject private var viewModel: ArticleViewModel
    var source: RSSSource?
    
    init(repository: RSSRepositoryProtocol, source: RSSSource? = nil) {
        _viewModel = StateObject(wrappedValue: ArticleViewModel(repository: repository))
        self.source = source
    }
    
    init(source: RSSSource? = nil) {
        // 这里需要在实际应用中注入正确的repository
        // 这是一个简化的初始化方法，实际应用中应使用依赖注入
        let modelContainer = try! ModelContainer(for: RSSSource.self, Article.self, KeywordGroup.self)
        let repository = RSSRepository(modelContainer: modelContainer)
        _viewModel = StateObject(wrappedValue: ArticleViewModel(repository: repository))
        self.source = source
    }
    
    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView("加载中...")
            } else if viewModel.articles.isEmpty {
                Text("没有文章")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.articles) { article in
                    NavigationLink(destination: ArticleDetailView(article: article, viewModel: viewModel)) {
                        ArticleRowView(article: article)
                    }
                }
            }
        }
        .navigationTitle(source?.title ?? "所有文章")
        .toolbar {
            if let source = source {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        refreshFeed()
                    }) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .refreshable {
            refreshFeed()
        }
        .onAppear {
            viewModel.loadArticles(for: source)
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    private func refreshFeed() {
        if let source = source {
            Task {
                await viewModel.refreshFeed(for: source)
            }
        } else {
            viewModel.loadArticles()
        }
    }
}

struct ArticleRowView: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(article.isRead ? .secondary : .primary)
            
            if let author = article.author, !author.isEmpty {
                Text("作者: \(author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let date = article.publishDate {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let summary = article.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if article.isRead {
                    Text("已读")
                        .font(.caption)
                        .padding(4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if article.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                if article.readingProgress > 0 {
                    ProgressView(value: article.readingProgress, total: 1.0)
                        .frame(width: 50)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ArticleDetailView: View {
    let article: Article
    @ObservedObject var viewModel: ArticleViewModel
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                HStack {
                    if let author = article.author, !author.isEmpty {
                        Text("作者: \(author)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let date = article.publishDate {
                        Text(date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                if let content = article.content {
                    Text(try! AttributedString(markdown: content))
                } else if let summary = article.summary {
                    Text(try! AttributedString(markdown: summary))
                } else {
                    Text("无内容")
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Spacer()
            }
            .padding()
            .background(GeometryReader { geo in
                Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
            })
            .background(GeometryReader { geo in
                Color.clear.preference(key: ContentHeightPreferenceKey.self, value: geo.size.height)
            })
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
            updateReadingProgress()
        }
        .onPreferenceChange(ContentHeightPreferenceKey.self) { value in
            contentHeight = value
            updateReadingProgress()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.toggleFavorite(article)
                }) {
                    Image(systemName: article.isFavorite ? "star.fill" : "star")
                        .foregroundColor(article.isFavorite ? .yellow : .primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Link(destination: article.link) {
                    Image(systemName: "safari")
                }
            }
        }
        .onAppear {
            if !article.isRead {
                viewModel.markAsRead(article)
            }
        }
    }
    
    private func updateReadingProgress() {
        guard contentHeight > 0 else { return }
        
        // 计算阅读进度
        let visibleHeight = UIScreen.main.bounds.height
        let totalScrollableHeight = contentHeight - visibleHeight
        
        if totalScrollableHeight <= 0 {
            // 内容不需要滚动，直接标记为已读完
            viewModel.updateReadingProgress(article, progress: 1.0)
        } else {
            // 计算滚动进度
            let progress = min(1.0, max(0.0, -scrollOffset / totalScrollableHeight))
            viewModel.updateReadingProgress(article, progress: progress)
        }
    }
}

// 用于跟踪滚动位置的PreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// 用于测量内容高度的PreferenceKey
struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
