# iOS RSS阅读应用核心功能实现

本文档详细描述了iOS RSS阅读应用核心RSS功能的实现，包括项目结构、数据模型、RSS源管理、RSS自动发现、内容获取和解析等功能。实现遵循MVVM架构模式和iOS开发最佳实践。

## 1. 项目结构

按照MVVM架构和关注点分离原则，项目结构如下：

```
RSSReader/
├── App/
│   ├── RSSReaderApp.swift
│   └── AppDelegate.swift
├── Data/
│   ├── Models/
│   │   ├── RSSSource.swift
│   │   ├── Article.swift
│   │   ├── KeywordGroup.swift
│   │   └── Discussion.swift
│   ├── DataSources/
│   │   ├── LocalDataSource.swift
│   │   ├── RemoteDataSource.swift
│   │   ├── CoreDataLocalDataSource.swift
│   │   └── FeedKitRemoteDataSource.swift
│   └── Repositories/
│       ├── RSSSourceRepository.swift
│       ├── ArticleRepository.swift
│       ├── KeywordRepository.swift
│       └── DiscussionRepository.swift
├── Domain/
│   └── UseCases/
│       ├── ManageRSSSourcesUseCase.swift
│       ├── ManageArticlesUseCase.swift
│       ├── KeywordAggregationUseCase.swift
│       └── ArticleRelationsUseCase.swift
├── Presentation/
│   ├── ViewModels/
│   │   ├── SourceListViewModel.swift
│   │   ├── ArticleListViewModel.swift
│   │   ├── KeywordGroupViewModel.swift
│   │   └── ArticleDetailViewModel.swift
│   └── Views/
│       ├── MainView.swift
│       ├── SourceListView.swift
│       ├── ArticleListView.swift
│       ├── ArticleDetailView.swift
│       ├── KeywordGroupView.swift
│       └── SettingsView.swift
└── Utils/
    ├── Extensions/
    │   ├── Date+Extensions.swift
    │   ├── String+Extensions.swift
    │   └── URL+Extensions.swift
    ├── Helpers/
    │   ├── NetworkMonitor.swift
    │   ├── ImageCache.swift
    │   └── HTMLParser.swift
    └── DependencyContainer.swift
```

## 2. 数据模型实现

### 2.1 RSSSource.swift

```swift
import Foundation
import CoreData

// MARK: - 数据模型
struct RSSSource: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var url: String
    var iconURL: String?
    var category: String?
    var lastUpdated: Date?
    var isActive: Bool
    
    init(id: UUID = UUID(), title: String, url: String, iconURL: String? = nil, 
         category: String? = nil, lastUpdated: Date? = nil, isActive: Bool = true) {
        self.id = id
        self.title = title
        self.url = url
        self.iconURL = iconURL
        self.category = category
        self.lastUpdated = lastUpdated
        self.isActive = isActive
    }
    
    static func == (lhs: RSSSource, rhs: RSSSource) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Core Data 扩展
extension RSSSource {
    init(from entity: RSSSourceEntity) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.url = entity.url ?? ""
        self.iconURL = entity.iconURL
        self.category = entity.category
        self.lastUpdated = entity.lastUpdated
        self.isActive = entity.isActive
    }
    
    func toEntity(in context: NSManagedObjectContext) -> RSSSourceEntity {
        let entity = RSSSourceEntity(context: context)
        entity.id = self.id
        entity.title = self.title
        entity.url = self.url
        entity.iconURL = self.iconURL
        entity.category = self.category
        entity.lastUpdated = self.lastUpdated
        entity.isActive = self.isActive
        return entity
    }
}
```

### 2.2 Article.swift

```swift
import Foundation
import CoreData

// MARK: - 数据模型
struct Article: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var link: String
    var description: String
    var content: String?
    var author: String?
    var pubDate: Date
    var sourceId: UUID
    var sourceName: String
    var imageURL: String?
    var keywords: [String: Double]?
    var isRead: Bool
    var isFavorite: Bool
    var readingProgress: Double?
    
    init(id: UUID = UUID(), title: String, link: String, description: String, 
         content: String? = nil, author: String? = nil, pubDate: Date, 
         sourceId: UUID, sourceName: String, imageURL: String? = nil, 
         keywords: [String: Double]? = nil, isRead: Bool = false, 
         isFavorite: Bool = false, readingProgress: Double? = nil) {
        self.id = id
        self.title = title
        self.link = link
        self.description = description
        self.content = content
        self.author = author
        self.pubDate = pubDate
        self.sourceId = sourceId
        self.sourceName = sourceName
        self.imageURL = imageURL
        self.keywords = keywords
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.readingProgress = readingProgress
    }
    
    static func == (lhs: Article, rhs: Article) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Core Data 扩展
extension Article {
    init(from entity: ArticleEntity) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.link = entity.link ?? ""
        self.description = entity.articleDescription ?? ""
        self.content = entity.content
        self.author = entity.author
        self.pubDate = entity.pubDate ?? Date()
        self.sourceId = entity.sourceId ?? UUID()
        self.sourceName = entity.sourceName ?? ""
        self.imageURL = entity.imageURL
        
        if let keywordsData = entity.keywords, 
           let keywords = try? JSONDecoder().decode([String: Double].self, from: keywordsData) {
            self.keywords = keywords
        } else {
            self.keywords = nil
        }
        
        self.isRead = entity.isRead
        self.isFavorite = entity.isFavorite
        self.readingProgress = entity.readingProgress
    }
    
    func toEntity(in context: NSManagedObjectContext) -> ArticleEntity {
        let entity = ArticleEntity(context: context)
        entity.id = self.id
        entity.title = self.title
        entity.link = self.link
        entity.articleDescription = self.description
        entity.content = self.content
        entity.author = self.author
        entity.pubDate = self.pubDate
        entity.sourceId = self.sourceId
        entity.sourceName = self.sourceName
        entity.imageURL = self.imageURL
        
        if let keywords = self.keywords, 
           let keywordsData = try? JSONEncoder().encode(keywords) {
            entity.keywords = keywordsData
        }
        
        entity.isRead = self.isRead
        entity.isFavorite = self.isFavorite
        entity.readingProgress = self.readingProgress
        return entity
    }
}
```

