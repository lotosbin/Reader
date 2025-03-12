# iOS RSS阅读应用架构设计

## 1. 架构概述

本应用采用**MVVM（Model-View-ViewModel）**架构模式，结合Swift UI和Combine框架，实现清晰的关注点分离和响应式编程。同时，我们将遵循SOLID原则、依赖注入和协议驱动开发等iOS开发最佳实践。

### 架构层次

1. **数据层（Data Layer）**
   - 模型（Models）
   - 数据源（Data Sources）
   - 仓库（Repositories）

2. **领域层（Domain Layer）**
   - 用例（Use Cases）
   - 服务（Services）

3. **表现层（Presentation Layer）**
   - 视图模型（ViewModels）
   - 视图（Views）

4. **工具层（Utility Layer）**
   - 扩展（Extensions）
   - 工具类（Helpers）
   - 常量（Constants）

## 2. 详细设计

### 2.1 数据层

#### 模型（Models）

```swift
// RSS源模型
struct RSSSource: Identifiable, Codable {
    let id: UUID
    var title: String
    var url: String
    var iconURL: String?
    var category: String?
    var lastUpdated: Date?
    var isActive: Bool
}

// 文章模型
struct Article: Identifiable, Codable {
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
}

// 关键词组模型
struct KeywordGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var keywords: [String]
    var color: String
}

// 相关讨论模型
struct Discussion: Identifiable, Codable {
    let id: UUID
    var articleId: UUID
    var content: String
    var author: String
    var date: Date
    var parentId: UUID?
}

// 文章关联模型
struct ArticleRelation: Identifiable, Codable {
    let id: UUID
    var sourceArticleId: UUID
    var relatedArticleId: UUID
    var relationType: RelationType
    var similarityScore: Double?
}

enum RelationType: String, Codable {
    case prerequisite // 前置文章
    case extension    // 扩展文章
    case similar      // 相似文章
    case sequel       // 后续文章
}
```

#### 数据源（Data Sources）

```swift
// 本地数据源协议
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

// 远程数据源协议
protocol RemoteDataSource {
    func fetchFeed(from url: String) -> AnyPublisher<RSSFeed, Error>
    func discoverRSSFeeds(from websiteUrl: String) -> AnyPublisher<[String], Error>
}

// Core Data实现
class CoreDataLocalDataSource: LocalDataSource {
    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // 实现LocalDataSource协议的方法...
}

// FeedKit实现
class FeedKitRemoteDataSource: RemoteDataSource {
    func fetchFeed(from url: String) -> AnyPublisher<RSSFeed, Error> {
        return Future<RSSFeed, Error> { promise in
            Task {
                do {
                    let feed = try await RSSFeed(urlString: url)
                    promise(.success(feed))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func discoverRSSFeeds(from websiteUrl: String) -> AnyPublisher<[String], Error> {
        // 实现RSS自动发现...
        return Future<[String], Error> { promise in
            Task {
                do {
                    guard let url = URL(string: websiteUrl) else {
                        throw URLError(.badURL)
                    }
                    
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let htmlString = String(data: data, encoding: .utf8) else {
                        throw NSError(domain: "HTMLParsingError", code: 1, userInfo: nil)
                    }
                    
                    // 使用正则表达式查找RSS链接
                    let pattern = "<link[^>]*rel=[\"']alternate[\"'][^>]*type=[\"']application/rss\\+xml[\"'][^>]*href=[\"']([^\"']+)[\"'][^>]*>"
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
                    
                    promise(.success(feedURLs))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
}
```

#### 仓库（Repositories）

