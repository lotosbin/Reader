import Foundation
import SwiftData

@Model
final class Article {
    var id: UUID
    var title: String
    var link: URL
    var content: String?
    var summary: String?
    var author: String?
    var publishDate: Date?
    var isRead: Bool
    var isFavorite: Bool
    var readingProgress: Double
    
    @Relationship(deleteRule: .cascade)
    var keywords: [String] = []
    
    @Relationship(deleteRule: .nullify, inverse: \RSSSource.articles)
    var source: RSSSource?
    
    @Relationship(deleteRule: .nullify)
    var relatedArticles: [Article]? = []
    
    init(id: UUID = UUID(), title: String, link: URL, content: String? = nil, summary: String? = nil, author: String? = nil, publishDate: Date? = nil, isRead: Bool = false, isFavorite: Bool = false, readingProgress: Double = 0.0) {
        self.id = id
        self.title = title
        self.link = link
        self.content = content
        self.summary = summary
        self.author = author
        self.publishDate = publishDate
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.readingProgress = readingProgress
    }
}