## 3. 数据源实现

### 3.1 LocalDataSource.swift

```swift
import Foundation
import Combine
import CoreData

// MARK: - 过滤器
struct ArticleFilters {
    var sourceId: UUID?
    var ids: [UUID]?
    var isRead: Bool?
    var isFavorite: Bool?
    var searchTerm: String?
    var startDate: Date?
    var endDate: Date?
}

// MARK: - 本地数据源协议
protocol LocalDataSource {
    func getSources() -> AnyPublisher<[RSSSource], Error>
    func saveSource(_ source: RSSSource) -> AnyPublisher<RSSSource, Error>
    func deleteSource(_ sourceId: UUID) -> AnyPublisher<Void, Error>
    
    func getArticles(filters: ArticleFilters?) -> AnyPublisher<[Article], Error>
    func saveArticle(_ article: Article) -> AnyPublisher<Article, Error>
    func updateArticleStatus(id: UUID, isRead: Bool?, isFavorite: Bool?, readingProgress: Double?) -> AnyPublisher<Void, Error>
    
    func getKeywordGroups() -> AnyPublisher<[KeywordGroup], Error>
    func saveKeywordGroup(_ group: KeywordGroup) -> AnyPublisher<KeywordGroup, Error>
    
    func getDiscussions(forArticleId: UUID) -> AnyPublisher<[Discussion], Error>
    func saveDiscussion(_ discussion: Discussion) -> AnyPublisher<Discussion, Error>
    
    func getRelatedArticles(forArticleId: UUID, relationType: RelationType?) -> AnyPublisher<[Article], Error>
    func saveArticleRelation(_ relation: ArticleRelation) -> AnyPublisher<ArticleRelation, Error>
}
```

### 3.2 CoreDataLocalDataSource.swift

