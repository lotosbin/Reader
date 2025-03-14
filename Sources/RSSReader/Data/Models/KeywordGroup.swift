import Foundation
import SwiftData

@Model
final class KeywordGroup {
    var id: UUID
    var name: String
    var keywords: [String]
    var isActive: Bool
    
    @Relationship(deleteRule: .nullify)
    var articles: [Article]? = []
    
    init(id: UUID = UUID(), name: String, keywords: [String], isActive: Bool = true) {
        self.id = id
        self.name = name
        self.keywords = keywords
        self.isActive = isActive
    }
}
