import XCTest
@testable import RSSReader

final class ArticleViewModelTests: XCTestCase {
    var viewModel: ArticleViewModel!
    var mockRepository: MockRSSRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockRSSRepository()
        viewModel = ArticleViewModel(repository: mockRepository)
    }
    
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        super.tearDown()
    }
    
    func testLoadArticles() {
        // 准备测试数据
        let source = RSSSource(title: "Test Feed", url: URL(string: "https://example.com/feed.xml")!)
        let article1 = Article(title: "Article 1", link: URL(string: "https://example.com/article1.html")!)
        let article2 = Article(title: "Article 2", link: URL(string: "https://example.com/article2.html")!)
        article1.source = source
        article2.source = source
        mockRepository.articles = [article1, article2]
        
        // 调用加载方法
        viewModel.loadArticles(for: source)
        
        // 验证结果
        XCTAssertEqual(viewModel.articles.count, 2)
        XCTAssertEqual(viewModel.articles[0].title, "Article 1")
        XCTAssertEqual(viewModel.articles[1].title, "Article 2")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testMarkAsRead() {
        // 准备测试数据
        let article = Article(title: "Test Article", link: URL(string: "https://example.com/article.html")!)
        article.isRead = false
        
        // 调用标记已读方法
        viewModel.markAsRead(article)
        
        // 验证结果
        XCTAssertTrue(article.isRead)
        XCTAssertEqual(mockRepository.updatedArticle?.id, article.id)
    }
    
    func testToggleFavorite() {
        // 准备测试数据
        let article = Article(title: "Test Article", link: URL(string: "https://example.com/article.html")!)
        article.isFavorite = false
        
        // 调用切换收藏方法
        viewModel.toggleFavorite(article)
        
        // 验证结果
        XCTAssertTrue(article.isFavorite)
        XCTAssertEqual(mockRepository.updatedArticle?.id, article.id)
        
        // 再次调用切换收藏方法
        viewModel.toggleFavorite(article)
        
        // 验证结果
        XCTAssertFalse(article.isFavorite)
    }
    
    func testUpdateReadingProgress() {
        // 准备测试数据
        let article = Article(title: "Test Article", link: URL(string: "https://example.com/article.html")!)
        article.readingProgress = 0.0
        
        // 调用更新阅读进度方法
        viewModel.updateReadingProgress(article, progress: 0.5)
        
        // 验证结果
        XCTAssertEqual(article.readingProgress, 0.5)
        XCTAssertEqual(mockRepository.updatedArticle?.id, article.id)
    }
    
    func testRefreshFeed() async {
        // 准备测试数据
        let source = RSSSource(title: "Test Feed", url: URL(string: "https://example.com/feed.xml")!)
        let feed = RSSFeed(
            title: "Test Feed",
            description: "Test description",
            link: URL(string: "https://example.com"),
            items: [
                RSSItem(
                    title: "New Article",
                    link: URL(string: "https://example.com/new-article.html")!,
                    description: "Test description",
                    content: "Test content",
                    author: "Test Author",
                    pubDate: Date()
                )
            ]
        )
        mockRepository.feed = feed
        
        // 调用刷新方法
        await viewModel.refreshFeed(for: source)
        
        // 验证结果
        XCTAssertEqual(mockRepository.lastFetchURL, source.url)
        XCTAssertNotNil(mockRepository.addedArticle)
        XCTAssertEqual(mockRepository.addedArticle?.title, "New Article")
        XCTAssertNotNil(source.lastUpdated)
        XCTAssertFalse(viewModel.isLoading)
    }
}
