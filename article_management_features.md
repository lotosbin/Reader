# iOS RSS阅读应用文章管理功能实现

本文档详细描述了iOS RSS阅读应用文章管理功能的实现，包括关键词聚合、阅读状态管理、收藏功能、分享功能、相关讨论功能和关联文章推荐等。实现遵循MVVM架构模式和iOS开发最佳实践。

## 1. 关键词聚合功能

关键词聚合是本应用的核心特色功能之一，它允许用户根据关键词组（如"软件架构师"及其相关关键词"架构"、"软件架构师"等）自动聚合相关文章，实现无感的信息获取和有目标的阅读。

### 1.1 数据模型

```swift
import Foundation
import CoreData

// MARK: - 数据模型
struct KeywordGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var keywords: [String]
    var isActive: Bool
    
    init(id: UUID = UUID(), name: String, keywords: [String], isActive: Bool = true) {
        self.id = id
        self.name = name
        self.keywords = keywords
        self.isActive = isActive
    }
    
    static func == (lhs: KeywordGroup, rhs: KeywordGroup) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Core Data 扩展
extension KeywordGroup {
    init(from entity: KeywordGroupEntity) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        
        if let keywordsData = entity.keywords,
           let keywords = try? JSONDecoder().decode([String].self, from: keywordsData) {
            self.keywords = keywords
        } else {
            self.keywords = []
        }
        
        self.isActive = entity.isActive
    }
    
    func toEntity(in context: NSManagedObjectContext) -> KeywordGroupEntity {
        let entity = KeywordGroupEntity(context: context)
        entity.id = self.id
        entity.name = self.name
        
        if let keywordsData = try? JSONEncoder().encode(self.keywords) {
            entity.keywords = keywordsData
        }
        
        entity.isActive = self.isActive
        return entity
    }
}
```

### 1.2 关键词提取服务

```swift
import Foundation
import NaturalLanguage
import Combine

protocol KeywordExtractionService {
    func extractKeywords(from text: String, maxKeywords: Int) -> [String: Double]
}

class NLKeywordExtractionService: KeywordExtractionService {
    private let stopWords: Set<String> = ["的", "了", "和", "是", "在", "我", "有", "这", "个", "你", "们", "中", "为", "以", "到", "对", "等", "与", "之", "而", "也", "就", "要", "从", "但", "于", "一", "地", "上", "下", "年", "月", "日", "时", "分", "秒", "the", "a", "an", "and", "or", "but", "is", "are", "was", "were", "be", "been", "being", "in", "on", "at", "to", "for", "with", "by", "about", "against", "between", "into", "through", "during", "before", "after", "above", "below", "from", "up", "down", "of", "off", "over", "under", "again", "further", "then", "once", "here", "there", "when", "where", "why", "how", "all", "any", "both", "each", "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only", "own", "same", "so", "than", "too", "very", "s", "t", "can", "will", "just", "don", "should", "now"]
    
    func extractKeywords(from text: String, maxKeywords: Int = 10) -> [String: Double] {
        // 创建分词器
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        // 词频统计
        var wordFrequency: [String: Int] = [:]
        
        // 遍历所有词
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let word = String(text[tokenRange]).lowercased()
            
            // 过滤停用词和短词
            if !self.stopWords.contains(word) && word.count > 1 {
                wordFrequency[word, default: 0] += 1
            }
            
            return true
        }
        
        // 计算TF-IDF值（这里简化为词频）
        let totalWords = wordFrequency.values.reduce(0, +)
        var keywords: [String: Double] = [:]
        
        for (word, frequency) in wordFrequency {
            let score = Double(frequency) / Double(totalWords)
            keywords[word] = score
        }
        
        // 按分数排序并限制数量
        let sortedKeywords = keywords.sorted { $0.value > $1.value }
        let limitedKeywords = sortedKeywords.prefix(maxKeywords)
        
        return Dictionary(uniqueKeysWithValues: limitedKeywords)
    }
}
```

### 1.3 关键词聚合用例

```swift
import Foundation
import Combine

class KeywordAggregationUseCase {
    private let articleRepository: ArticleRepository
    private let keywordRepository: KeywordRepository
    private let keywordExtractionService: KeywordExtractionService
    
    init(
        articleRepository: ArticleRepository,
        keywordRepository: KeywordRepository,
        keywordExtractionService: KeywordExtractionService
    ) {
        self.articleRepository = articleRepository
        self.keywordRepository = keywordRepository
        self.keywordExtractionService = keywordExtractionService
    }
    
    func getKeywordGroups() -> AnyPublisher<[KeywordGroup], Error> {
        return keywordRepository.getKeywordGroups()
    }
    
    func saveKeywordGroup(_ group: KeywordGroup) -> AnyPublisher<KeywordGroup, Error> {
        return keywordRepository.saveKeywordGroup(group)
    }
    
    func deleteKeywordGroup(id: UUID) -> AnyPublisher<Void, Error> {
        return keywordRepository.deleteKeywordGroup(id: id)
    }
    
    func getArticlesByKeywordGroup(groupId: UUID) -> AnyPublisher<[Article], Error> {
        return Publishers.CombineLatest(
            keywordRepository.getKeywordGroup(id: groupId),
            articleRepository.getArticles(filters: nil)
        )
        .map { group, articles -> [Article] in
            // 过滤出包含关键词组中任一关键词的文章
            return articles.filter { article in
                // 检查文章标题和描述
                let titleAndDesc = "\(article.title) \(article.description)".lowercased()
                
                // 检查是否包含关键词组中的任一关键词
                for keyword in group.keywords {
                    if titleAndDesc.contains(keyword.lowercased()) {
                        return true
                    }
                }
                
                // 检查文章提取的关键词
                if let articleKeywords = article.keywords {
                    for groupKeyword in group.keywords {
                        if articleKeywords.keys.contains(where: { $0.lowercased().contains(groupKeyword.lowercased()) }) {
                            return true
                        }
                    }
                }
                
                return false
            }
        }
        .eraseToAnyPublisher()
    }
    
    func extractAndSaveArticleKeywords(articleId: UUID) -> AnyPublisher<Article, Error> {
        return articleRepository.getArticle(id: articleId)
            .flatMap { [weak self] article -> AnyPublisher<Article, Error> in
                guard let self = self else {
                    return Fail(error: NSError(domain: "KeywordAggregationUseCase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                        .eraseToAnyPublisher()
                }
                
                // 提取文章内容的关键词
                let content = "\(article.title) \(article.description) \(article.content ?? "")"
                let keywords = self.keywordExtractionService.extractKeywords(from: content, maxKeywords: 15)
                
                // 更新文章的关键词
                var updatedArticle = article
                updatedArticle.keywords = keywords
                
                // 保存更新后的文章
                return self.articleRepository.saveArticle(updatedArticle)
            }
            .eraseToAnyPublisher()
    }
    
    func processNewArticles() -> AnyPublisher<Int, Error> {
        return articleRepository.getArticles(filters: ArticleFilters(isProcessed: false))
            .flatMap { [weak self] articles -> AnyPublisher<Int, Error> in
                guard let self = self else {
                    return Fail(error: NSError(domain: "KeywordAggregationUseCase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                        .eraseToAnyPublisher()
                }
                
                if articles.isEmpty {
                    return Just(0)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // 为每篇文章提取关键词
                let publishers = articles.map { article in
                    self.extractAndSaveArticleKeywords(articleId: article.id)
                }
                
                return Publishers.MergeMany(publishers)
                    .collect()
                    .map { $0.count }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
```