```swift
// RSS源仓库协议
protocol RSSSourceRepository {
    func getSources() -> AnyPublisher<[RSSSource], Error>
    func addSource(_ source: RSSSource) -> AnyPublisher<RSSSource, Error>
    func deleteSource(_ sourceId: UUID) -> AnyPublisher<Void, Error>
    func discoverRSSFeeds(from websiteUrl: String) -> AnyPublisher<[String], Error>
}

// 文章仓库协议
protocol ArticleRepository {
    func getArticles(filters: ArticleFilters?) -> AnyPublisher<[Article], Error>
    func fetchArticlesFromSource(sourceId: UUID) -> AnyPublisher<[Article], Error>
    func updateArticleStatus(id: UUID, isRead: Bool?, isFavorite: Bool?, readingProgress: Double?) -> AnyPublisher<Void, Error>
    func getRelatedArticles(forArticleId: UUID, relationType: RelationType?) -> AnyPublisher<[Article], Error>
    func saveArticleRelation(_ relation: ArticleRelation) -> AnyPublisher<ArticleRelation, Error>
}

// 关键词仓库协议
protocol KeywordRepository {
    func getKeywordGroups() -> AnyPublisher<[KeywordGroup], Error>
    func saveKeywordGroup(_ group: KeywordGroup) -> AnyPublisher<KeywordGroup, Error>
    func extractKeywords(from text: String, maximumCount: Int) -> AnyPublisher<[String: Double], Error>
    func groupArticlesByKeywords(articles: [Article], targetKeywords: [String]) -> AnyPublisher<[String: [Article]], Error>
}

// 讨论仓库协议
protocol DiscussionRepository {
    func getDiscussions(forArticleId: UUID) -> AnyPublisher<[Discussion], Error>
    func saveDiscussion(_ discussion: Discussion) -> AnyPublisher<Discussion, Error>
}

// 实现类
class DefaultRSSSourceRepository: RSSSourceRepository {
    private let localDataSource: LocalDataSource
    private let remoteDataSource: RemoteDataSource
    
    init(localDataSource: LocalDataSource, remoteDataSource: RemoteDataSource) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }
    
    // 实现RSSSourceRepository协议的方法...
}

// 其他仓库实现类...
```

### 2.2 领域层

#### 用例（Use Cases）

```swift
// RSS源管理用例
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

// 文章管理用例
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

// 关键词聚合用例
class KeywordAggregationUseCase {
    private let keywordRepository: KeywordRepository
    private let articleRepository: ArticleRepository
    
    init(keywordRepository: KeywordRepository, articleRepository: ArticleRepository) {
        self.keywordRepository = keywordRepository
        self.articleRepository = articleRepository
    }
    
    func getKeywordGroups() -> AnyPublisher<[KeywordGroup], Error> {
        return keywordRepository.getKeywordGroups()
    }
    
    func saveKeywordGroup(_ group: KeywordGroup) -> AnyPublisher<KeywordGroup, Error> {
        return keywordRepository.saveKeywordGroup(group)
    }
    
    func getArticlesByKeywordGroup(groupId: UUID) -> AnyPublisher<[Article], Error> {
        return Publishers.CombineLatest(
            keywordRepository.getKeywordGroups(),
            articleRepository.getArticles(filters: nil)
        )
        .flatMap { (groups, articles) -> AnyPublisher<[Article], Error> in
            guard let group = groups.first(where: { $0.id == groupId }) else {
                return Fail(error: NSError(domain: "KeywordError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Group not found"]))
                    .eraseToAnyPublisher()
            }
            
            return self.keywordRepository.groupArticlesByKeywords(articles: articles, targetKeywords: group.keywords)
                .map { keywordArticles in
                    // 合并所有关键词下的文章并去重
                    let allArticles = keywordArticles.values.flatMap { $0 }
                    let uniqueArticles = Array(Set(allArticles))
                    return uniqueArticles.sorted(by: { $0.pubDate > $1.pubDate })
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

// 文章关联用例
class ArticleRelationsUseCase {
    private let articleRepository: ArticleRepository
    
    init(articleRepository: ArticleRepository) {
        self.articleRepository = articleRepository
    }
    
    func getRelatedArticles(forArticleId: UUID, relationType: RelationType?) -> AnyPublisher<[Article], Error> {
        return articleRepository.getRelatedArticles(forArticleId: forArticleId, relationType: relationType)
    }
    
    func findSimilarArticles(forArticleId: UUID) -> AnyPublisher<[Article], Error> {
        // 实现查找相似文章的逻辑...
        return articleRepository.getRelatedArticles(forArticleId: forArticleId, relationType: .similar)
    }
}

// 讨论管理用例
class ManageDiscussionsUseCase {
    private let discussionRepository: DiscussionRepository
    
    init(discussionRepository: DiscussionRepository) {
        self.discussionRepository = discussionRepository
    }
    
    func getDiscussions(forArticleId: UUID) -> AnyPublisher<[Discussion], Error> {
        return discussionRepository.getDiscussions(forArticleId: forArticleId)
    }
    
    func addDiscussion(_ discussion: Discussion) -> AnyPublisher<Discussion, Error> {
        return discussionRepository.saveDiscussion(discussion)
    }
}
```