```swift
import Foundation
import CoreData
import Combine

class CoreDataLocalDataSource: LocalDataSource {
    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - RSS源管理
    
    func getSources() -> AnyPublisher<[RSSSource], Error> {
        return Future<[RSSSource], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "CoreDataLocalDataSource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.backgroundContext.perform {
                let fetchRequest: NSFetchRequest<RSSSourceEntity> = RSSSourceEntity.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
                
                do {
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    let sources = entities.map { RSSSource(from: $0) }
                    promise(.success(sources))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func saveSource(_ source: RSSSource) -> AnyPublisher<RSSSource, Error> {
        return Future<RSSSource, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "CoreDataLocalDataSource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.backgroundContext.perform {
                // 检查是否已存在
                let fetchRequest: NSFetchRequest<RSSSourceEntity> = RSSSourceEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", source.id as CVarArg)
                
                do {
                    let existingEntities = try self.backgroundContext.fetch(fetchRequest)
                    
                    let entity: RSSSourceEntity
                    if let existingEntity = existingEntities.first {
                        // 更新现有实体
                        entity = existingEntity
                        entity.title = source.title
                        entity.url = source.url
                        entity.iconURL = source.iconURL
                        entity.category = source.category
                        entity.lastUpdated = source.lastUpdated
                        entity.isActive = source.isActive
                    } else {
                        // 创建新实体
                        entity = source.toEntity(in: self.backgroundContext)
                    }
                    
                    try self.backgroundContext.save()
                    promise(.success(source))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func deleteSource(_ sourceId: UUID) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "CoreDataLocalDataSource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.backgroundContext.perform {
                let fetchRequest: NSFetchRequest<RSSSourceEntity> = RSSSourceEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", sourceId as CVarArg)
                
                do {
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    
                    for entity in entities {
                        self.backgroundContext.delete(entity)
                    }
                    
                    try self.backgroundContext.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - 文章管理
    
    func getArticles(filters: ArticleFilters?) -> AnyPublisher<[Article], Error> {
        return Future<[Article], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "CoreDataLocalDataSource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.backgroundContext.perform {
                let fetchRequest: NSFetchRequest<ArticleEntity> = ArticleEntity.fetchRequest()
                
                // 构建谓词
                var predicates: [NSPredicate] = []
                
                if let filters = filters {
                    if let sourceId = filters.sourceId {
                        predicates.append(NSPredicate(format: "sourceId == %@", sourceId as CVarArg))
                    }
                    
                    if let ids = filters.ids, !ids.isEmpty {
                        predicates.append(NSPredicate(format: "id IN %@", ids as [CVarArg]))
                    }
                    
                    if let isRead = filters.isRead {
                        predicates.append(NSPredicate(format: "isRead == %@", NSNumber(value: isRead)))
                    }
                    
                    if let isFavorite = filters.isFavorite {
                        predicates.append(NSPredicate(format: "isFavorite == %@", NSNumber(value: isFavorite)))
                    }
                    
                    if let searchTerm = filters.searchTerm, !searchTerm.isEmpty {
                        predicates.append(NSPredicate(format: "title CONTAINS[cd] %@ OR articleDescription CONTAINS[cd] %@", searchTerm, searchTerm))
                    }
                    
                    if let startDate = filters.startDate {
                        predicates.append(NSPredicate(format: "pubDate >= %@", startDate as NSDate))
                    }
                    
                    if let endDate = filters.endDate {
                        predicates.append(NSPredicate(format: "pubDate <= %@", endDate as NSDate))
                    }
                }
                
                if !predicates.isEmpty {
                    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                }
                
                // 排序
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "pubDate", ascending: false)]
                
                do {
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    let articles = entities.map { Article(from: $0) }
                    promise(.success(articles))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func saveArticle(_ article: Article) -> AnyPublisher<Article, Error> {
        return Future<Article, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "CoreDataLocalDataSource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.backgroundContext.perform {
                // 检查是否已存在
                let fetchRequest: NSFetchRequest<ArticleEntity> = ArticleEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", article.id as CVarArg)
                
                do {
                    let existingEntities = try self.backgroundContext.fetch(fetchRequest)
                    
                    let entity: ArticleEntity
                    if let existingEntity = existingEntities.first {
                        // 更新现有实体
                        entity = existingEntity
                        entity.title = article.title
                        entity.link = article.link
                        entity.articleDescription = article.description
                        entity.content = article.content
                        entity.author = article.author
                        entity.pubDate = article.pubDate
                        entity.sourceId = article.sourceId
                        entity.sourceName = article.sourceName
                        entity.imageURL = article.imageURL
                        
                        if let keywords = article.keywords, 
                           let keywordsData = try? JSONEncoder().encode(keywords) {
                            entity.keywords = keywordsData
                        }
                        
                        entity.isRead = article.isRead
                        entity.isFavorite = article.isFavorite
                        entity.readingProgress = article.readingProgress
                    } else {
                        // 创建新实体
                        entity = article.toEntity(in: self.backgroundContext)
                    }
                    
                    try self.backgroundContext.save()
                    promise(.success(article))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func updateArticleStatus(id: UUID, isRead: Bool?, isFavorite: Bool?, readingProgress: Double?) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "CoreDataLocalDataSource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }
            
            self.backgroundContext.perform {
                let fetchRequest: NSFetchRequest<ArticleEntity> = ArticleEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                
                do {
                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    
                    guard let entity = entities.first else {
                        promise(.failure(NSError(domain: "CoreDataLocalDataSource", code: 2, userInfo: [NSLocalizedDescriptionKey: "Article not found"])))
                        return
                    }
                    
                    if let isRead = isRead {
                        entity.isRead = isRead
                    }
                    
                    if let isFavorite = isFavorite {
                        entity.isFavorite = isFavorite
                    }
                    
                    if let readingProgress = readingProgress {
                        entity.readingProgress = readingProgress
                    }
                    
                    try self.backgroundContext.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // 其他方法实现...
}
```

### 3.3 RemoteDataSource.swift

```swift
import Foundation
import Combine
import FeedKit

// MARK: - 远程数据源协议
protocol RemoteDataSource {
    func fetchFeed(from url: String) -> AnyPublisher<RSSFeed, Error>
    func discoverRSSFeeds(from websiteUrl: String) -> AnyPublisher<[String], Error>
}
```

### 3.4 FeedKitRemoteDataSource.swift