### 1.4 关键词聚合视图模型

```swift
import Foundation
import Combine
import SwiftUI

class KeywordGroupViewModel: ObservableObject {
    @Published var keywordGroups: [KeywordGroup] = []
    @Published var selectedGroupArticles: [Article] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let keywordAggregationUseCase: KeywordAggregationUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(keywordAggregationUseCase: KeywordAggregationUseCase) {
        self.keywordAggregationUseCase = keywordAggregationUseCase
        loadKeywordGroups()
    }
    
    func loadKeywordGroups() {
        isLoading = true
        keywordAggregationUseCase.getKeywordGroups()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] groups in
                    self?.keywordGroups = groups
                }
            )
            .store(in: &cancellables)
    }
    
    func saveKeywordGroup(_ group: KeywordGroup) {
        isLoading = true
        keywordAggregationUseCase.saveKeywordGroup(group)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadKeywordGroups()
                }
            )
            .store(in: &cancellables)
    }
    
    func deleteKeywordGroup(at indexSet: IndexSet) {
        guard let index = indexSet.first, index < keywordGroups.count else { return }
        let groupId = keywordGroups[index].id
        
        isLoading = true
        keywordAggregationUseCase.deleteKeywordGroup(id: groupId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadKeywordGroups()
                }
            )
            .store(in: &cancellables)
    }
    
    func loadArticlesByKeywordGroup(groupId: UUID) {
        isLoading = true
        keywordAggregationUseCase.getArticlesByKeywordGroup(groupId: groupId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.selectedGroupArticles = articles
                }
            )
            .store(in: &cancellables)
    }
    
    func processNewArticles() {
        isLoading = true
        keywordAggregationUseCase.processNewArticles()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] count in
                    print("Processed \(count) new articles")
                    if let selectedGroup = self?.keywordGroups.first {
                        self?.loadArticlesByKeywordGroup(groupId: selectedGroup.id)
                    }
                }
            )
            .store(in: &cancellables)
    }
}
```

### 1.5 关键词聚合视图

```swift
import SwiftUI

struct KeywordGroupListView: View {
    @ObservedObject var viewModel: KeywordGroupViewModel
    @State private var showingAddSheet = false
    @State private var newGroupName = ""
    @State private var newGroupKeywords = ""
    
    var body: some View {
        List {
            ForEach(viewModel.keywordGroups) { group in
                NavigationLink(destination: KeywordGroupDetailView(group: group, viewModel: viewModel)) {
                    VStack(alignment: .leading) {
                        Text(group.name)
                            .font(.headline)
                        
                        Text(group.keywords.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .onDelete(perform: viewModel.deleteKeywordGroup)
        }
        .navigationTitle("关键词聚合")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: viewModel.processNewArticles) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .refreshable {
            viewModel.loadKeywordGroups()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                Form {
                    Section(header: Text("关键词组名称")) {
                        TextField("例如：软件架构师", text: $newGroupName)
                    }
                    
                    Section(header: Text("关键词（用逗号分隔）")) {
                        TextField("例如：架构,软件架构师,设计模式", text: $newGroupKeywords)
                    }
                    
                    Section {
                        Button("添加关键词组") {
                            addKeywordGroup()
                        }
                        .disabled(newGroupName.isEmpty || newGroupKeywords.isEmpty)
                    }
                }
                .navigationTitle("添加关键词组")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("取消") {
                            showingAddSheet = false
                            newGroupName = ""
                            newGroupKeywords = ""
                        }
                    }
                }
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Alert(
                title: Text("错误"),
                message: Text(viewModel.error?.localizedDescription ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private func addKeywordGroup() {
        let keywords = newGroupKeywords
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let newGroup = KeywordGroup(
            id: UUID(),
            name: newGroupName.trimmingCharacters(in: .whitespacesAndNewlines),
            keywords: keywords,
            isActive: true
        )
        
        viewModel.saveKeywordGroup(newGroup)
        showingAddSheet = false
        newGroupName = ""
        newGroupKeywords = ""
    }
}

struct KeywordGroupDetailView: View {
    let group: KeywordGroup
    @ObservedObject var viewModel: KeywordGroupViewModel
    @State private var showingEditSheet = false
    @State private var editedName: String = ""
    @State private var editedKeywords: String = ""
    
    var body: some View {
        List {
            Section(header: Text("关键词")) {
                ForEach(group.keywords, id: \.self) { keyword in
                    Text(keyword)
                }
            }
            
            Section(header: Text("相关文章")) {
                if viewModel.selectedGroupArticles.isEmpty && !viewModel.isLoading {
                    Text("没有找到相关文章")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(viewModel.selectedGroupArticles) { article in
                        NavigationLink(destination: ArticleDetailView(article: article)) {
                            ArticleRow(article: article)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingEditSheet = true }) {
                    Text("编辑")
                }
            }
        }
        .onAppear {
            viewModel.loadArticlesByKeywordGroup(groupId: group.id)
            editedName = group.name
            editedKeywords = group.keywords.joined(separator: ", ")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                Form {
                    Section(header: Text("关键词组名称")) {
                        TextField("名称", text: $editedName)
                    }
                    
                    Section(header: Text("关键词（用逗号分隔）")) {
                        TextField("关键词", text: $editedKeywords)
                    }
                    
                    Section {
                        Button("保存修改") {
                            updateKeywordGroup()
                        }
                        .disabled(editedName.isEmpty || editedKeywords.isEmpty)
                    }
                }
                .navigationTitle("编辑关键词组")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("取消") {
                            showingEditSheet = false
                            editedName = group.name
                            editedKeywords = group.keywords.joined(separator: ", ")
                        }
                    }
                }
            }
        }
    }
    
    private func updateKeywordGroup() {
        let keywords = editedKeywords
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let updatedGroup = KeywordGroup(
            id: group.id,
            name: editedName.trimmingCharacters(in: .whitespacesAndNewlines),
            keywords: keywords,
            isActive: group.isActive
        )
        
        viewModel.saveKeywordGroup(updatedGroup)
        showingEditSheet = false
    }
}
```

