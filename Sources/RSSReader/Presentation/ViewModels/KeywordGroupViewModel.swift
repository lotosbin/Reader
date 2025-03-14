import Foundation
import SwiftUI
import SwiftData
import Combine

class KeywordGroupViewModel: ObservableObject {
    @Published var keywordGroups: [KeywordGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let modelContainer: ModelContainer
    private var cancellables = Set<AnyCancellable>()
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        loadKeywordGroups()
    }
    
    func loadKeywordGroups() {
        isLoading = true
        errorMessage = nil
        
        do {
            let descriptor = FetchDescriptor<KeywordGroup>(sortBy: [SortDescriptor(\.name)])
            keywordGroups = try modelContainer.mainContext.fetch(descriptor)
            isLoading = false
        } catch {
            errorMessage = "加载关键词组失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func addKeywordGroup(name: String, keywords: [String]) {
        let newGroup = KeywordGroup(name: name, keywords: keywords)
        
        do {
            let context = modelContainer.mainContext
            context.insert(newGroup)
            try context.save()
            loadKeywordGroups()
        } catch {
            errorMessage = "添加关键词组失败: \(error.localizedDescription)"
        }
    }
    
    func updateKeywordGroup(_ group: KeywordGroup) {
        do {
            try modelContainer.mainContext.save()
            loadKeywordGroups()
        } catch {
            errorMessage = "更新关键词组失败: \(error.localizedDescription)"
        }
    }
    
    func deleteKeywordGroup(_ group: KeywordGroup) {
        do {
            let context = modelContainer.mainContext
            context.delete(group)
            try context.save()
            loadKeywordGroups()
        } catch {
            errorMessage = "删除关键词组失败: \(error.localizedDescription)"
        }
    }
    
    // 根据关键词组查找相关文章
    func findRelatedArticles(for group: KeywordGroup) -> [Article] {
        do {
            let keywords = group.keywords
            
            // 创建一个谓词，查找包含任何关键词的文章
            var predicates: [Predicate<Article>] = []
            
            for keyword in keywords {
                predicates.append(#Predicate<Article> { article in
                    article.title.localizedStandardContains(keyword) ||
                    article.content?.localizedStandardContains(keyword) == true ||
                    article.summary?.localizedStandardContains(keyword) == true
                })
            }
            
            // 组合谓词
            let combinedPredicate = PredicateGroup(type: .or, predicates: predicates)
            
            // 创建查询描述符
            let descriptor = FetchDescriptor<Article>(
                predicate: combinedPredicate,
                sortBy: [SortDescriptor(\.publishDate, order: .reverse)]
            )
            
            return try modelContainer.mainContext.fetch(descriptor)
        } catch {
            errorMessage = "查找相关文章失败: \(error.localizedDescription)"
            return []
        }
    }
    
    // 从文章中提取关键词
    func extractKeywords(from article: Article) -> [String] {
        var keywords: [String] = []
        
        // 这里可以使用NaturalLanguage框架进行关键词提取
        // 简单实现：提取标题中的名词和形容词
        if let content = article.content ?? article.summary {
            // 实际应用中应使用NaturalLanguage框架
            // 这里简化处理，仅作示例
            let words = content.components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 2 } // 过滤短词
                .prefix(10) // 取前10个
            
            keywords = Array(words)
        }
        
        return keywords
    }
}