```swift
import Foundation
import Combine
import FeedKit

class FeedKitRemoteDataSource: RemoteDataSource {
    
    // MARK: - 获取Feed
    
    func fetchFeed(from url: String) -> AnyPublisher<RSSFeed, Error> {
        return Future<RSSFeed, Error> { promise in
            Task {
                do {
                    guard let feedURL = URL(string: url) else {
                        throw URLError(.badURL)
                    }
                    
                    let feed = try await RSSFeed(url: feedURL)
                    promise(.success(feed))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - RSS自动发现
    
    func discoverRSSFeeds(from websiteUrl: String) -> AnyPublisher<[String], Error> {
        return Future<[String], Error> { promise in
            Task {
                do {
                    guard let url = URL(string: websiteUrl) else {
                        throw URLError(.badURL)
                    }
                    
                    // 1. 尝试从HTML头部发现RSS链接
                    let headFeeds = try await self.discoverFeedsFromHTMLHead(url: url)
                    
                    // 2. 如果头部没有发现，尝试常见路径
                    if headFeeds.isEmpty {
                        let commonPathFeeds = try await self.checkCommonRSSLocations(baseURL: url)
                        promise(.success(commonPathFeeds))
                    } else {
                        promise(.success(headFeeds))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // 从HTML头部发现RSS链接
    private func discoverFeedsFromHTMLHead(url: URL) async throws -> [String] {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "HTMLParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML"])
        }
        
        // 使用正则表达式查找RSS链接
        let pattern = "<link[^>]*rel=[\"']alternate[\"'][^>]*type=[\"']application/(?:rss|atom)\\+xml[\"'][^>]*href=[\"']([^\"']+)[\"'][^>]*>"
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let matches = regex.matches(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.utf16.count))
        
        // 提取URL
        var feedURLs: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: htmlString) {
                let urlString = String(htmlString[range])
                if let feedURL = URL(string: urlString, relativeTo: url) {
                    feedURLs.append(feedURL.absoluteString)
                }
            }
        }
        
        return feedURLs
    }
    
    // 检查常见的RSS路径
    private func checkCommonRSSLocations(baseURL: URL) async throws -> [String] {
        let commonPaths = ["/feed", "/rss", "/feed.xml", "/rss.xml", "/atom.xml", "/feed/", "/rss/", "/index.xml"]
        var discoveredFeeds: [String] = []
        
        for path in commonPaths {
            if let feedURL = URL(string: path, relativeTo: baseURL) {
                do {
                    let (_, response) = try await URLSession.shared.data(from: feedURL)
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200,
                       let mimeType = httpResponse.mimeType,
                       (mimeType.contains("xml") || mimeType.contains("rss") || mimeType.contains("atom")) {
                        discoveredFeeds.append(feedURL.absoluteString)
                    }
                } catch {
                    // 忽略错误，继续检查下一个位置
                    continue
                }
            }
        }
        
        return discoveredFeeds
    }
}
```

## 4. 仓库实现

### 4.1 RSSSourceRepository.swift

```swift
import Foundation
import Combine

// MARK: - 仓库协议
protocol RSSSourceRepository {
    func getSources() -> AnyPublisher<[RSSSource], Error>
    func addSource(_ source: RSSSource) -> AnyPublisher<RSSSource, Error>
    func deleteSource(_ sourceId: UUID) -> AnyPublisher<Void, Error>
    func discoverRSSFeeds(from websiteUrl: String) -> AnyPublisher<[String], Error>
}

// MARK: - 默认实现
class DefaultRSSSourceRepository: RSSSourceRepository {
    private let localDataSource: LocalDataSource
    private let remoteDataSource: RemoteDataSource
    
    init(localDataSource: LocalDataSource, remoteDataSource: RemoteDataSource) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }
    
    func getSources() -> AnyPublisher<[RSSSource], Error> {
        return localDataSource.getSources()
    }
    
    func addSource(_ source: RSSSource) -> AnyPublisher<RSSSource, Error> {
        return localDataSource.saveSource(source)
    }
    
    func deleteSource(_ sourceId: UUID) -> AnyPublisher<Void, Error> {
        return localDataSource.deleteSource(sourceId)
    }
    
    func discoverRSSFeeds(from websiteUrl: String) -> AnyPublisher<[String], Error> {
        return remoteDataSource.discoverRSSFeeds(from: websiteUrl)
    }
}
```

### 4.2 ArticleRepository.swift

