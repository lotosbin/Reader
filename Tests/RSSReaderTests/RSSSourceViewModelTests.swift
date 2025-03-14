import XCTest
@testable import RSSReader

final class RSSSourceViewModelTests: XCTestCase {
    var viewModel: RSSSourceViewModel!
    var mockRepository: MockRSSRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockRSSRepository()
        viewModel = RSSSourceViewModel(repository: mockRepository)
    }
    
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        super.tearDown()
    }
    
    func testLoadSources() {
        // 准备测试数据
        let source1 = RSSSource(title: "Test Feed 1", url: URL(string: "https://example.com/feed1.xml")!)
        let source2 = RSSSource(title: "Test Feed 2", url: URL(string: "https://example.com/feed2.xml")!)
        mockRepository.sources = [source1, source2]
        
        // 调用加载方法
        viewModel.loadSources()
        
        // 验证结果
        XCTAssertEqual(viewModel.sources.count, 2)
        XCTAssertEqual(viewModel.sources[0].title, "Test Feed 1")
        XCTAssertEqual(viewModel.sources[1].title, "Test Feed 2")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testAddSource() {
        // 调用添加方法
        viewModel.addSource(
            title: "New Feed",
            url: URL(string: "https://example.com/newfeed.xml")!,
            description: "Test description"
        )
        
        // 验证结果
        XCTAssertEqual(mockRepository.addedSource?.title, "New Feed")
        XCTAssertEqual(mockRepository.addedSource?.url, URL(string: "https://example.com/newfeed.xml")!)
        XCTAssertEqual(mockRepository.addedSource?.description, "Test description")
    }
    
    func testUpdateSource() {
        // 准备测试数据
        let source = RSSSource(title: "Test Feed", url: URL(string: "https://example.com/feed.xml")!)
        
        // 调用更新方法
        viewModel.updateSource(source)
        
        // 验证结果
        XCTAssertEqual(mockRepository.updatedSource?.id, source.id)
    }
    
    func testDeleteSource() {
        // 准备测试数据
        let source = RSSSource(title: "Test Feed", url: URL(string: "https://example.com/feed.xml")!)
        
        // 调用删除方法
        viewModel.deleteSource(source)
        
        // 验证结果
        XCTAssertEqual(mockRepository.deletedSource?.id, source.id)
    }
    
    func testDiscoverFeeds() async {
        // 准备测试数据
        let websiteURL = URL(string: "https://example.com")!
        let expectedFeeds = [
            URL(string: "https://example.com/feed.xml")!,
            URL(string: "https://example.com/rss.xml")!
        ]
        mockRepository.discoveredFeeds = expectedFeeds
        
        // 调用发现方法
        let feeds = await viewModel.discoverFeeds(from: websiteURL)
        
        // 验证结果
        XCTAssertEqual(feeds, expectedFeeds)
        XCTAssertEqual(mockRepository.lastDiscoverURL, websiteURL)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testFetchFeed() async {
        // 准备测试数据
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let expectedFeed = RSSFeed(
            title: "Test Feed",
            description: "Test description",
            link: URL(string: "https://example.com"),
            items: []
        )
        mockRepository.feed = expectedFeed
        
        // 调用获取方法
        let feed = await viewModel.fetchFeed(from: feedURL)
        
        // 验证结果
        XCTAssertEqual(feed?.title, expectedFeed.title)
        XCTAssertEqual(mockRepository.lastFetchURL, feedURL)
        XCTAssertFalse(viewModel.isLoading)
    }
}

// 模拟RSSRepository用于测试
class MockRSSRepository: RSSRepositoryProtocol {
    var sources: [RSSSource] = []
    var articles: [Article] = []
    var discoveredFeeds: [URL] = []
    var feed: RSSFeed!
    
    var addedSource: RSSSource?
    var updatedSource: RSSSource?
    var deletedSource: RSSSource?
    var addedArticle: Article?
    var updatedArticle: Article?
    var deletedArticle: Article?
    var lastDiscoverURL: URL?
    var lastFetchURL: URL?
    
    func addRSSSource(_ source: RSSSource) throws {
        addedSource = source
        sources.append(source)
    }
    
    func updateRSSSource(_ source: RSSSource) throws {
        updatedSource = source
    }
    
    func deleteRSSSource(_ source: RSSSource) throws {
        deletedSource = source
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources.remove(at: index)
        }
    }
    
    func getRSSSources() throws -> [RSSSource] {
        return sources
    }
    
    func addArticle(_ article: Article, to source: RSSSource) throws {
        addedArticle = article
        article.source = source
        articles.append(article)
    }
    
    func updateArticle(_ article: Article) throws {
        updatedArticle = article
    }
    
    func deleteArticle(_ article: Article) throws {
        deletedArticle = article
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles.remove(at: index)
        }
    }
    
    func getArticles(for source: RSSSource?) throws -> [Article] {
        if let source = source {
            return articles.filter { $0.source?.id == source.id }
        } else {
            return articles
        }
    }
    
    func discoverFeeds(from websiteURL: URL) async throws -> [URL] {
        lastDiscoverURL = websiteURL
        return discoveredFeeds
    }
    
    func fetchFeed(from url: URL) async throws -> RSSFeed {
        lastFetchURL = url
        return feed
    }
}