## 2. 阅读状态管理功能

阅读状态管理功能允许用户跟踪文章的已读/未读状态和阅读进度，帮助用户更好地管理阅读体验。

### 2.1 阅读状态管理用例

```swift
import Foundation
import Combine

class ReadingStatusUseCase {
    private let articleRepository: ArticleRepository
    
    init(articleRepository: ArticleRepository) {
        self.articleRepository = articleRepository
    }
    
    func markArticleAsRead(id: UUID) -> AnyPublisher<Void, Error> {
        return articleRepository.updateArticleStatus(id: id, isRead: true, isFavorite: nil, readingProgress: nil)
    }
    
    func markArticleAsUnread(id: UUID) -> AnyPublisher<Void, Error> {
        return articleRepository.updateArticleStatus(id: id, isRead: false, isFavorite: nil, readingProgress: nil)
    }
    
    func updateReadingProgress(id: UUID, progress: Double) -> AnyPublisher<Void, Error> {
        // 如果阅读进度超过80%，自动标记为已读
        let isRead = progress >= 0.8 ? true : nil
        
        return articleRepository.updateArticleStatus(id: id, isRead: isRead, isFavorite: nil, readingProgress: progress)
    }
    
    func getUnreadArticles() -> AnyPublisher<[Article], Error> {
        return articleRepository.getArticles(filters: ArticleFilters(isRead: false))
    }
    
    func getReadArticles() -> AnyPublisher<[Article], Error> {
        return articleRepository.getArticles(filters: ArticleFilters(isRead: true))
    }
    
    func getArticlesWithProgress() -> AnyPublisher<[Article], Error> {
        return articleRepository.getArticles(filters: nil)
            .map { articles in
                return articles.filter { $0.readingProgress != nil && $0.readingProgress! > 0 && $0.readingProgress! < 1.0 }
            }
            .eraseToAnyPublisher()
    }
}
```

### 2.2 阅读状态视图模型

```swift
import Foundation
import Combine
import SwiftUI

class ReadingStatusViewModel: ObservableObject {
    @Published var unreadArticles: [Article] = []
    @Published var inProgressArticles: [Article] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let readingStatusUseCase: ReadingStatusUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(readingStatusUseCase: ReadingStatusUseCase) {
        self.readingStatusUseCase = readingStatusUseCase
        loadUnreadArticles()
        loadInProgressArticles()
    }
    
    func loadUnreadArticles() {
        isLoading = true
        readingStatusUseCase.getUnreadArticles()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.unreadArticles = articles
                }
            )
            .store(in: &cancellables)
    }
    
    func loadInProgressArticles() {
        isLoading = true
        readingStatusUseCase.getArticlesWithProgress()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.inProgressArticles = articles
                }
            )
            .store(in: &cancellables)
    }
    
    func markAsRead(articleId: UUID) {
        readingStatusUseCase.markArticleAsRead(id: articleId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadUnreadArticles()
                    self?.loadInProgressArticles()
                }
            )
            .store(in: &cancellables)
    }
    
    func markAsUnread(articleId: UUID) {
        readingStatusUseCase.markArticleAsUnread(id: articleId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadUnreadArticles()
                    self?.loadInProgressArticles()
                }
            )
            .store(in: &cancellables)
    }
    
    func updateReadingProgress(articleId: UUID, progress: Double) {
        readingStatusUseCase.updateReadingProgress(id: articleId, progress: progress)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    // 如果进度达到100%，更新列表
                    if progress >= 1.0 {
                        self?.loadUnreadArticles()
                        self?.loadInProgressArticles()
                    }
                }
            )
            .store(in: &cancellables)
    }
}
```

### 2.3 阅读状态视图

```swift
import SwiftUI

struct ReadingStatusView: View {
    @ObservedObject var viewModel: ReadingStatusViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("阅读状态", selection: $selectedTab) {
                Text("未读").tag(0)
                Text("进行中").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            if selectedTab == 0 {
                UnreadArticlesView(viewModel: viewModel)
            } else {
                InProgressArticlesView(viewModel: viewModel)
            }
        }
        .navigationTitle("阅读状态")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Alert(
                title: Text("错误"),
                message: Text(viewModel.error?.localizedDescription ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
}

struct UnreadArticlesView: View {
    @ObservedObject var viewModel: ReadingStatusViewModel
    
    var body: some View {
        List {
            if viewModel.unreadArticles.isEmpty && !viewModel.isLoading {
                Text("没有未读文章")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.unreadArticles) { article in
                    NavigationLink(destination: ArticleDetailView(article: article)) {
                        ArticleRow(article: article)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.markAsRead(articleId: article.id)
                        } label: {
                            Label("标为已读", systemImage: "envelope.open")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadUnreadArticles()
        }
    }
}

struct InProgressArticlesView: View {
    @ObservedObject var viewModel: ReadingStatusViewModel
    
    var body: some View {
        List {
            if viewModel.inProgressArticles.isEmpty && !viewModel.isLoading {
                Text("没有进行中的文章")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.inProgressArticles) { article in
                    NavigationLink(destination: ArticleDetailView(article: article)) {
                        VStack(alignment: .leading, spacing: 4) {
                            ArticleRow(article: article)
                            
                            if let progress = article.readingProgress {
                                ProgressView(value: progress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .frame(height: 4)
                                
                                Text("\(Int(progress * 100))% 已读")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadInProgressArticles()
        }
    }
}
```

## 3. 收藏和分享功能

收藏和分享功能允许用户保存重要文章并与他人分享内容。

### 3.1 收藏功能用例

```swift
import Foundation
import Combine

class FavoriteArticlesUseCase {
    private let articleRepository: ArticleRepository
    
    init(articleRepository: ArticleRepository) {
        self.articleRepository = articleRepository
    }
    
    func getFavoriteArticles() -> AnyPublisher<[Article], Error> {
        return articleRepository.getArticles(filters: ArticleFilters(isFavorite: true))
    }
    
    func toggleFavorite(id: UUID, isFavorite: Bool) -> AnyPublisher<Void, Error> {
        return articleRepository.updateArticleStatus(id: id, isRead: nil, isFavorite: isFavorite, readingProgress: nil)
    }
}
```

