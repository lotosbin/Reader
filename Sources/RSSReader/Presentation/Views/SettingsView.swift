import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("maxArticlesPerFeed") private var maxArticlesPerFeed = 50
    @AppStorage("markReadOnScroll") private var markReadOnScroll = true
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("darkModePreference") private var darkModePreference = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("通用设置")) {
                    Picker("刷新间隔", selection: $refreshInterval) {
                        Text("15分钟").tag(15)
                        Text("30分钟").tag(30)
                        Text("1小时").tag(60)
                        Text("2小时").tag(120)
                        Text("4小时").tag(240)
                        Text("手动刷新").tag(0)
                    }
                    
                    Picker("每个Feed最大文章数", selection: $maxArticlesPerFeed) {
                        Text("20").tag(20)
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                        Text("不限制").tag(0)
                    }
                    
                    Toggle("滚动时自动标记为已读", isOn: $markReadOnScroll)
                    
                    Toggle("启用通知", isOn: $enableNotifications)
                }
                
                Section(header: Text("外观")) {
                    Picker("主题", selection: $darkModePreference) {
                        Text("跟随系统").tag(0)
                        Text("浅色模式").tag(1)
                        Text("深色模式").tag(2)
                    }
                }
                
                Section(header: Text("数据管理")) {
                    Button("清除缓存") {
                        // 实现清除缓存的功能
                    }
                    
                    Button("导出订阅") {
                        // 实现导出OPML的功能
                    }
                    
                    Button("导入订阅") {
                        // 实现导入OPML的功能
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("源代码", destination: URL(string: "https://github.com/lotosbin/Reader")!)
                    
                    Link("报告问题", destination: URL(string: "https://github.com/lotosbin/Reader/issues")!)
                }
            }
            .navigationTitle("设置")
        }
    }
}