### 2.3 表现层

#### 视图模型（ViewModels）

```swift
// 源列表视图模型
class SourceListViewModel: ObservableObject {
    @Published var sources: [RSSSource] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let manageRSSSourcesUseCase: ManageRSSSourcesUseCase
    private var cancellables = Set<AnyCancellable>()
    
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

// 文章列表视图模型
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

// 关键词组视图模型
class KeywordGroupViewModel: ObservableObject {
    @Published var keywordGroups: [KeywordGroup] = []
    @Published var groupedArticles: [String: [Article]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let keywordAggregationUseCase: KeywordAggregationUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(keywordAggregationUseCase: KeywordAggregationUseCase) {
        self.keywordAggregationUseCase = keywordAggregationUseCase
        loadKeywordGroups()
    }
    
    func loadKeywordGroups() {
        isLoading = true
        keywordAggregationUseCase.getKeywordGroups()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] groups in
                    self?.keywordGroups = groups
                }
            )
            .store(in: &cancellables)
    }
    
    func loadArticlesForGroup(groupId: UUID) {
        isLoading = true
        keywordAggregationUseCase.getArticlesByKeywordGroup(groupId: groupId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    guard let self = self,
                          let group = self.keywordGroups.first(where: { $0.id == groupId }) else { return }
                    
                    self.groupedArticles[group.name] = articles
                }
            )
            .store(in: &cancellables)
    }
    
    func saveKeywordGroup(_ group: KeywordGroup) {
        isLoading = true
        keywordAggregationUseCase.saveKeywordGroup(group)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadKeywordGroups()
                }
            )
            .store(in: &cancellables)
    }
}

// 文章详情视图模型
class ArticleDetailViewModel: ObservableObject {
    @Published var article: Article?
    @Published var relatedArticles: [RelationType: [Article]] = [:]
    @Published var discussions: [Discussion] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let manageArticlesUseCase: ManageArticlesUseCase
    private let articleRelationsUseCase: ArticleRelationsUseCase
    private let manageDiscussionsUseCase: ManageDiscussionsUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(
        manageArticlesUseCase: ManageArticlesUseCase,
        articleRelationsUseCase: ArticleRelationsUseCase,
        manageDiscussionsUseCase: ManageDiscussionsUseCase
    ) {
        self.manageArticlesUseCase = manageArticlesUseCase
        self.articleRelationsUseCase = articleRelationsUseCase
        self.manageDiscussionsUseCase = manageDiscussionsUseCase
    }
    
    func loadArticle(id: UUID) {
        isLoading = true
        manageArticlesUseCase.getArticles(filters: ArticleFilters(ids: [id]))
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.article = articles.first
                    if let article = articles.first {
                        self?.loadRelatedArticles(forArticleId: article.id)
                        self?.loadDiscussions(forArticleId: article.id)
                        self?.updateReadingProgress(id: article.id, progress: 0)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadRelatedArticles(forArticleId: UUID) {
        // 加载前置文章
        articleRelationsUseCase.getRelatedArticles(forArticleId: forArticleId, relationType: .prerequisite)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.relatedArticles[.prerequisite] = articles
                }
            )
            .store(in: &cancellables)
        
        // 加载扩展文章
        articleRelationsUseCase.getRelatedArticles(forArticleId: forArticleId, relationType: .extension)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.relatedArticles[.extension] = articles
                }
            )
            .store(in: &cancellables)
        
        // 加载相似文章
        articleRelationsUseCase.findSimilarArticles(forArticleId: forArticleId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.relatedArticles[.similar] = articles
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadDiscussions(forArticleId: UUID) {
        manageDiscussionsUseCase.getDiscussions(forArticleId: forArticleId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] discussions in
                    self?.discussions = discussions
                }
            )
            .store(in: &cancellables)
    }
    
    func updateReadingProgress(id: UUID, progress: Double) {
        manageArticlesUseCase.updateReadingProgress(id: id, progress: progress)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.article?.readingProgress = progress
                    if progress >= 0.9 { // 如果阅读进度超过90%，标记为已读
                        self?.manageArticlesUseCase.markArticleAsRead(id: id)
                            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                            .store(in: &self!.cancellables)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func toggleFavorite() {
        guard let article = article else { return }
        let isFavorite = !article.isFavorite
        
        manageArticlesUseCase.toggleFavorite(id: article.id, isFavorite: isFavorite)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.article?.isFavorite = isFavorite
                }
            )
            .store(in: &cancellables)
    }
    
    func addDiscussion(_ content: String) {
        guard let article = article else { return }
        
        let discussion = Discussion(
            id: UUID(),
            articleId: article.id,
            content: content,
            author: "User", // 在实际应用中，这应该是当前用户的名称
            date: Date(),
            parentId: nil
        )
        
        manageDiscussionsUseCase.addDiscussion(discussion)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadDiscussions(forArticleId: article.id)
                }
            )
            .store(in: &cancellables)
    }
}
```

