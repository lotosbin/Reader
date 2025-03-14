import SwiftUI
import SwiftData

struct KeywordGroupsView: View {
    @StateObject private var viewModel: KeywordGroupViewModel
    @State private var showingAddSheet = false
    @State private var newGroupName = ""
    @State private var newKeywords = ""
    
    init(modelContainer: ModelContainer) {
        _viewModel = StateObject(wrappedValue: KeywordGroupViewModel(modelContainer: modelContainer))
    }
    
    init() {
        // 这里需要在实际应用中注入正确的modelContainer
        // 这是一个简化的初始化方法，实际应用中应使用依赖注入
        let modelContainer = try! ModelContainer(for: RSSSource.self, Article.self, KeywordGroup.self)
        _viewModel = StateObject(wrappedValue: KeywordGroupViewModel(modelContainer: modelContainer))
    }
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                } else if viewModel.keywordGroups.isEmpty {
                    Text("没有关键词组，请添加")
                        .foregroundColor(.secondary)
                } else {
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
                    .onDelete(perform: deleteGroup)
                }
            }
            .navigationTitle("关键词聚合")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Label("添加", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .refreshable {
                viewModel.loadKeywordGroups()
            }
            .sheet(isPresented: $showingAddSheet) {
                addKeywordGroupView
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    private var addKeywordGroupView: some View {
        NavigationView {
            Form {
                Section(header: Text("关键词组信息")) {
                    TextField("名称", text: $newGroupName)
                    TextField("关键词（用逗号分隔）", text: $newKeywords)
                }
                
                Button("添加") {
                    addKeywordGroup()
                }
                .disabled(newGroupName.isEmpty || newKeywords.isEmpty)
            }
            .navigationTitle("添加关键词组")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showingAddSheet = false
                        resetForm()
                    }
                }
            }
        }
    }
    
    private func addKeywordGroup() {
        let keywords = newKeywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        viewModel.addKeywordGroup(name: newGroupName, keywords: keywords)
        showingAddSheet = false
        resetForm()
    }
    
    private func resetForm() {
        newGroupName = ""
        newKeywords = ""
    }
    
    private func deleteGroup(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteKeywordGroup(viewModel.keywordGroups[index])
        }
    }
}

struct KeywordGroupDetailView: View {
    let group: KeywordGroup
    @ObservedObject var viewModel: KeywordGroupViewModel
    @State private var relatedArticles: [Article] = []
    @State private var isLoading = false
    
    var body: some View {
        List {
            Section(header: Text("关键词")) {
                ForEach(group.keywords, id: \.self) { keyword in
                    Text(keyword)
                }
            }
            
            Section(header: Text("相关文章")) {
                if isLoading {
                    ProgressView("加载中...")
                } else if relatedArticles.isEmpty {
                    Text("没有找到相关文章")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(relatedArticles) { article in
                        NavigationLink(destination: ArticleDetailView(article: article, viewModel: ArticleViewModel(repository: RSSRepository(modelContainer: try! ModelContainer(for: RSSSource.self, Article.self, KeywordGroup.self))))) {
                            VStack(alignment: .leading) {
                                Text(article.title)
                                    .font(.headline)
                                if let source = article.source {
                                    Text("来源: \(source.title)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let date = article.publishDate {
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .onAppear {
            loadRelatedArticles()
        }
    }
    
    private func loadRelatedArticles() {
        isLoading = true
        relatedArticles = viewModel.findRelatedArticles(for: group)
        isLoading = false
    }
}
