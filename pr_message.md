feat: 实现RSS自动发现与阅读iOS应用

本次提交实现了一个完整的iOS/macOS RSS阅读应用，具有以下特点：

- 使用Swift/SwiftUI/SwiftData技术栈构建
- 采用MVVM架构模式
- 实现RSS自动发现功能
- 支持文章关键词聚合
- 支持阅读进度跟踪
- 支持iOS和macOS平台

主要功能：
1. RSS源管理：添加、编辑和删除RSS源
2. RSS自动发现：从网站URL自动发现RSS源
3. 文章管理：已读/未读状态、收藏功能、阅读进度跟踪
4. 关键词聚合：创建关键词组，自动聚合相关文章
5. 设置功能：刷新间隔、文章数量限制等

技术实现：
- 使用SwiftData进行数据持久化
- 使用FeedKit库解析RSS内容
- 使用SwiftUI构建现代化用户界面
- 使用Combine框架实现响应式编程

所有功能已经过单元测试和UI测试验证。
