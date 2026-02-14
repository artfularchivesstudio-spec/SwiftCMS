import XCTest
@testable import CMSCore

final class CMSCoreTests: XCTestCase {

    func testModuleManagerRegistration() {
        let manager = ModuleManager()
        let module = TestModule(name: "test", priority: 0)
        manager.register(module)
        XCTAssertEqual(manager.modules.count, 1)
        XCTAssertEqual(manager.modules.first?.name, "test")
    }

    func testModuleManagerMultiple() {
        let manager = ModuleManager()
        manager.register(TestModule(name: "a", priority: 10))
        manager.register(TestModule(name: "b", priority: 5))
        manager.register(TestModule(name: "c", priority: 20))
        XCTAssertEqual(manager.modules.count, 3)
    }

    func testHookRegistryInvoke() async throws {
        let registry = HookRegistry()

        registry.register(hookName: "transform") { (value: String) -> String in
            return value.uppercased()
        }

        let result: String = try await registry.invoke(hookName: "transform", args: "hello")
        XCTAssertEqual(result, "HELLO")
    }

    func testHookRegistryMultipleHandlers() async throws {
        let registry = HookRegistry()

        registry.register(hookName: "add") { (value: Int) -> Int in
            return value + 1
        }
        registry.register(hookName: "add") { (value: Int) -> Int in
            return value + 10
        }

        let result: Int = try await registry.invoke(hookName: "add", args: 0)
        XCTAssertEqual(result, 11) // 0 + 1 + 10
    }

    func testHookRegistryNoHandlers() async throws {
        let registry = HookRegistry()
        let result: String = try await registry.invoke(hookName: "missing", args: "unchanged")
        XCTAssertEqual(result, "unchanged")
    }

    func testHandlerCount() {
        let registry = HookRegistry()
        XCTAssertEqual(registry.handlerCount(for: "test"), 0)

        registry.register(hookName: "test") { (v: Int) -> Int in v }
        XCTAssertEqual(registry.handlerCount(for: "test"), 1)
    }
}

// MARK: - Test Helpers

struct TestModule: CmsModule {
    let name: String
    let priority: Int
}
