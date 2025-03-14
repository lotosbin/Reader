import SwiftUI
import SwiftData

struct FeedListView: View {
    @StateObject private var viewModel: RSSSourceViewModel
    @State private var showingAddSheet = false
    @State private var websiteURL = ""
    @State private var discoveredFeeds: [URL] = []
    @State private var isDiscovering = false
    
    init(repository: RSSRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: RSSSourceViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                } else if viewModel.sources.isEmpty {
                    Text("没有RSS源，请添加")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.sources) { source in
                        NavigationLink(destination: ArticleListView(source: source)) {
                            VStack(alignment: .leading) {
                                Text(source.title)
                                    .font(.headline)
                                if let description = source.description {
                                    Text(description)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteSource)
                }
            }
            .navigationTitle("RSS订阅")
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
                viewModel.loadSources()
            }
            .sheet(isPresented: $showingAddSheet) {
                addFeedView
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
    
    private var addFeedView: some View {
        NavigationView {
            Form {
                Section(header: Text("输入网站URL自动发现RSS源")) {
                    TextField("网站URL", text: $websiteURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    Button("发现RSS源") {
                        discoverFeeds()
                    }
                    .disabled(websiteURL.isEmpty || isDiscovering)
                }
                
                if isDiscovering {
                    Section {
                        ProgressView("正在发现RSS源...")
                    }
                } else if !discoveredFeeds.isEmpty {
                    Section(header: Text("发现的RSS源")) {
                        ForEach(discoveredFeeds, id: \.self) { url in
                            Button(action: {
                                addDiscoveredFeed(url)
                            }) {
                                Text(url.absoluteString)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                
                Section(header: Text("手动添加RSS源")) {
                    NavigationLink("手动添加") {
                        ManualAddFeedView(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("添加RSS源")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showingAddSheet = false
                        websiteURL = ""
                        discoveredFeeds = []
                    }
                }
            }
        }
    }
    
    private func discoverFeeds() {
        guard let url = URL(string: websiteURL) else {
            viewModel.errorMessage = "无效的URL"
            return
        }
        
        isDiscovering = true
        discoveredFeeds = []
        
        Task {
            let feeds = await viewModel.discoverFeeds(from: url)
            DispatchQueue.main.async {
                self.discoveredFeeds = feeds
                self.isDiscovering = false
            }
        }
    }
    
    private func addDiscoveredFeed(_ url: URL) {
        Task {
            if let feed = await viewModel.fetchFeed(from: url) {
                DispatchQueue.main.async {
                    viewModel.addSource(
                        title: feed.title,
                        url: url,
                        websiteURL: feed.link,
                        description: feed.description
                    )
                    showingAddSheet = false
                    websiteURL = ""
                    discoveredFeeds = []
                }
            }
        }
    }
    
    private func deleteSource(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteSource(viewModel.sources[index])
        }
    }
}

struct ManualAddFeedView: View {
    @ObservedObject var viewModel: RSSSourceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var urlString = ""
    @State private var description = ""
    @State private var category = ""
    
    var body: some View {
        Form {
            Section {
                TextField("标题", text: $title)
                TextField("RSS URL", text: $urlString)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                TextField("描述", text: $description)
                TextField("分类", text: $category)
            }
            
            Button("添加") {
                addFeed()
            }
            .disabled(title.isEmpty || urlString.isEmpty)
        }
        .navigationTitle("手动添加RSS源")
    }
    
    private func addFeed() {
        guard let url = URL(string: urlString) else {
            viewModel.errorMessage = "无效的URL"
            return
        }
        
        viewModel.addSource(
            title: title,
            url: url,
            description: description.isEmpty ? nil : description,
            category: category.isEmpty ? nil : category
        )
        
        dismiss()
    }
}