#### 视图（Views）

```swift
// 主视图
struct MainView: View {
    @StateObject private var sourceListViewModel: SourceListViewModel
    @StateObject private var articleListViewModel: ArticleListViewModel
    @StateObject private var keywordGroupViewModel: KeywordGroupViewModel
    
    init(
        sourceListViewModel: SourceListViewModel,
        articleListViewModel: ArticleListViewModel,
        keywordGroupViewModel: KeywordGroupViewModel
    ) {
        _sourceListViewModel = StateObject(wrappedValue: sourceListViewModel)
        _articleListViewModel = StateObject(wrappedValue: articleListViewModel)
        _keywordGroupViewModel = StateObject(wrappedValue: keywordGroupViewModel)
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
                KeywordGroupView(viewModel: keywordGroupViewModel)
            }
            .tabItem {
                Label("关键词", systemImage: "tag")
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
    }
}

// 源列表视图
struct SourceListView: View {
    @ObservedObject var viewModel: SourceListViewModel
    @State private var showingAddSheet = false
    @State private var websiteUrl = ""
    @State private var discoveredFeeds: [String] = []
    @State private var isDiscovering = false
    
    var body: some View {
        List {
            ForEach(viewModel.sources) { source in
                NavigationLink(destination: SourceDetailView(source: source)) {
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

// 其他视图实现...
```

### 2.4 依赖注入

```swift
// 依赖注入容器
class DependencyContainer {
    // 数据源
    lazy var localDataSource: LocalDataSource = {
        let container = NSPersistentContainer(name: "RSSReader")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        return CoreDataLocalDataSource(persistentContainer: container)
    }()
    
    lazy var remoteDataSource: RemoteDataSource = {
        return FeedKitRemoteDataSource()
    }()
    
    // 仓库
    lazy var rssSourceRepository: RSSSourceRepository = {
        return DefaultRSSSourceRepository(localDataSource: localDataSource, remoteDataSource: remoteDataSource)
    }()
    
    lazy var articleRepository: ArticleRepository = {
        return DefaultArticleRepository(localDataSource: localDataSource, remoteDataSource: remoteDataSource)
    }()
    
    lazy var keywordRepository: KeywordRepository = {
        return DefaultKeywordRepository(localDataSource: localDataSource)
    }()
    
    lazy var discussionRepository: DiscussionRepository = {
        return DefaultDiscussionRepository(localDataSource: localDataSource)
    }()
    
    // 用例
    lazy var manageRSSSourcesUseCase: ManageRSSSourcesUseCase = {
        return ManageRSSSourcesUseCase(sourceRepository: rssSourceRepository)
    }()
    
    lazy var manageArticlesUseCase: ManageArticlesUseCase = {
        return ManageArticlesUseCase(articleRepository: articleRepository)
    }()
    
    lazy var keywordAggregationUseCase: KeywordAggregationUseCase = {
        return KeywordAggregationUseCase(keywordRepository: keywordRepository, articleRepository: articleRepository)
    }()
    
    lazy var articleRelationsUseCase: ArticleRelationsUseCase = {
        return ArticleRelationsUseCase(articleRepository: articleRepository)
    }()
    
    lazy var manageDiscussionsUseCase: ManageDiscussionsUseCase = {
        return ManageDiscussionsUseCase(discussionRepository: discussionRepository)
    }()
    
    // 视图模型
    func makeSourceListViewModel() -> SourceListViewModel {
        return SourceListViewModel(manageRSSSourcesUseCase: manageRSSSourcesUseCase)
    }
    
    func makeArticleListViewModel() -> ArticleListViewModel {
        return ArticleListViewModel(manageArticlesUseCase: manageArticlesUseCase)
    }
    
    func makeKeywordGroupViewModel() -> KeywordGroupViewModel {
        return KeywordGroupViewModel(keywordAggregationUseCase: keywordAggregationUseCase)
    }
    
    func makeArticleDetailViewModel() -> ArticleDetailViewModel {
        return ArticleDetailViewModel(
            manageArticlesUseCase: manageArticlesUseCase,
            articleRelationsUseCase: articleRelationsUseCase,
            manageDiscussionsUseCase: manageDiscussionsUseCase
        )
    }
}
```

