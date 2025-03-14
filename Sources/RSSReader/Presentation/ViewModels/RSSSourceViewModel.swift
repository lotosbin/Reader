import Foundation
import SwiftUI
import SwiftData
import Combine

class RSSSourceViewModel: ObservableObject {
    @Published var sources: [RSSSource] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: RSSRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: RSSRepositoryProtocol) {
        self.repository = repository
        loadSources()
    }
    
    func loadSources() {
        isLoading = true
        errorMessage = nil
        
        do {
            sources = try repository.getRSSSources()
            isLoading = false
        } catch {
            errorMessage = "加载RSS源失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func addSource(title: String, url: URL, websiteURL: URL? = nil, description: String? = nil, category: String? = nil) {
        let newSource = RSSSource(
            title: title,
            url: url,
            websiteURL: websiteURL,
            description: description,
            category: category
        )
        
        do {
            try repository.addRSSSource(newSource)
            loadSources()
        } catch {
            errorMessage = "添加RSS源失败: \(error.localizedDescription)"
        }
    }
    
    func updateSource(_ source: RSSSource) {
        do {
            try repository.updateRSSSource(source)
            loadSources()
        } catch {
            errorMessage = "更新RSS源失败: \(error.localizedDescription)"
        }
    }
    
    func deleteSource(_ source: RSSSource) {
        do {
            try repository.deleteRSSSource(source)
            loadSources()
        } catch {
            errorMessage = "删除RSS源失败: \(error.localizedDescription)"
        }
    }
    
    func discoverFeeds(from websiteURL: URL) async -> [URL] {
        isLoading = true
        errorMessage = nil
        
        do {
            let feeds = try await repository.discoverFeeds(from: websiteURL)
            isLoading = false
            return feeds
        } catch {
            errorMessage = "发现RSS源失败: \(error.localizedDescription)"
            isLoading = false
            return []
        }
    }
    
    func fetchFeed(from url: URL) async -> RSSFeed? {
        isLoading = true
        errorMessage = nil
        
        do {
            let feed = try await repository.fetchFeed(from: url)
            isLoading = false
            return feed
        } catch {
            errorMessage = "获取Feed内容失败: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
}
