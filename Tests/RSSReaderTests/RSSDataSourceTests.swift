import XCTest
@testable import RSSReader

final class RSSDataSourceTests: XCTestCase {
    var dataSource: RSSDataSource!
    
    override func setUp() {
        super.setUp()
        dataSource = RSSDataSource()
    }
    
    override func tearDown() {
        dataSource = nil
        super.tearDown()
    }
    
    func testDiscoverFeed() async throws {
        // 测试从已知包含RSS源的网站URL发现Feed
        let websiteURL = URL(string: "https://www.apple.com")!
        let feedURLs = try await dataSource.discoverFeed(from: websiteURL)
        
        // 验证是否发现了至少一个Feed
        XCTAssertFalse(feedURLs.isEmpty, "应该至少发现一个Feed")
    }
    
    func testFetchFeed() async throws {
        // 测试从已知的RSS URL获取Feed内容
        let feedURL = URL(string: "https://developer.apple.com/news/rss/news.rss")!
        let feed = try await dataSource.fetchFeed(from: feedURL)
        
        // 验证Feed的基本信息
        XCTAssertFalse(feed.title.isEmpty, "Feed标题不应为空")
        XCTAssertFalse(feed.items.isEmpty, "Feed应包含至少一个条目")
    }
}
