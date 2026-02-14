import XCTest
import Vapor
@testable import CMSCore

struct TestModuleA: CmsModule {
    let name = "test-a"
    let priority = 10
    var onRegister: (() -> Void)?
    var onBoot: (() -> Void)?

    func register(app: Application) throws { onRegister?() }
    func boot(app: Application) throws { onBoot?() }
}

struct TestModuleB: CmsModule {
    let name = "test-b"
    let priority = 20
    var onBoot: (() -> Void)?

    func boot(app: Application) throws { onBoot?() }
}

final class ModuleManagerTests: XCTestCase {

    func testModuleRegistration() {
        let manager = ModuleManager()
        manager.register(TestModuleA())
        manager.register(TestModuleB())
        XCTAssertEqual(manager.modules.count, 2)
    }

    func testHookRegistry() async throws {
        let hooks = HookRegistry()
        hooks.register(hookName: "beforeSave") { (data: String) -> String in
            return data.uppercased()
        }

        let result: String = try await hooks.invoke(hookName: "beforeSave", args: "hello")
        XCTAssertEqual(result, "HELLO")
    }

    func testHookChaining() async throws {
        let hooks = HookRegistry()
        hooks.register(hookName: "transform") { (n: Int) -> Int in n + 1 }
        hooks.register(hookName: "transform") { (n: Int) -> Int in n * 2 }

        let result: Int = try await hooks.invoke(hookName: "transform", args: 5)
        XCTAssertEqual(result, 12) // (5 + 1) * 2
    }
}
