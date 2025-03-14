import Foundation
import SwiftUI
import SwiftData
import Combine

class ArticleViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: RSSRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: RSSRepositoryProtocol) {
        self.repository = repository
    }
    
    func loadArticles(for source: RSSSource? = nil) {
        isLoading = true
        errorMessage = nil
        
        do {
            articles = try repository.getArticles(for: source)
            isLoading = false
        } catch {
            errorMessage = "加载文章失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func markAsRead(_ article: Article) {
        article.isRead = true
        
        do {
            try repository.updateArticle(article)
        } catch {
            errorMessage = "更新文章状态失败: \(error.localizedDescription)"
        }
    }
    
    func toggleFavorite(_ article: Article) {
        article.isFavorite.toggle()
        
        do {
            try repository.updateArticle(article)
        } catch {
            errorMessage = "更新文章收藏状态失败: \(error.localizedDescription)"
        }
    }
    
    func updateReadingProgress(_ article: Article, progress: Double) {
        article.readingProgress = progress
        
        do {
            try repository.updateArticle(article)
        } catch {
            errorMessage = "更新阅读进度失败: \(error.localizedDescription)"
        }
    }
    
    func refreshFeed(for source: RSSSource) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let feed = try await repository.fetchFeed(from: source.url)
            
            // 处理获取到的文章
            for item in feed.items {
                // 检查文章是否已存在
                let existingArticle = articles.first { article in
                    article.link == item.link
                }
                
                if existingArticle == nil {
                    // 创建新文章
                    let newArticle = Article(
                        title: item.title,
                        link: item.link,
                        content: item.content,
                        summary: item.description,
                        author: item.author,
                        publishDate: item.pubDate
                    )
                    
                    try repository.addArticle(newArticle, to: source)
                }
            }
            
            // 更新源的最后更新时间
            source.lastUpdated = Date()
            try repository.updateRSSSource(source)
            
            // 重新加载文章列表
            loadArticles(for: source)
            
            isLoading = false
        } catch {
            errorMessage = "刷新Feed失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