### 3.2 分享功能服务

```swift
import Foundation
import UIKit
import LinkPresentation

class ShareService {
    func shareArticle(article: Article, from viewController: UIViewController, sourceView: UIView) {
        // 创建分享内容
        var items: [Any] = []
        
        // 添加文章标题和链接
        let text = "\(article.title)\n\(article.link)"
        items.append(text)
        
        // 如果有URL，添加URL
        if let url = URL(string: article.link) {
            items.append(url)
            
            // 创建LinkPresentation元数据
            let metadata = LPLinkMetadata()
            metadata.originalURL = url
            metadata.url = url
            metadata.title = article.title
            
            // 如果有图片，添加图片
            if let imageURL = article.imageURL, let imageUrl = URL(string: imageURL) {
                let provider = LinkPresentationItemProvider(metadata: metadata, imageURL: imageUrl)
                items.append(provider)
            }
        }
        
        // 创建活动视图控制器
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // 在iPad上设置弹出位置
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = sourceView
            popoverController.sourceRect = sourceView.bounds
        }
        
        // 显示分享界面
        viewController.present(activityViewController, animated: true, completion: nil)
    }
}

// 自定义LinkPresentation提供者
class LinkPresentationItemProvider: NSItemProvider {
    private let metadata: LPLinkMetadata
    private let imageURL: URL
    
    init(metadata: LPLinkMetadata, imageURL: URL) {
        self.metadata = metadata
        self.imageURL = imageURL
        super.init()
        
        registerMetadata()
    }
    
    private func registerMetadata() {
        // 注册LinkPresentation元数据
        self.registerObject(self.metadata, visibility: .all)
        
        // 异步加载图片
        URLSession.shared.dataTask(with: imageURL) { [weak self] data, response, error in
            guard let self = self, let data = data, let image = UIImage(data: data) else { return }
            
            DispatchQueue.main.async {
                // 更新元数据的图片
                self.metadata.imageProvider = NSItemProvider(object: image)
                
                // 重新注册元数据
                self.registerObject(self.metadata, visibility: .all)
            }
        }.resume()
    }
}
```

### 3.3 收藏视图模型

```swift
import Foundation
import Combine
import SwiftUI

class FavoriteArticlesViewModel: ObservableObject {
    @Published var favoriteArticles: [Article] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let favoriteArticlesUseCase: FavoriteArticlesUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(favoriteArticlesUseCase: FavoriteArticlesUseCase) {
        self.favoriteArticlesUseCase = favoriteArticlesUseCase
        loadFavoriteArticles()
    }
    
    func loadFavoriteArticles() {
        isLoading = true
        favoriteArticlesUseCase.getFavoriteArticles()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.favoriteArticles = articles
                }
            )
            .store(in: &cancellables)
    }
    
    func toggleFavorite(articleId: UUID) {
        guard let index = favoriteArticles.firstIndex(where: { $0.id == articleId }) else { return }
        let isFavorite = !favoriteArticles[index].isFavorite
        
        favoriteArticlesUseCase.toggleFavorite(id: articleId, isFavorite: isFavorite)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadFavoriteArticles()
                }
            )
            .store(in: &cancellables)
    }
}
```

### 3.4 收藏和分享视图

```swift
import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: FavoriteArticlesViewModel
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode {
        case list
        case grid
    }
    
    var body: some View {
        VStack {
            Picker("查看模式", selection: $viewMode) {
                Image(systemName: "list.bullet").tag(ViewMode.list)
                Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            if viewMode == .list {
                favoritesList
            } else {
                favoritesGrid
            }
        }
        .navigationTitle("收藏")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Alert(
                title: Text("错误"),
                message: Text(viewModel.error?.localizedDescription ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    var favoritesList: some View {
        List {
            if viewModel.favoriteArticles.isEmpty && !viewModel.isLoading {
                Text("没有收藏的文章")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.favoriteArticles) { article in
                    NavigationLink(destination: ArticleDetailView(article: article)) {
                        ArticleRow(article: article)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.toggleFavorite(articleId: article.id)
                        } label: {
                            Label("取消收藏", systemImage: "star.slash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        ShareButton(article: article)
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadFavoriteArticles()
        }
    }
    
    var favoritesGrid: some View {
        ScrollView {
            if viewModel.favoriteArticles.isEmpty && !viewModel.isLoading {
                Text("没有收藏的文章")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                    ForEach(viewModel.favoriteArticles) { article in
                        NavigationLink(destination: ArticleDetailView(article: article)) {
                            FavoriteGridItem(article: article)
                        }
                        .contextMenu {
                            Button {
                                viewModel.toggleFavorite(articleId: article.id)
                            } label: {
                                Label("取消收藏", systemImage: "star.slash")
                            }
                            
                            ShareButton(article: article)
                        }
                    }
                }
                .padding()
            }
        }
        .refreshable {
            viewModel.loadFavoriteArticles()
        }
    }
}

struct FavoriteGridItem: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading) {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                }
                .frame(height: 100)
                .clipped()
                .cornerRadius(8)
            } else {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(height: 100)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    )
            }
            
            Text(article.title)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            Text(article.sourceName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ShareButton: View {
    let article: Article
    @State private var showingShareSheet = false
    @State private var shareItem: UIView?
    
    var body: some View {
        Button {
            showingShareSheet = true
        } label: {
            Label("分享", systemImage: "square.and.arrow.up")
        }
        .tint(.blue)
        .background(
            // 隐藏视图，用于获取UIView引用
            Color.clear
                .frame(width: 0, height: 0)
                .background(
                    ViewControllerRepresentable(showingShareSheet: $showingShareSheet, article: article)
                )
        )
    }
}

// 用于在SwiftUI中使用UIKit的分享功能
struct ViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var showingShareSheet: Bool
    let article: Article
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if showingShareSheet {
            let shareService = ShareService()
            shareService.shareArticle(article: article, from: uiViewController, sourceView: uiViewController.view)
            showingShareSheet = false
        }
    }
}
```

## 4. 文章关联功能

文章关联功能根据内容相似度推荐相关文章，包括前置文章、扩展文章等，帮助用户发现更多相关内容。

### 4.1 数据模型

