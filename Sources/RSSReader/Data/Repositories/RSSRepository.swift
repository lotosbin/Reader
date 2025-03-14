import Foundation
import SwiftData

protocol RSSRepositoryProtocol {
    func addRSSSource(_ source: RSSSource) throws
    func updateRSSSource(_ source: RSSSource) throws
    func deleteRSSSource(_ source: RSSSource) throws
    func getRSSSources() throws -> [RSSSource]
    func addArticle(_ article: Article, to source: RSSSource) throws
    func updateArticle(_ article: Article) throws
    func deleteArticle(_ article: Article) throws
    func getArticles(for source: RSSSource?) throws -> [Article]
    func discoverFeeds(from websiteURL: URL) async throws -> [URL]
    func fetchFeed(from url: URL) async throws -> RSSFeed
}

class RSSRepository: RSSRepositoryProtocol {
    private let modelContainer: ModelContainer
    private let dataSource: RSSDataSourceProtocol
    
    init(modelContainer: ModelContainer, dataSource: RSSDataSourceProtocol = RSSDataSource()) {
        self.modelContainer = modelContainer
        self.dataSource = dataSource
    }
    
    func addRSSSource(_ source: RSSSource) throws {
        let context = modelContainer.mainContext
        context.insert(source)
        try context.save()
    }
    
    func updateRSSSource(_ source: RSSSource) throws {
        try modelContainer.mainContext.save()
    }
    
    func deleteRSSSource(_ source: RSSSource) throws {
        let context = modelContainer.mainContext
        context.delete(source)
        try context.save()
    }
    
    func getRSSSources() throws -> [RSSSource] {
        let descriptor = FetchDescriptor<RSSSource>(sortBy: [SortDescriptor(\.title)])
        return try modelContainer.mainContext.fetch(descriptor)
    }
    
    func addArticle(_ article: Article, to source: RSSSource) throws {
        let context = modelContainer.mainContext
        article.source = source
        source.articles.append(article)
        context.insert(article)
        try context.save()
    }
    
    func updateArticle(_ article: Article) throws {
        try modelContainer.mainContext.save()
    }
    
    func deleteArticle(_ article: Article) throws {
        let context = modelContainer.mainContext
        context.delete(article)
        try context.save()
    }
    
    func getArticles(for source: RSSSource? = nil) throws -> [Article] {
        var descriptor: FetchDescriptor<Article>
        
        if let source = source {
            descriptor = FetchDescriptor<Article>(
                predicate: #Predicate { $0.source == source },
                sortBy: [SortDescriptor(\.publishDate, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Article>(
                sortBy: [SortDescriptor(\.publishDate, order: .reverse)]
            )
        }
        
        return try modelContainer.mainContext.fetch(descriptor)
    }
    
    func discoverFeeds(from websiteURL: URL) async throws -> [URL] {
        return try await dataSource.discoverFeed(from: websiteURL)
    }
    
    func fetchFeed(from url: URL) async throws -> RSSFeed {
        return try await dataSource.fetchFeed(from: url)
    }
}
