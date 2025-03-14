import Foundation
import SwiftData

@Model
final class RSSSource {
    var id: UUID
    var title: String
    var url: URL
    var websiteURL: URL?
    var description: String?
    var category: String?
    var isActive: Bool
    var lastUpdated: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \Article.source)
    var articles: [Article] = []
    
    init(id: UUID = UUID(), title: String, url: URL, websiteURL: URL? = nil, description: String? = nil, category: String? = nil, isActive: Bool = true) {
        self.id = id
        self.title = title
        self.url = url
        self.websiteURL = websiteURL
        self.description = description
        self.category = category
        self.isActive = isActive
    }
}
