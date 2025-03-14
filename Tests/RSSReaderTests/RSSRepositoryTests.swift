import XCTest
@testable import RSSReader

final class RSSRepositoryTests: XCTestCase {
    var repository: RSSRepository!
    var mockDataSource: MockRSSDataSource!
    var modelContainer: ModelContainer!
    
    override func setUp() async throws {
        super.setUp()
        
        // 创建内存中的SwiftData容器用于测试
        let schema = Schema([RSSSource.self, Article.self, KeywordGroup.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        
        mockDataSource = MockRSSDataSource()
        repository = RSSRepository(modelContainer: modelContainer, dataSource: mockDataSource)
    }
    
    override func tearDown() {
        repository = nil
        mockDataSource = nil
        modelContainer = nil
        super.tearDown()
    }
    
    func testAddAndGetRSSSource() throws {
        // 测试添加RSS源
        let source = RSSSource(title: "Test Feed", url: URL(string: "https://example.com/feed.xml")!)
        try repository.addRSSSource(source)
        
        // 获取所有RSS源并验证
        let sources = try repository.getRSSSources()
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.title, "Test Feed")
        XCTAssertEqual(sources.first?.url, URL(string: "https://example.com/feed.xml")!)
    }
    
    func testUpdateRSSSource() throws {
        // 添加RSS源
        let source = RSSSource(title: "Test Feed", url: URL(string: "https://example.com/feed.xml")!)
        try repository.addRSSSource(source)
        
        // 更新RSS源
        source.title = "Updated Feed"
        try repository.updateRSSSource(source)
        
        // 获取所有RSS源并验证
        let sources = try repository.getRSSSources()
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.title, "Updated Feed")
    }
    
    func testDeleteRSSSource() throws {
        // 添加RSS源
        let source = RSSSource(title: "Test Feed", url: URL(string: "https://example.com/feed.xml")!)
        try repository.addRSSSource(source)
        
        // 删除RSS源
        try repository.deleteRSSSource(source)
        
        // 获取所有RSS源并验证
        let sources = try repository.getRSSSources()
        XCTAssertEqual(sources.count, 0)
    }
    
    func testAddAndGetArticle() throws {
        // 添加RSS源
        let source = RSSSource(title: "Test Feed", url: URL(string: "https://example.com/feed.xml")!)
        try repository.addRSSSource(source)
        
        // 添加文章
        let article = Article(
            title: "Test Article",
            link: URL(string: "https://example.com/article.html")!,
            content: "Test content",
            publishDate: Date()
        )
        try repository.addArticle(article, to: source)
        
        // 获取文章并验证
        let articles = try repository.getArticles(for: source)
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles.first?.title, "Test Article")
        XCTAssertEqual(articles.first?.source?.id, source.id)
    }
    
    func testDiscoverFeeds() async throws {
        // 设置模拟数据
        let websiteURL = URL(string: "https://example.com")!
        let expectedFeeds = [
            URL(string: "https://example.com/feed.xml")!,
            URL(string: "https://example.com/rss.xml")!
        ]
        mockDataSource.discoveredFeeds = expectedFeeds
        
        // 调用发现Feed的方法
        let feeds = try await repository.discoverFeeds(from: websiteURL)
        
        // 验证结果
        XCTAssertEqual(feeds, expectedFeeds)
        XCTAssertEqual(mockDataSource.lastDiscoverURL, websiteURL)
    }
    
    func testFetchFeed() async throws {
        // 设置模拟数据
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let expectedFeed = RSSFeed(
            title: "Test Feed",
            description: "Test description",
            link: URL(string: "https://example.com"),
            items: [
                RSSItem(
                    title: "Test Item",
                    link: URL(string: "https://example.com/item.html")!,
                    description: "Test description",
                    content: "Test content",
                    author: "Test Author",
                    pubDate: Date()
                )
            ]
        )
        mockDataSource.feed = expectedFeed
        
        // 调用获取Feed的方法
        let feed = try await repository.fetchFeed(from: feedURL)
        
        // 验证结果
        XCTAssertEqual(feed.title, expectedFeed.title)
        XCTAssertEqual(feed.items.count, expectedFeed.items.count)
        XCTAssertEqual(mockDataSource.lastFetchURL, feedURL)
    }
}

// 模拟RSSDataSource用于测试
class MockRSSDataSource: RSSDataSourceProtocol {
    var discoveredFeeds: [URL] = []
    var feed: RSSFeed!
    var lastDiscoverURL: URL?
    var lastFetchURL: URL?
    
    func discoverFeed(from websiteURL: URL) async throws -> [URL] {
        lastDiscoverURL = websiteURL
        return discoveredFeeds
    }
    
    func fetchFeed(from url: URL) async throws -> RSSFeed {
        lastFetchURL = url
        return feed
    }
}
