import Foundation
import FeedKit

protocol RSSDataSourceProtocol {
    func fetchFeed(from url: URL) async throws -> RSSFeed
    func discoverFeed(from websiteURL: URL) async throws -> [URL]
}

struct RSSFeed {
    let title: String
    let description: String?
    let link: URL?
    let items: [RSSItem]
}

struct RSSItem {
    let title: String
    let link: URL
    let description: String?
    let content: String?
    let author: String?
    let pubDate: Date?
}

class RSSDataSource: RSSDataSourceProtocol {
    
    // 从RSS URL获取Feed内容
    func fetchFeed(from url: URL) async throws -> RSSFeed {
        return try await withCheckedThrowingContinuation { continuation in
            let parser = FeedParser(URL: url)
            
            parser.parseAsync { result in
                switch result {
                case .success(let feed):
                    if let rssFeed = feed.rssFeed {
                        let items = rssFeed.items?.compactMap { item in
                            RSSItem(
                                title: item.title ?? "无标题",
                                link: URL(string: item.link ?? "") ?? url,
                                description: item.description,
                                content: item.content?.contentEncoded,
                                author: item.author,
                                pubDate: item.pubDate
                            )
                        } ?? []
                        
                        let feed = RSSFeed(
                            title: rssFeed.title ?? "未知Feed",
                            description: rssFeed.description,
                            link: URL(string: rssFeed.link ?? ""),
                            items: items
                        )
                        
                        continuation.resume(returning: feed)
                    } else if let atomFeed = feed.atomFeed {
                        let items = atomFeed.entries?.compactMap { entry in
                            RSSItem(
                                title: entry.title ?? "无标题",
                                link: URL(string: entry.links?.first?.attributes?.href ?? "") ?? url,
                                description: entry.summary?.value,
                                content: entry.content?.value,
                                author: entry.authors?.first?.name,
                                pubDate: entry.published ?? entry.updated
                            )
                        } ?? []
                        
                        let feed = RSSFeed(
                            title: atomFeed.title ?? "未知Feed",
                            description: atomFeed.subtitle?.value,
                            link: URL(string: atomFeed.links?.first?.attributes?.href ?? ""),
                            items: items
                        )
                        
                        continuation.resume(returning: feed)
                    } else if let jsonFeed = feed.jsonFeed {
                        let items = jsonFeed.items?.compactMap { item in
                            RSSItem(
                                title: item.title ?? "无标题",
                                link: URL(string: item.url ?? "") ?? url,
                                description: item.summary,
                                content: item.contentHtml ?? item.contentText,
                                author: item.author?.name,
                                pubDate: item.datePublished
                            )
                        } ?? []
                        
                        let feed = RSSFeed(
                            title: jsonFeed.title ?? "未知Feed",
                            description: jsonFeed.description,
                            link: URL(string: jsonFeed.homePageURL ?? ""),
                            items: items
                        )
                        
                        continuation.resume(returning: feed)
                    } else {
                        continuation.resume(throwing: NSError(domain: "RSSDataSource", code: 1, userInfo: [NSLocalizedDescriptionKey: "不支持的Feed格式"]))
                    }
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 从网站URL自动发现RSS Feed
    func discoverFeed(from websiteURL: URL) async throws -> [URL] {
        let (data, response) = try await URLSession.shared.data(from: websiteURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "RSSDataSource", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法获取网页内容"])
        }
        
        // 查找RSS链接
        var feedURLs: [URL] = []
        
        // 查找标准的RSS/Atom链接标签
        let linkPattern = #"<link[^>]*rel=["'](?:alternate|feed)["'][^>]*type=["']application/(?:rss|atom)\+xml["'][^>]*href=["']([^"']+)["'][^>]*>"#
        let linkRegex = try NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive])
        let linkMatches = linkRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        
        for match in linkMatches {
            if let range = Range(match.range(at: 1), in: html) {
                let urlString = String(html[range])
                if let url = URL(string: urlString, relativeTo: websiteURL)?.absoluteURL {
                    feedURLs.append(url)
                }
            }
        }
        
        // 查找反向顺序的链接标签
        let reverseLinkPattern = #"<link[^>]*href=["']([^"']+)["'][^>]*type=["']application/(?:rss|atom)\+xml["'][^>]*rel=["'](?:alternate|feed)["'][^>]*>"#
        let reverseLinkRegex = try NSRegularExpression(pattern: reverseLinkPattern, options: [.caseInsensitive])
        let reverseLinkMatches = reverseLinkRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        
        for match in reverseLinkMatches {
            if let range = Range(match.range(at: 1), in: html) {
                let urlString = String(html[range])
                if let url = URL(string: urlString, relativeTo: websiteURL)?.absoluteURL {
                    feedURLs.append(url)
                }
            }
        }
        
        // 查找常见的RSS路径
        let commonPaths = [
            "/feed", "/rss", "/feed.xml", "/rss.xml", "/atom.xml", 
            "/feeds/posts/default", "/feed/", "/rss/", "/index.xml",
            "/blog/feed", "/blog/rss", "/blog/atom"
        ]
        
        for path in commonPaths {
            if let url = URL(string: path, relativeTo: websiteURL)?.absoluteURL {
                // 检查这个URL是否已经在列表中
                if !feedURLs.contains(url) {
                    feedURLs.append(url)
                }
            }
        }
        
        return feedURLs
    }
}
