# RSSReader - iOS/macOS RSS自动发现与阅读应用

这是一个基于Swift/SwiftUI/SwiftData构建的iOS/macOS RSS阅读应用，支持RSS自动发现功能。

## 项目特点

- 使用Swift、SwiftUI和SwiftData构建
- 采用MVVM架构模式
- 支持RSS自动发现功能
- 支持文章关键词聚合
- 支持阅读进度跟踪
- 支持iOS和macOS平台

## 项目结构

```
RSSReader/
├── App/                  # 应用入口
├── Data/                 # 数据层
│   ├── Models/           # 数据模型
│   ├── DataSources/      # 数据源
│   └── Repositories/     # 数据仓库
├── Domain/               # 领域层
│   ├── UseCases/         # 用例
│   └── Services/         # 服务
└── Presentation/         # 表现层
    ├── ViewModels/       # 视图模型
    └── Views/            # 视图
```

## 核心功能

### RSS自动发现

应用可以从网站URL自动发现RSS源，支持以下发现方式：
- 解析HTML中的`<link>`标签
- 检查常见的RSS路径

### RSS源管理

- 添加、编辑和删除RSS源
- 分类管理RSS源
- 定期自动更新RSS内容

### 文章管理

- 已读/未读状态管理
- 收藏功能
- 阅读进度跟踪

### 关键词聚合

- 创建关键词组
- 根据关键词自动聚合相关文章

## 技术实现

### 数据模型

使用SwiftData进行数据持久化，主要模型包括：
- `RSSSource`: RSS源信息
- `Article`: 文章信息
- `KeywordGroup`: 关键词组

### RSS解析

使用FeedKit库解析RSS、Atom和JSON Feed格式，支持：
- RSS 2.0
- Atom
- JSON Feed

### UI实现

使用SwiftUI构建现代化的用户界面，主要视图包括：
- `FeedListView`: RSS源列表
- `ArticleListView`: 文章列表
- `ArticleDetailView`: 文章详情
- `KeywordGroupsView`: 关键词聚合
- `SettingsView`: 设置

## 安装和使用

### 要求

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### 安装

1. 克隆仓库
2. 打开项目
3. 构建并运行

## 贡献

欢迎提交Pull Request或Issue。

## 许可证

MIT