```swift
import Foundation
import CoreData

enum RelationType: String, Codable {
    case prerequisite = "prerequisite"  // 前置文章
    case extension = "extension"        // 扩展文章
    case similar = "similar"            // 相似文章
}

// MARK: - 数据模型
struct ArticleRelation: Identifiable, Codable, Equatable {
    let id: UUID
    var sourceArticleId: UUID
    var targetArticleId: UUID
    var relationType: RelationType
    var relevanceScore: Double
    
    init(id: UUID = UUID(), sourceArticleId: UUID, targetArticleId: UUID, relationType: RelationType, relevanceScore: Double) {
        self.id = id
        self.sourceArticleId = sourceArticleId
        self.targetArticleId = targetArticleId
        self.relationType = relationType
        self.relevanceScore = relevanceScore
    }
    
    static func == (lhs: ArticleRelation, rhs: ArticleRelation) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Core Data 扩展
extension ArticleRelation {
    init(from entity: ArticleRelationEntity) {
        self.id = entity.id ?? UUID()
        self.sourceArticleId = entity.sourceArticleId ?? UUID()
        self.targetArticleId = entity.targetArticleId ?? UUID()
        
        if let relationTypeString = entity.relationType,
           let relationType = RelationType(rawValue: relationTypeString) {
            self.relationType = relationType
        } else {
            self.relationType = .similar
        }
        
        self.relevanceScore = entity.relevanceScore
    }
    
    func toEntity(in context: NSManagedObjectContext) -> ArticleRelationEntity {
        let entity = ArticleRelationEntity(context: context)
        entity.id = self.id
        entity.sourceArticleId = self.sourceArticleId
        entity.targetArticleId = self.targetArticleId
        entity.relationType = self.relationType.rawValue
        entity.relevanceScore = self.relevanceScore
        return entity
    }
}
```

### 4.2 文章关联服务

```swift
import Foundation
import NaturalLanguage
import Combine

protocol ArticleRelationService {
    func findRelatedArticles(article: Article, allArticles: [Article], maxResults: Int) -> [ArticleRelation]
}

class NLArticleRelationService: ArticleRelationService {
    private let keywordExtractionService: KeywordExtractionService
    
    init(keywordExtractionService: KeywordExtractionService) {
        self.keywordExtractionService = keywordExtractionService
    }
    
    func findRelatedArticles(article: Article, allArticles: [Article], maxResults: Int = 10) -> [ArticleRelation] {
        // 排除当前文章
        let otherArticles = allArticles.filter { $0.id != article.id }
        if otherArticles.isEmpty {
            return []
        }
        
        // 如果文章没有关键词，先提取关键词
        let sourceKeywords: [String: Double]
        if let keywords = article.keywords, !keywords.isEmpty {
            sourceKeywords = keywords
        } else {
            let content = "\(article.title) \(article.description) \(article.content ?? "")"
            sourceKeywords = keywordExtractionService.extractKeywords(from: content, maxKeywords: 15)
        }
        
        // 计算与其他文章的相似度
        var similarities: [(article: Article, score: Double, type: RelationType)] = []
        
        for otherArticle in otherArticles {
            // 获取目标文章的关键词
            let targetKeywords: [String: Double]
            if let keywords = otherArticle.keywords, !keywords.isEmpty {
                targetKeywords = keywords
            } else {
                let content = "\(otherArticle.title) \(otherArticle.description) \(otherArticle.content ?? "")"
                targetKeywords = keywordExtractionService.extractKeywords(from: content, maxKeywords: 15)
            }
            
            // 计算余弦相似度
            let similarity = calculateCosineSimilarity(sourceKeywords: sourceKeywords, targetKeywords: targetKeywords)
            
            // 确定关系类型
            let relationType = determineRelationType(sourceArticle: article, targetArticle: otherArticle)
            
            similarities.append((otherArticle, similarity, relationType))
        }
        
        // 按相似度排序并限制结果数量
        let sortedSimilarities = similarities.sorted { $0.score > $1.score }
        let limitedSimilarities = sortedSimilarities.prefix(maxResults)
        
        // 创建文章关系
        return limitedSimilarities.map { similarity in
            ArticleRelation(
                id: UUID(),
                sourceArticleId: article.id,
                targetArticleId: similarity.article.id,
                relationType: similarity.type,
                relevanceScore: similarity.score
            )
        }
    }
    
    // 计算余弦相似度
    private func calculateCosineSimilarity(sourceKeywords: [String: Double], targetKeywords: [String: Double]) -> Double {
        // 获取所有唯一关键词
        var allKeywords = Set<String>()
        for (keyword, _) in sourceKeywords {
            allKeywords.insert(keyword)
        }
        for (keyword, _) in targetKeywords {
            allKeywords.insert(keyword)
        }
        
        // 创建向量
        var sourceVector: [Double] = []
        var targetVector: [Double] = []
        
        for keyword in allKeywords {
            sourceVector.append(sourceKeywords[keyword] ?? 0)
            targetVector.append(targetKeywords[keyword] ?? 0)
        }
        
        // 计算余弦相似度
        let dotProduct = zip(sourceVector, targetVector).map { $0 * $1 }.reduce(0, +)
        let sourceNorm = sqrt(sourceVector.map { $0 * $0 }.reduce(0, +))
        let targetNorm = sqrt(targetVector.map { $0 * $0 }.reduce(0, +))
        
        if sourceNorm == 0 || targetNorm == 0 {
            return 0
        }
        
        return dotProduct / (sourceNorm * targetNorm)
    }
    
    // 确定关系类型
    private func determineRelationType(sourceArticle: Article, targetArticle: Article) -> RelationType {
        // 根据发布日期判断前置文章
        if targetArticle.pubDate < sourceArticle.pubDate {
            return .prerequisite
        }
        
        // 根据内容长度判断扩展文章
        let sourceContentLength = (sourceArticle.content ?? "").count
        let targetContentLength = (targetArticle.content ?? "").count
        
        if targetContentLength > sourceContentLength * 1.5 {
            return .extension
        }
        
        // 默认为相似文章
        return .similar
    }
}
```

### 4.3 文章关联用例

