import XCTest

final class RSSReaderUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testBasicNavigation() {
        // 测试基本导航功能
        
        // 检查主标签栏是否存在
        XCTAssertTrue(app.tabBars.firstMatch.exists)
        
        // 切换到文章标签
        app.tabBars.buttons["文章"].tap()
        XCTAssertTrue(app.navigationBars["所有文章"].exists)
        
        // 切换到关键词标签
        app.tabBars.buttons["关键词"].tap()
        XCTAssertTrue(app.navigationBars["关键词聚合"].exists)
        
        // 切换到设置标签
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].exists)
        
        // 返回到订阅标签
        app.tabBars.buttons["订阅"].tap()
        XCTAssertTrue(app.navigationBars["RSS订阅"].exists)
    }
    
    func testAddRSSSource() {
        // 测试添加RSS源功能
        
        // 点击添加按钮
        app.navigationBars["RSS订阅"].buttons["添加"].tap()
        
        // 检查添加表单是否出现
        XCTAssertTrue(app.navigationBars["添加RSS源"].exists)
        
        // 输入网站URL
        let urlTextField = app.textFields["网站URL"]
        XCTAssertTrue(urlTextField.exists)
        urlTextField.tap()
        urlTextField.typeText("https://developer.apple.com")
        
        // 点击发现RSS源按钮
        app.buttons["发现RSS源"].tap()
        
        // 等待发现过程完成（这里可能需要等待一段时间）
        let discoveredFeedsExists = app.staticTexts["发现的RSS源"].waitForExistence(timeout: 10)
        XCTAssertTrue(discoveredFeedsExists)
        
        // 取消添加
        app.buttons["取消"].tap()
        
        // 验证返回到RSS订阅列表
        XCTAssertTrue(app.navigationBars["RSS订阅"].exists)
    }
    
    func testSettingsInteraction() {
        // 测试设置界面交互
        
        // 导航到设置标签
        app.tabBars.buttons["设置"].tap()
        
        // 检查设置选项是否存在
        XCTAssertTrue(app.staticTexts["刷新间隔"].exists)
        XCTAssertTrue(app.staticTexts["每个Feed最大文章数"].exists)
        XCTAssertTrue(app.switches["滚动时自动标记为已读"].exists)
        XCTAssertTrue(app.switches["启用通知"].exists)
        
        // 切换一个开关设置
        let markReadSwitch = app.switches["滚动时自动标记为已读"]
        let initialValue = markReadSwitch.value as? String
        markReadSwitch.tap()
        
        // 验证开关状态已改变
        let newValue = markReadSwitch.value as? String
        XCTAssertNotEqual(initialValue, newValue)
    }
}