```swift
import Foundation
import Combine
import FeedKit

// MARK: - 仓库协议
protocol ArticleRepository {
    func getArticles(filters: ArticleFilters?) -> AnyPublisher<[Article], Error>
    func fetchArticlesFromSource(sourceId: UUID) -> AnyPublisher<[Article], Error>
    func updateArticleStatus(id: UUID, isRead: Bool?, isFavorite: Bool?, readingProgress: Double?) -> AnyPublisher<Void, Error>
    func getRelatedArticles(forArticleId: UUID, relationType: RelationType?) -> AnyPublisher<[Article], Error>
    func saveArticleRelation(_ relation: ArticleRelation) -> AnyPublisher<ArticleRelation, Error>
}

// MARK: - 默认实现
class DefaultArticleRepository: ArticleRepository {
    private let localDataSource: LocalDataSource
    private let remoteDataSource: RemoteDataSource
    
    init(localDataSource: LocalDataSource, remoteDataSource: RemoteDataSource) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }
    
    func getArticles(filters: ArticleFilters?) -> AnyPublisher<[Article], Error> {
        return localDataSource.getArticles(filters: filters)
    }
    
    func fetchArticlesFromSource(sourceId: UUID) -> AnyPublisher<[Article], Error> {
        return Publishers.CombineLatest(
            localDataSource.getSources(),
            localDataSource.getArticles(filters: ArticleFilters(sourceId: sourceId))
        )
        .flatMap { [weak self] (sources, existingArticles) -> AnyPublisher<[Article], Error> in
            guard let self = self,
                  let source = sources.first(where: { $0.id == sourceId }) else {
                return Fail(error: NSError(domain: "ArticleRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source not found"]))
                    .eraseToAnyPublisher()
            }
            
            return self.remoteDataSource.fetchFeed(from: source.url)
                .flatMap { feed -> AnyPublisher<[Article], Error> in
                    // 将RSS Feed转换为文章
                    let articles = self.convertFeedToArticles(feed: feed, sourceId: sourceId, sourceName: source.title)
                    
                    // 过滤出新文章
                    let existingLinks = Set(existingArticles.map { $0.link })
                    let newArticles = articles.filter { !existingLinks.contains($0.link) }
                    
                    if newArticles.isEmpty {
                        return Just(existingArticles)
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                    
                    // 保存新文章
                    let savePublishers = newArticles.map { self.localDataSource.saveArticle($0) }
                    
                    return Publishers.MergeMany(savePublishers)
                        .collect()
                        .flatMap { _ -> AnyPublisher<[Article], Error> in
                            // 更新源的最后更新时间
                            let updatedSource = RSSSource(
                                id: source.id,
                                title: source.title,
                                url: source.url,
                                iconURL: source.iconURL,
                                category: source.category,
                                lastUpdated: Date(),
                                isActive: source.isActive
                            )
                            
                            return self.localDataSource.saveSource(updatedSource)
                                .flatMap { _ -> AnyPublisher<[Article], Error> in
                                    // 返回所有文章
                                    return self.localDataSource.getArticles(filters: ArticleFilters(sourceId: sourceId))
                                }
                                .eraseToAnyPublisher()
                        }
                        .eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    func updateArticleStatus(id: UUID, isRead: Bool?, isFavorite: Bool?, readingProgress: Double?) -> AnyPublisher<Void, Error> {
        return localDataSource.updateArticleStatus(id: id, isRead: isRead, isFavorite: isFavorite, readingProgress: readingProgress)
    }
    
    func getRelatedArticles(forArticleId: UUID, relationType: RelationType?) -> AnyPublisher<[Article], Error> {
        return localDataSource.getRelatedArticles(forArticleId: forArticleId, relationType: relationType)
    }
    
    func saveArticleRelation(_ relation: ArticleRelation) -> AnyPublisher<ArticleRelation, Error> {
        return localDataSource.saveArticleRelation(relation)
    }
    
    // MARK: - 辅助方法
    
    private func convertFeedToArticles(feed: RSSFeed, sourceId: UUID, sourceName: String) -> [Article] {
        guard let items = feed.channel?.items else { return [] }
        
        return items.compactMap { item -> Article? in
            guard let title = item.title,
                  let link = item.link,
                  let pubDate = item.pubDate else {
                return nil
            }
            
            return Article(
                id: UUID(),
                title: title,
                link: link,
                description: item.description ?? "",
                content: item.content?.contentEncoded,
                author: item.author,
                pubDate: pubDate,
                sourceId: sourceId,
                sourceName: sourceName,
                imageURL: extractImageURL(from: item),
                keywords: nil,
                isRead: false,
                isFavorite: false,
                readingProgress: nil
            )
        }
    }
    
    private func extractImageURL(from item: RSSFeedItem) -> String? {
        // 尝试从Media命名空间获取
        if let mediaContent = item.media?.mediaContents?.first,
           let url = mediaContent.attributes?.url {
            return url
        }
        
        // 尝试从内容中提取第一个图片
        if let content = item.content?.contentEncoded {
            let pattern = "<img[^>]*src=[\"']([^\"']+)[\"'][^>]*>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count)),
               let range = Range(match.range(at: 1), in: content) {
                return String(content[range])
            }
        }
        
        // 尝试从描述中提取第一个图片
        if let description = item.description {
            let pattern = "<img[^>]*src=[\"']([^\"']+)[\"'][^>]*>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: description, options: [], range: NSRange(location: 0, length: description.utf16.count)),
               let range = Range(match.range(at: 1), in: description) {
                return String(description[range])
            }
        }
        
        return nil
    }
}
```

## 5. 用例实现

### 5.1 ManageRSSSourcesUseCase.swift