```swift
import Foundation
import Combine

class ArticleRelationsUseCase {
    private let articleRepository: ArticleRepository
    private let articleRelationService: ArticleRelationService
    
    init(
        articleRepository: ArticleRepository,
        articleRelationService: ArticleRelationService
    ) {
        self.articleRepository = articleRepository
        self.articleRelationService = articleRelationService
    }
    
    func getRelatedArticles(forArticleId: UUID, relationType: RelationType? = nil) -> AnyPublisher<[Article], Error> {
        return articleRepository.getRelatedArticles(forArticleId: forArticleId, relationType: relationType)
    }
    
    func findAndSaveRelatedArticles(articleId: UUID) -> AnyPublisher<[ArticleRelation], Error> {
        return Publishers.CombineLatest(
            articleRepository.getArticle(id: articleId),
            articleRepository.getArticles(filters: nil)
        )
        .flatMap { [weak self] (article, allArticles) -> AnyPublisher<[ArticleRelation], Error> in
            guard let self = self else {
                return Fail(error: NSError(domain: "ArticleRelationsUseCase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                    .eraseToAnyPublisher()
            }
            
            // 查找相关文章
            let relations = self.articleRelationService.findRelatedArticles(article: article, allArticles: allArticles, maxResults: 10)
            
            if relations.isEmpty {
                return Just([])
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            
            // 保存关系
            let savePublishers = relations.map { self.articleRepository.saveArticleRelation($0) }
            
            return Publishers.MergeMany(savePublishers)
                .collect()
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    func processNewArticlesForRelations() -> AnyPublisher<Int, Error> {
        return articleRepository.getArticles(filters: ArticleFilters(isRelationsProcessed: false))
            .flatMap { [weak self] articles -> AnyPublisher<Int, Error> in
                guard let self = self else {
                    return Fail(error: NSError(domain: "ArticleRelationsUseCase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                        .eraseToAnyPublisher()
                }
                
                if articles.isEmpty {
                    return Just(0)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // 为每篇文章查找相关文章
                let publishers = articles.map { article in
                    self.findAndSaveRelatedArticles(articleId: article.id)
                        .map { _ in 1 }
                        .catch { _ in Just(0) }
                }
                
                return Publishers.MergeMany(publishers)
                    .collect()
                    .map { $0.reduce(0, +) }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
```

### 4.4 文章关联视图模型

```swift
import Foundation
import Combine
import SwiftUI

class ArticleRelationsViewModel: ObservableObject {
    @Published var relatedArticles: [RelationType: [Article]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let articleRelationsUseCase: ArticleRelationsUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(articleRelationsUseCase: ArticleRelationsUseCase) {
        self.articleRelationsUseCase = articleRelationsUseCase
    }
    
    func loadRelatedArticles(forArticleId: UUID) {
        isLoading = true
        
        // 加载所有类型的相关文章
        articleRelationsUseCase.getRelatedArticles(forArticleId: forArticleId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] articles in
                    // 按关系类型分组
                    var groupedArticles: [RelationType: [Article]] = [
                        .prerequisite: [],
                        .extension: [],
                        .similar: []
                    ]
                    
                    for article in articles {
                        if let relation = article.relation, let type = RelationType(rawValue: relation.relationType) {
                            groupedArticles[type, default: []].append(article)
                        }
                    }
                    
                    // 按相关度排序
                    for (type, typeArticles) in groupedArticles {
                        groupedArticles[type] = typeArticles.sorted {
                            ($0.relation?.relevanceScore ?? 0) > ($1.relation?.relevanceScore ?? 0)
                        }
                    }
                    
                    self?.relatedArticles = groupedArticles
                }
            )
            .store(in: &cancellables)
    }
    
    func findAndSaveRelatedArticles(articleId: UUID) {
        isLoading = true
        articleRelationsUseCase.findAndSaveRelatedArticles(articleId: articleId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadRelatedArticles(forArticleId: articleId)
                }
            )
            .store(in: &cancellables)
    }
}
```

### 4.5 文章关联视图

```swift
import SwiftUI

struct ArticleRelationsView: View {
    let article: Article
    @ObservedObject var viewModel: ArticleRelationsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if allRelatedArticles.isEmpty {
                Text("没有找到相关文章")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // 前置文章
                if let prerequisites = viewModel.relatedArticles[.prerequisite], !prerequisites.isEmpty {
                    RelatedArticleSection(title: "前置文章", articles: prerequisites)
                }
                
                // 扩展文章
                if let extensions = viewModel.relatedArticles[.extension], !extensions.isEmpty {
                    RelatedArticleSection(title: "扩展阅读", articles: extensions)
                }
                
                // 相似文章
                if let similar = viewModel.relatedArticles[.similar], !similar.isEmpty {
                    RelatedArticleSection(title: "相似文章", articles: similar)
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.loadRelatedArticles(forArticleId: article.id)
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Alert(
                title: Text("错误"),
                message: Text(viewModel.error?.localizedDescription ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private var allRelatedArticles: [Article] {
        let prerequisites = viewModel.relatedArticles[.prerequisite] ?? []
        let extensions = viewModel.relatedArticles[.extension] ?? []
        let similar = viewModel.relatedArticles[.similar] ?? []
        return prerequisites + extensions + similar
    }
}

struct RelatedArticleSection: View {
    let title: String
    let articles: [Article]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(articles) { article in
                        NavigationLink(destination: ArticleDetailView(article: article)) {
                            RelatedArticleCard(article: article)
                        }
                    }
                }
            }
        }
    }
}

struct RelatedArticleCard: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                }
                .frame(width: 160, height: 90)
                .clipped()
                .cornerRadius(8)
            } else {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(width: 160, height: 90)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    )
            }
            
            Text(article.title)
                .font(.subheadline)
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)
            
            Text(article.sourceName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 160)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
```

## 5. 相关讨论功能

相关讨论功能允许用户对文章进行评论和讨论，促进用户之间的交流和信息共享。

### 5.1 数据模型

```swift
import Foundation
import CoreData

// MARK: - 数据模型
struct Discussion: Identifiable, Codable, Equatable {
    let id: UUID
    var articleId: UUID
    var userId: String
    var userName: String
    var content: String
    var createdAt: Date
    var parentId: UUID?
    var likes: Int
    
    init(id: UUID = UUID(), articleId: UUID, userId: String, userName: String, content: String, createdAt: Date = Date(), parentId: UUID? = nil, likes: Int = 0) {
        self.id = id
        self.articleId = articleId
        self.userId = userId
        self.userName = userName
        self.content = content
        self.createdAt = createdAt
        self.parentId = parentId
        self.likes = likes
    }
    
    static func == (lhs: Discussion, rhs: Discussion) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Core Data 扩展
extension Discussion {
    init(from entity: DiscussionEntity) {
        self.id = entity.id ?? UUID()
        self.articleId = entity.articleId ?? UUID()
        self.userId = entity.userId ?? ""
        self.userName = entity.userName ?? ""
        self.content = entity.content ?? ""
        self.createdAt = entity.createdAt ?? Date()
        self.parentId = entity.parentId
        self.likes = Int(entity.likes)
    }
    
    func toEntity(in context: NSManagedObjectContext) -> DiscussionEntity {
        let entity = DiscussionEntity(context: context)
        entity.id = self.id
        entity.articleId = self.articleId
        entity.userId = self.userId
        entity.userName = self.userName
        entity.content = self.content
        entity.createdAt = self.createdAt
        entity.parentId = self.parentId
        entity.likes = Int32(self.likes)
        return entity
    }
}
```