## 3. 数据流

1. **用户操作** → 视图（View）
2. 视图调用 → **视图模型（ViewModel）**方法
3. 视图模型调用 → **用例（Use Case）**
4. 用例协调 → **仓库（Repository）**
5. 仓库访问 → **数据源（Data Source）**
6. 数据源返回数据 → 仓库
7. 仓库处理数据 → 用例
8. 用例处理业务逻辑 → 视图模型
9. 视图模型更新状态 → 视图自动更新

## 4. 核心功能实现

### 4.1 RSS自动发现

RSS自动发现功能通过解析网页HTML头部的`<link>`标签或检查常见的RSS路径来实现。这个功能在`FeedKitRemoteDataSource`的`discoverRSSFeeds`方法中实现。

### 4.2 关键词聚合

关键词聚合功能使用NaturalLanguage框架实现，通过以下步骤：

1. 使用`NLTagger`对文章内容进行词性标注
2. 提取名词、动词和形容词作为候选关键词
3. 计算词频和重要性得分
4. 将文章按关键词分组

这个功能在`KeywordRepository`的实现类中完成。

### 4.3 文章关联

文章关联功能通过计算文章之间的相似度来实现，主要步骤：

1. 提取文章的关键词和权重
2. 计算文章之间关键词的重叠度
3. 根据重叠度计算相似度得分
4. 按相似度排序，推荐相关文章

这个功能在`ArticleRepository`的实现类中完成。

### 4.4 阅读状态管理

阅读状态管理通过跟踪用户的阅读进度实现：

1. 用户打开文章时，初始化阅读进度为0
2. 用户滚动阅读时，更新阅读进度
3. 当阅读进度超过90%时，自动标记文章为已读
4. 用户可以手动标记文章为已读或未读

这个功能在`ArticleDetailViewModel`中实现。

## 5. 性能优化

1. **懒加载**：使用懒加载初始化依赖项，减少启动时间
2. **分页加载**：文章列表使用分页加载，减少内存占用
3. **缓存策略**：实现智能缓存策略，减少网络请求
4. **后台处理**：在后台线程处理数据密集型操作，如关键词提取
5. **批量更新**：使用批量操作更新Core Data，提高性能

## 6. 安全考虑

1. **数据验证**：验证从远程源获取的数据，防止注入攻击
2. **安全存储**：敏感数据使用Keychain存储
3. **网络安全**：使用HTTPS进行网络通信
4. **输入验证**：验证用户输入，防止恶意输入

## 7. 可扩展性

1. **模块化设计**：每个功能模块独立，易于扩展
2. **协议驱动**：使用协议定义接口，便于替换实现
3. **依赖注入**：使用依赖注入容器管理依赖，便于测试和扩展
4. **事件驱动**：使用Combine框架实现响应式编程，便于处理异步事件

## 8. 测试策略

1. **单元测试**：测试各个组件的独立功能
2. **集成测试**：测试组件之间的交互
3. **UI测试**：测试用户界面和交互
4. **性能测试**：测试应用在不同条件下的性能

## 9. 总结

本架构设计采用MVVM模式，结合Swift UI和Combine框架，实现了一个功能完善、可扩展的RSS阅读应用。通过清晰的层次划分和依赖注入，使代码结构清晰、易于维护和测试。核心功能如RSS自动发现、关键词聚合和文章关联等都有详细的实现方案，确保应用能够满足用户需求。