```swift
import Foundation
import Combine

class ManageRSSSourcesUseCase {
    private let sourceRepository: RSSSourceRepository
    
    init(sourceRepository: RSSSourceRepository) {
        self.sourceRepository = sourceRepository
    }
    
    func getSources() -> AnyPublisher<[RSSSource], Error> {
        return sourceRepository.getSources()
    }
    
    func addSource(_ source: RSSSource) -> AnyPublisher<RSSSource, Error> {
        return sourceRepository.addSource(source)
    }
    
    func deleteSource(_ sourceId: UUID) -> AnyPublisher<Void, Error> {
        return sourceRepository.deleteSource(sourceId)
    }
    
    func discoverRSSFeeds(from websiteUrl: String) -> AnyPublisher<[String], Error> {
        return sourceRepository.discoverRSSFeeds(from: websiteUrl)
    }
}
```

### 5.2 ManageArticlesUseCase.swift

```swift
import Foundation
import Combine

class ManageArticlesUseCase {
    private let articleRepository: ArticleRepository
    
    init(articleRepository: ArticleRepository) {
        self.articleRepository = articleRepository
    }
    
    func getArticles(filters: ArticleFilters?) -> AnyPublisher<[Article], Error> {
        return articleRepository.getArticles(filters: filters)
    }
    
    func fetchArticlesFromSource(sourceId: UUID) -> AnyPublisher<[Article], Error> {
        return articleRepository.fetchArticlesFromSource(sourceId: sourceId)
    }
    
    func markArticleAsRead(id: UUID) -> AnyPublisher<Void, Error> {
        return articleRepository.updateArticleStatus(id: id, isRead: true, isFavorite: nil, readingProgress: nil)
    }
    
    func toggleFavorite(id: UUID, isFavorite: Bool) -> AnyPublisher<Void, Error> {
        return articleRepository.updateArticleStatus(id: id, isRead: nil, isFavorite: isFavorite, readingProgress: nil)
    }
    
    func updateReadingProgress(id: UUID, progress: Double) -> AnyPublisher<Void, Error> {
        return articleRepository.updateArticleStatus(id: id, isRead: nil, isFavorite: nil, readingProgress: progress)
    }
}
```

## 6. 视图模型实现

### 6.1 SourceListViewModel.swift

```swift
import Foundation
import Combine
import SwiftUI

class SourceListViewModel: ObservableObject {
    @Published var sources: [RSSSource] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let manageRSSSourcesUseCase: ManageRSSSourcesUseCase
    var cancellables = Set<AnyCancellable>()
    
    init(manageRSSSourcesUseCase: ManageRSSSourcesUseCase) {
        self.manageRSSSourcesUseCase = manageRSSSourcesUseCase
        loadSources()
    }
    
    func loadSources() {
        isLoading = true
        manageRSSSourcesUseCase.getSources()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] sources in
                    self?.sources = sources
                }
            )
            .store(in: &cancellables)
    }
    
    func addSource(_ source: RSSSource) {
        isLoading = true
        manageRSSSourcesUseCase.addSource(source)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadSources()
                }
            )
            .store(in: &cancellables)
    }
    
    func deleteSource(at indexSet: IndexSet) {
        guard let index = indexSet.first, index < sources.count else { return }
        let sourceId = sources[index].id
        
        isLoading = true
        manageRSSSourcesUseCase.deleteSource(sourceId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadSources()
                }
            )
            .store(in: &cancellables)
    }
    
    func discoverRSSFeeds(from websiteUrl: String) -> AnyPublisher<[String], Error> {
        return manageRSSSourcesUseCase.discoverRSSFeeds(from: websiteUrl)
    }
}
```

### 6.2 ArticleListViewModel.swift

```swift
import Foundation
import Combine
import SwiftUI

class ArticleListViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let manageArticlesUseCase: ManageArticlesUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(manageArticlesUseCase: ManageArticlesUseCase) {
        self.manageArticlesUseCase = manageArticlesUseCase
    }
    
    func loadArticles(filters: ArticleFilters? = nil) {
        isLoading = true
        manageArticlesUseCase.getArticles(filters: filters)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.articles = articles
                }
            )
            .store(in: &cancellables)
    }
    
    func fetchArticlesFromSource(sourceId: UUID) {
        isLoading = true
        manageArticlesUseCase.fetchArticlesFromSource(sourceId: sourceId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.articles = articles
                }
            )
            .store(in: &cancellables)
    }
    
    func markAsRead(articleId: UUID) {
        manageArticlesUseCase.markArticleAsRead(id: articleId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    if let index = self?.articles.firstIndex(where: { $0.id == articleId }) {
                        self?.articles[index].isRead = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func toggleFavorite(articleId: UUID) {
        guard let index = articles.firstIndex(where: { $0.id == articleId }) else { return }
        let isFavorite = !articles[index].isFavorite
        
        manageArticlesUseCase.toggleFavorite(id: articleId, isFavorite: isFavorite)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    if let index = self?.articles.firstIndex(where: { $0.id == articleId }) {
                        self?.articles[index].isFavorite = isFavorite
                    }
                }
            )
            .store(in: &cancellables)
    }
}
```

## 7. 视图实现

### 7.1 MainView.swift