### 5.2 讨论仓库

```swift
import Foundation
import Combine

// MARK: - 仓库协议
protocol DiscussionRepository {
    func getDiscussions(forArticleId: UUID) -> AnyPublisher<[Discussion], Error>
    func addDiscussion(_ discussion: Discussion) -> AnyPublisher<Discussion, Error>
    func likeDiscussion(id: UUID) -> AnyPublisher<Discussion, Error>
}

// MARK: - 默认实现
class DefaultDiscussionRepository: DiscussionRepository {
    private let localDataSource: LocalDataSource
    
    init(localDataSource: LocalDataSource) {
        self.localDataSource = localDataSource
    }
    
    func getDiscussions(forArticleId: UUID) -> AnyPublisher<[Discussion], Error> {
        return localDataSource.getDiscussions(forArticleId: forArticleId)
    }
    
    func addDiscussion(_ discussion: Discussion) -> AnyPublisher<Discussion, Error> {
        return localDataSource.saveDiscussion(discussion)
    }
    
    func likeDiscussion(id: UUID) -> AnyPublisher<Discussion, Error> {
        return localDataSource.getDiscussion(id: id)
            .flatMap { [weak self] discussion -> AnyPublisher<Discussion, Error> in
                guard let self = self else {
                    return Fail(error: NSError(domain: "DiscussionRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                        .eraseToAnyPublisher()
                }
                
                var updatedDiscussion = discussion
                updatedDiscussion.likes += 1
                
                return self.localDataSource.saveDiscussion(updatedDiscussion)
            }
            .eraseToAnyPublisher()
    }
}
```

### 5.3 讨论用例

```swift
import Foundation
import Combine

class DiscussionUseCase {
    private let discussionRepository: DiscussionRepository
    private let userService: UserService
    
    init(discussionRepository: DiscussionRepository, userService: UserService) {
        self.discussionRepository = discussionRepository
        self.userService = userService
    }
    
    func getDiscussions(forArticleId: UUID) -> AnyPublisher<[Discussion], Error> {
        return discussionRepository.getDiscussions(forArticleId: forArticleId)
    }
    
    func addDiscussion(articleId: UUID, content: String, parentId: UUID? = nil) -> AnyPublisher<Discussion, Error> {
        let currentUser = userService.getCurrentUser()
        
        let discussion = Discussion(
            id: UUID(),
            articleId: articleId,
            userId: currentUser.id,
            userName: currentUser.name,
            content: content,
            createdAt: Date(),
            parentId: parentId,
            likes: 0
        )
        
        return discussionRepository.addDiscussion(discussion)
    }
    
    func likeDiscussion(id: UUID) -> AnyPublisher<Discussion, Error> {
        return discussionRepository.likeDiscussion(id: id)
    }
}
```

### 5.4 讨论视图模型

```swift
import Foundation
import Combine
import SwiftUI

class DiscussionViewModel: ObservableObject {
    @Published var discussions: [Discussion] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let discussionUseCase: DiscussionUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(discussionUseCase: DiscussionUseCase) {
        self.discussionUseCase = discussionUseCase
    }
    
    func loadDiscussions(forArticleId: UUID) {
        isLoading = true
        discussionUseCase.getDiscussions(forArticleId: forArticleId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] discussions in
                    self?.discussions = discussions
                }
            )
            .store(in: &cancellables)
    }
    
    func addDiscussion(articleId: UUID, content: String, parentId: UUID? = nil) {
        isLoading = true
        discussionUseCase.addDiscussion(articleId: articleId, content: content, parentId: parentId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadDiscussions(forArticleId: articleId)
                }
            )
            .store(in: &cancellables)
    }
    
    func likeDiscussion(id: UUID, articleId: UUID) {
        discussionUseCase.likeDiscussion(id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadDiscussions(forArticleId: articleId)
                }
            )
            .store(in: &cancellables)
    }
    
    // 获取讨论树结构
    func getDiscussionTree() -> [DiscussionNode] {
        // 找出所有顶级讨论（没有父评论）
        let topLevelDiscussions = discussions.filter { $0.parentId == nil }
        
        // 为每个顶级讨论构建树
        return topLevelDiscussions.map { discussion in
            buildDiscussionNode(discussion: discussion)
        }
    }
    
    // 递归构建讨论树节点
    private func buildDiscussionNode(discussion: Discussion) -> DiscussionNode {
        // 找出所有回复
        let replies = discussions.filter { $0.parentId == discussion.id }
        
        // 递归构建回复的树
        let replyNodes = replies.map { buildDiscussionNode(discussion: $0) }
        
        return DiscussionNode(discussion: discussion, replies: replyNodes)
    }
}

// 讨论树节点
struct DiscussionNode: Identifiable {
    var id: UUID { discussion.id }
    let discussion: Discussion
    let replies: [DiscussionNode]
}
```

### 5.5 讨论视图