```swift
import SwiftUI

struct MainView: View {
    @StateObject private var sourceListViewModel: SourceListViewModel
    @StateObject private var articleListViewModel: ArticleListViewModel
    
    init(
        sourceListViewModel: SourceListViewModel,
        articleListViewModel: ArticleListViewModel
    ) {
        _sourceListViewModel = StateObject(wrappedValue: sourceListViewModel)
        _articleListViewModel = StateObject(wrappedValue: articleListViewModel)
    }
    
    var body: some View {
        TabView {
            NavigationView {
                SourceListView(viewModel: sourceListViewModel)
            }
            .tabItem {
                Label("订阅", systemImage: "list.bullet")
            }
            
            NavigationView {
                ArticleListView(viewModel: articleListViewModel)
            }
            .tabItem {
                Label("文章", systemImage: "doc.text")
            }
            
            NavigationView {
                FavoritesView(viewModel: articleListViewModel)
            }
            .tabItem {
                Label("收藏", systemImage: "star")
            }
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
        }
        .onAppear {
            // 加载所有文章
            articleListViewModel.loadArticles()
        }
    }
}
```

### 7.2 SourceListView.swift

```swift
import SwiftUI

struct SourceListView: View {
    @ObservedObject var viewModel: SourceListViewModel
    @State private var showingAddSheet = false
    @State private var websiteUrl = ""
    @State private var discoveredFeeds: [String] = []
    @State private var isDiscovering = false
    
    var body: some View {
        List {
            ForEach(viewModel.sources) { source in
                NavigationLink(destination: SourceDetailView(source: source, viewModel: viewModel)) {
                    HStack {
                        if let iconURL = source.iconURL, let url = URL(string: iconURL) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                Image(systemName: "globe")
                            }
                            .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "globe")
                                .frame(width: 24, height: 24)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(source.title)
                                .font(.headline)
                            if let category = source.category {
                                Text(category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .onDelete(perform: viewModel.deleteSource)
        }
        .navigationTitle("RSS订阅")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            viewModel.loadSources()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                Form {
                    Section(header: Text("输入网站URL")) {
                        TextField("https://example.com", text: $websiteUrl)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                        
                        Button("发现RSS源") {
                            discoverFeeds()
                        }
                        .disabled(websiteUrl.isEmpty || isDiscovering)
                    }
                    
                    if isDiscovering {
                        Section {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("正在搜索RSS源...")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    
                    if !discoveredFeeds.isEmpty {
                        Section(header: Text("发现的RSS源")) {
                            ForEach(discoveredFeeds, id: \.self) { feed in
                                Button(action: {
                                    addSource(url: feed)
                                }) {
                                    Text(feed)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("手动添加")) {
                        Button("添加RSS源") {
                            addSource(url: websiteUrl)
                        }
                        .disabled(websiteUrl.isEmpty)
                    }
                }
                .navigationTitle("添加RSS源")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("取消") {
                            showingAddSheet = false
                            websiteUrl = ""
                            discoveredFeeds = []
                        }
                    }
                }
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Alert(
                title: Text("错误"),
                message: Text(viewModel.error?.localizedDescription ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private func discoverFeeds() {
        guard !websiteUrl.isEmpty else { return }
        
        isDiscovering = true
        discoveredFeeds = []
        
        viewModel.discoverRSSFeeds(from: websiteUrl)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isDiscovering = false
                    if case .failure(let error) = completion {
                        viewModel.error = error
                    }
                },
                receiveValue: { feeds in
                    discoveredFeeds = feeds
                }
            )
            .store(in: &viewModel.cancellables)
    }
    
    private func addSource(url: String) {
        let newSource = RSSSource(
            id: UUID(),
            title: URL(string: url)?.host ?? url,
            url: url,
            iconURL: nil,
            category: nil,
            lastUpdated: nil,
            isActive: true
        )
        
        viewModel.addSource(newSource)
        showingAddSheet = false
        websiteUrl = ""
        discoveredFeeds = []
    }
}
```

### 7.3 SourceDetailView.swift

```swift
import SwiftUI

struct SourceDetailView: View {
    let source: RSSSource
    @ObservedObject var viewModel: SourceListViewModel
    @StateObject private var articleListViewModel: ArticleListViewModel
    
    init(source: RSSSource, viewModel: SourceListViewModel) {
        self.source = source
        self.viewModel = viewModel
        
        // 使用依赖注入容器获取ArticleListViewModel
        let container = DependencyContainer.shared
        _articleListViewModel = StateObject(wrappedValue: container.makeArticleListViewModel())
    }
    
    var body: some View {
        List {
            if articleListViewModel.articles.isEmpty && !articleListViewModel.isLoading {
                Text("没有文章")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(articleListViewModel.articles) { article in
                    NavigationLink(destination: ArticleDetailView(article: article)) {
                        ArticleRow(article: article)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            articleListViewModel.markAsRead(articleId: article.id)
                        } label: {
                            Label(article.isRead ? "标为未读" : "标为已读", systemImage: article.isRead ? "envelope" : "envelope.open")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            articleListViewModel.toggleFavorite(articleId: article.id)
                        } label: {
                            Label(article.isFavorite ? "取消收藏" : "收藏", systemImage: article.isFavorite ? "star.slash" : "star")
                        }
                        .tint(.yellow)
                    }
                }
            }
        }
        .navigationTitle(source.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshArticles) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .refreshable {
            refreshArticles()
        }
        .overlay {
            if articleListViewModel.isLoading {
                ProgressView()
            }
        }
        .onAppear {
            loadArticles()
        }
        .alert(isPresented: Binding<Bool>(
            get: { articleListViewModel.error != nil },
            set: { if !$0 { articleListViewModel.error = nil } }
        )) {
            Alert(
                title: Text("错误"),
                message: Text(articleListViewModel.error?.localizedDescription ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private func loadArticles() {
        articleListViewModel.loadArticles(filters: ArticleFilters(sourceId: source.id))
    }
    
    private func refreshArticles() {
        articleListViewModel.fetchArticlesFromSource(sourceId: source.id)
    }
}

struct ArticleRow: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title)
                .font(article.isRead ? .body : .headline)
                .foregroundColor(article.isRead ? .secondary : .primary)
                .lineLimit(2)
            
            HStack {
                Text(article.sourceName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDate(article.pubDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

## 8. 依赖注入容器

```swift
import Foundation
import CoreData

class DependencyContainer {
    static let shared = DependencyContainer()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RSSReader")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        return container
    }()
    
    // MARK: - 数据源
    
    lazy var localDataSource: LocalDataSource = {
        return CoreDataLocalDataSource(persistentContainer: persistentContainer)
    }()
    
    lazy var remoteDataSource: RemoteDataSource = {
        return FeedKitRemoteDataSource()
    }()
    
    // MARK: - 仓库
    
    lazy var rssSourceRepository: RSSSourceRepository = {
        return DefaultRSSSourceRepository(localDataSource: localDataSource, remoteDataSource: remoteDataSource)
    }()
    
    lazy var articleRepository: ArticleRepository = {
        return DefaultArticleRepository(localDataSource: localDataSource, remoteDataSource: remoteDataSource)
    }()
    
    // MARK: - 用例
    
    lazy var manageRSSSourcesUseCase: ManageRSSSourcesUseCase = {
        return ManageRSSSourcesUseCase(sourceRepository: rssSourceRepository)
    }()
    
    lazy var manageArticlesUseCase: ManageArticlesUseCase = {
        return ManageArticlesUseCase(articleRepository: articleRepository)
    }()
    
    // MARK: - 视图模型工厂方法
    
    func makeSourceListViewModel() -> SourceListViewModel {
        return SourceListViewModel(manageRSSSourcesUseCase: manageRSSSourcesUseCase)
    }
    
    func makeArticleListViewModel() -> ArticleListViewModel {
        return ArticleListViewModel(manageArticlesUseCase: manageArticlesUseCase)
    }
}
```

## 9. 应用入口

```swift
import SwiftUI

@main
struct RSSReaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            let container = DependencyContainer.shared
            MainView(
                sourceListViewModel: container.makeSourceListViewModel(),
                articleListViewModel: container.makeArticleListViewModel()
            )
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 应用启动配置
        return true
    }
}
```

## 10. Core Data 模型

```swift
// RSSSourceEntity.swift
import CoreData

@objc(RSSSourceEntity)
public class RSSSourceEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var url: String?
    @NSManaged public var iconURL: String?
    @NSManaged public var category: String?
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var isActive: Bool
}

// ArticleEntity.swift
import CoreData

@objc(ArticleEntity)
public class ArticleEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var link: String?
    @NSManaged public var articleDescription: String?
    @NSManaged public var content: String?
    @NSManaged public var author: String?
    @NSManaged public var pubDate: Date?
    @NSManaged public var sourceId: UUID?
    @NSManaged public var sourceName: String?
    @NSManaged public var imageURL: String?
    @NSManaged public var keywords: Data?
    @NSManaged public var isRead: Bool
    @NSManaged public var isFavorite: Bool
    @NSManaged public var readingProgress: Double?
}
```

## 11. 总结

本文档详细描述了iOS RSS阅读应用核心RSS功能的实现，包括项目结构、数据模型、RSS源管理、RSS自动发现、内容获取和解析等功能。实现遵循MVVM架构模式和iOS开发最佳实践，使用了依赖注入、协议驱动开发和响应式编程等技术。

核心功能包括：

1. **RSS源管理**：添加、删除和更新RSS源
2. **RSS自动发现**：从网站URL自动发现RSS源
3. **内容获取和解析**：使用FeedKit库解析RSS、Atom和JSON格式的Feed
4. **数据持久化**：使用Core Data存储RSS源和文章
5. **基本UI界面**：实现了主界面、订阅列表和添加订阅等基本界面

这些功能为后续实现关键词聚合、文章关联和讨论功能奠定了基础。