```swift
import SwiftUI

struct DiscussionView: View {
    let article: Article
    @ObservedObject var viewModel: DiscussionViewModel
    @State private var newComment = ""
    @State private var replyingTo: Discussion? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 讨论列表
            if viewModel.isLoading && viewModel.discussions.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if viewModel.discussions.isEmpty {
                Text("暂无评论，快来发表第一条评论吧！")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List {
                    ForEach(viewModel.getDiscussionTree()) { node in
                        DiscussionNodeView(
                            node: node,
                            level: 0,
                            onReply: { discussion in
                                replyingTo = discussion
                            },
                            onLike: { discussion in
                                viewModel.likeDiscussion(id: discussion.id, articleId: article.id)
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
            
            // 评论输入框
            VStack(spacing: 8) {
                if let replyingTo = replyingTo {
                    HStack {
                        Text("回复: \(replyingTo.userName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            self.replyingTo = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                
                HStack {
                    TextField("发表评论...", text: $newComment)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Button(action: submitComment) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: -2)
            }
        }
        .navigationTitle("评论")
        .onAppear {
            viewModel.loadDiscussions(forArticleId: article.id)
        }
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Alert(
                title: Text("错误"),
                message: Text(viewModel.error?.localizedDescription ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private func submitComment() {
        let trimmedComment = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else { return }
        
        viewModel.addDiscussion(
            articleId: article.id,
            content: trimmedComment,
            parentId: replyingTo?.id
        )
        
        newComment = ""
        replyingTo = nil
    }
}

struct DiscussionNodeView: View {
    let node: DiscussionNode
    let level: Int
    let onReply: (Discussion) -> Void
    let onLike: (Discussion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 当前评论
            HStack(alignment: .top) {
                // 缩进
                if level > 0 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .padding(.leading, CGFloat(level * 8))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // 用户信息和时间
                    HStack {
                        Text(node.discussion.userName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(formatDate(node.discussion.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 评论内容
                    Text(node.discussion.content)
                        .font(.body)
                    
                    // 操作按钮
                    HStack {
                        Button(action: {
                            onReply(node.discussion)
                        }) {
                            Label("回复", systemImage: "arrowshape.turn.up.left")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            onLike(node.discussion)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.thumbsup")
                                Text("\(node.discussion.likes)")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // 回复
            if !node.replies.isEmpty {
                ForEach(node.replies) { reply in
                    DiscussionNodeView(
                        node: reply,
                        level: level + 1,
                        onReply: onReply,
                        onLike: onLike
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

## 6. 文章详情视图

文章详情视图整合了所有文章管理功能，包括阅读状态管理、收藏分享、相关讨论和关联文章推荐等。

```swift
import SwiftUI
import WebKit

struct ArticleDetailView: View {
    let article: Article
    @StateObject private var readingStatusViewModel: ReadingStatusViewModel
    @StateObject private var articleRelationsViewModel: ArticleRelationsViewModel
    @StateObject private var discussionViewModel: DiscussionViewModel
    @State private var showingDiscussions = false
    @State private var scrollPosition: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    
    init(article: Article) {
        self.article = article
        
        // 使用依赖注入容器获取视图模型
        let container = DependencyContainer.shared
        _readingStatusViewModel = StateObject(wrappedValue: container.makeReadingStatusViewModel())
        _articleRelationsViewModel = StateObject(wrappedValue: container.makeArticleRelationsViewModel())
        _discussionViewModel = StateObject(wrappedValue: container.makeDiscussionViewModel())
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 文章标题
                Text(article.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // 文章元信息
                HStack {
                    Text(article.sourceName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatDate(article.pubDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 文章图片
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(8)
                }
                
                // 文章内容
                if let content = article.content {
                    ArticleContentView(content: content, onScroll: updateReadingProgress)
                        .frame(height: contentHeight)
                } else {
                    Text(article.description)
                        .font(.body)
                }
                
                Divider()
                
                // 关联文章
                Text("相关文章")
                    .font(.headline)
                
                ArticleRelationsView(article: article, viewModel: articleRelationsViewModel)
                
                Divider()
                
                // 讨论入口
                Button(action: {
                    showingDiscussions = true
                }) {
                    HStack {
                        Text("查看评论")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("scroll")).minY
                    )
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollPosition = value
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    readingStatusViewModel.toggleFavorite(articleId: article.id)
                }) {
                    Image(systemName: article.isFavorite ? "star.fill" : "star")
                        .foregroundColor(article.isFavorite ? .yellow : .blue)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareButton(article: article)
            }
        }
        .onAppear {
            // 计算内容高度
            if let content = article.content {
                let estimatedHeight = Double(content.count) / 4 // 粗略估计
                contentHeight = max(300, min(estimatedHeight, 2000))
            }
            
            // 标记为已读
            readingStatusViewModel.markAsRead(articleId: article.id)
            
            // 加载相关文章
            articleRelationsViewModel.loadRelatedArticles(forArticleId: article.id)
            
            // 加载讨论
            discussionViewModel.loadDiscussions(forArticleId: article.id)
        }
        .sheet(isPresented: $showingDiscussions) {
            NavigationView {
                DiscussionView(article: article, viewModel: discussionViewModel)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func updateReadingProgress(scrollPosition: CGFloat, contentHeight: CGFloat) {
        guard contentHeight > 0 else { return }
        
        // 计算阅读进度
        let visibleHeight = UIScreen.main.bounds.height
        let totalScrollableHeight = contentHeight - visibleHeight
        let progress = min(1.0, max(0.0, -scrollPosition / totalScrollableHeight))
        
        // 更新阅读进度
        readingStatusViewModel.updateReadingProgress(articleId: article.id, progress: progress)
    }
}

struct ArticleContentView: UIViewRepresentable {
    let content: String
    let onScroll: (CGFloat, CGFloat) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false
        
        // 禁用缩放
        webView.scrollView.bouncesZoom = false
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 准备HTML内容
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
                    font-size: 17px;
                    line-height: 1.5;
                    color: #000000;
                    margin: 0;
                    padding: 0;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 4px;
                }
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #FFFFFF;
                        background-color: #000000;
                    }
                }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var parent: ArticleContentView
        
        init(_ parent: ArticleContentView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 获取内容高度
            webView.evaluateJavaScript("document.body.scrollHeight") { (height, error) in
                if let height = height as? CGFloat {
                    // 通知内容高度变化
                    self.parent.onScroll(webView.scrollView.contentOffset.y, height)
                }
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // 通知滚动位置变化
            parent.onScroll(scrollView.contentOffset.y, scrollView.contentSize.height)
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
```

## 7. 总结

本文档详细描述了iOS RSS阅读应用文章管理功能的实现，包括关键词聚合、阅读状态管理、收藏功能、分享功能、相关讨论功能和关联文章推荐等。实现遵循MVVM架构模式和iOS开发最佳实践，使用了依赖注入、协议驱动开发和响应式编程等技术。

核心功能包括：

1. **关键词聚合**：使用NaturalLanguage框架提取文章关键词，根据关键词组自动聚合相关文章，实现无感的信息获取和有目标的阅读。

2. **阅读状态管理**：跟踪文章的已读/未读状态和阅读进度，帮助用户更好地管理阅读体验。

3. **收藏和分享**：允许用户收藏重要文章并与他人分享内容，支持丰富的分享选项和预览。

4. **文章关联**：根据内容相似度推荐相关文章，包括前置文章、扩展文章等，帮助用户发现更多相关内容。

5. **相关讨论**：允许用户对文章进行评论和讨论，支持回复和点赞功能，促进用户之间的交流和信息共享。

这些功能共同构成了一个功能完善、用户体验良好的RSS阅读应用，帮助用户更好地获取、整理、讨论和分享信息。
