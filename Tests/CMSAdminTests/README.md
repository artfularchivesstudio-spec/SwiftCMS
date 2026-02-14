# 🧪 CMSAdmin Testing Guide

This directory contains snapshot tests for the SwiftCMS Admin UI using the **SnapshotTesting** library.

## 📸 Snapshot Testing Overview

Snapshot tests capture the rendered output of our admin UI templates and compare against baseline snapshots. This ensures UI consistency and catches unintended changes.

### Types of Snapshots

1. **HTML Snapshots** - Capture rendered HTML structure
2. **Visual Snapshots** - Capture pixel-perfect rendered output (macOS only)
3. **Lines Snapshots** - Capture text content for simpler comparison

## 🚀 Running Snapshot Tests

```bash
# Run all admin tests
swift test --filter CMSAdminTests

# Run specific snapshot test
swift test --filter testLoginSnapshot

# Update snapshots (if changes are intentional)
# Set IS_RECORDING environment variable
IS_RECORDING=1 swift test --filter CMSAdminTests
```

## 🏗️ Test Structure

### LeafSnapshotTestCase

Base class for all admin snapshot tests:

```swift
final class AdminSnapshotTests: LeafSnapshotTestCase {
    // Inherits:
    // - Application setup
    // - Leaf template configuration
    // - HTML rendering helpers
    // - WebView creation (macOS)
}
```

### Rendering Templates

```swift
// Simple template rendering
let html = try await render("admin/login", context)

// Assert HTML snapshot
assertSnapshot(of: html, as: .lines, named: "Login_Default")

// Visual snapshot (macOS only)
let webView = makeWebView(html: html)
assertSnapshot(of: webView, as: .image(precision: 0.98), named: "Login_Visual")
```

## 📁 Fixtures

### AdminTestFixtures.swift

Contains sample data for admin template testing:

```swift
// Blog content type schema
let schema = AdminTestFixtures.blogSchema

// Sample content types for testing
let types = AdminTestFixtures.sampleContentTypes

// Recent entries for dashboard
let entries = AdminTestFixtures.sampleRecentEntries

// Sample blog entry data
let entryData = AdminTestFixtures.sampleBlogEntryData
```

## 🎨 Writing Snapshot Tests

### Basic HTML Test

```swift
func testLoginPage() async throws {
    struct LoginContext: Encodable {
        let title: String
        let error: String?
    }

    let context = LoginContext(title: "Login", error: nil)
    let html = try await render("admin/login", context)

    assertSnapshot(of: html, as: .lines, named: "Login_Default")
}
```

### Error State Test

```swift
func testLoginError() async throws {
    struct LoginContext: Encodable {
        let title: String
        let error: String?
    }

    let context = LoginContext(
        title: "Login",
        error: "Invalid credentials"
    )
    let html = try await render("admin/login", context)

    assertSnapshot(of: html, as: .lines, named: "Login_Error")
}
```

### Visual Regression Test (macOS)

```swift
#if canImport(WebKit)
@MainActor
func testDashboardVisual() async throws {
    let context = DashboardContext(
        title: "Dashboard",
        typeCount: 5,
        entryCount: 42,
        // ... other fields
    )

    let html = try await render("admin/dashboard", context)
    let webView = makeWebView(html: html)

    // 98% precision to account for minor rendering differences
    assertSnapshot(
        of: webView,
        as: .image(precision: 0.98),
        named: "Dashboard_Visual"
    )
}
#endif
```

## 🔧 Configuration

### Leaf Template Setup

Tests automatically:
- Configure Leaf renderer
- Point to `Resources/Views/` directory
- Register standard Leaf tags

### WebView Configuration (macOS)

```swift
// Base URL for loading local assets
var publicDirectoryURL: URL {
    URL(fileURLWithPath: DirectoryConfiguration.detect().workingDirectory + "Public/")
}

// Custom WebView size
let webView = makeWebView(html: html, size: CGSize(width: 1280, height: 800))
```

## 📸 Snapshot Files

Snapshots are stored in:
```
__Snapshots__/
└── AdminSnapshotTests/
    ├── testLoginSnapshot.1.png  # Visual snapshot
    ├── Login_Default.txt         # HTML snapshot
    └── Login_Error.txt           # HTML snapshot
```

## 🎯 Coverage Areas

### Authentication
- [x] Login page (default state)
- [x] Login page (error state)
- [ ] Password reset forms
- [ ] Two-factor authentication

### Dashboard
- [x] Main dashboard layout
- [x] Dashboard visual rendering
- [ ] Empty state dashboard
- [ ] Dashboard with real data

### Content Management
- [ ] Content type list
- [ ] Content type create/edit forms
- [ ] Content entry list
- [ ] Content entry create/edit forms

### Media Management
- [ ] Media library grid/list views
- [ ] Media upload interface
- [ ] Media edit modal

### User Management
- [ ] User list
- [ ] User create/edit forms
- [ ] Role management interface

### Settings
- [ ] General settings
- [ ] Webhook configuration
- [ ] Plugin management

## 🐛 Troubleshooting

### Snapshot Mismatch

If tests fail due to snapshot mismatches:

1. **Review Changes**: Ensure changes are intentional
2. **Update Snapshots**: Run with `IS_RECORDING=1` if changes are expected
3. **Precision**: Adjust visual snapshot precision if needed (0.95-0.99)
4. **Platform Differences**: HTML snapshots work cross-platform, visual snapshots are macOS-only

### Template Errors

- Check template file paths
- Verify Leaf tags are registered
- Ensure test context matches template expectations

## 🔄 Continuous Integration

### CI Considerations

1. **Snapshot Storage**: Commit snapshot files to Git
2. **Platform**: HTML snapshots work on Linux, visual snapshots require macOS
3. **Timeouts**: Allow extra time for WebView rendering in visual tests
4. **Artifacts**: Store failed snapshots as CI artifacts

### GitHub Actions Example

```yaml
- name: Run Admin Tests
  run: swift test --filter CMSAdminTests

- name: Upload Failed Snapshots
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: failed-snapshots
    path: __Snapshots__/
```

## 📖 Best Practices

1. **Clear Test Names**: Use descriptive names like `testLoginPageWithError`
2. **Context Isolation**: Each test should be independent
3. **Minimal Context**: Provide only necessary data in test contexts
4. **Multiple States**: Test both success and error states
5. **Visual Coverage**: Include visual tests for key UI components
6. **Platform Awareness**: Use `#if canImport(WebKit)` for macOS-only tests

## 🌟 Advanced Techniques

### Dynamic Data Testing

```swift
func testDashboardWithRealData() async throws {
    // Create real content types and entries
    let type = try await createSampleContentType()
    let entries = try await createSampleEntries(count: 10)

    // Fetch real dashboard data
    let dashboardData = try await fetchDashboardData()

    // Render with real data
    let html = try await render("admin/dashboard", dashboardData)
    assertSnapshot(of: html, as: .lines, named: "Dashboard_RealData")
}
```

### Responsive Testing

```swift
#if canImport(WebKit)
@MainActor
func testMobileResponsive() async throws {
    let html = try await render("admin/dashboard", context)

    // Test mobile viewport
    let mobileWebView = makeWebView(
        html: html,
        size: CGSize(width: 375, height: 667)
    )

    assertSnapshot(
        of: mobileWebView,
        as: .image(precision: 0.98),
        named: "Dashboard_Mobile"
    )
}
#endif
```

---

**Emoji Guide**: 🧪 Testing, 📸 Snapshots, 🎨 UI/UX, 🔧 Configuration, 🐛 Debugging, 🔄 CI/CD, 🌟 Advanced, 🎯 Coverage, 📁 Files, 🚀 Running, 📖 Best Practices

## 🔗 Related Documentation

- [Test Utilities](../../Tests/Helpers/README.md)
- [Integration Tests](../../Tests/IntegrationTests/README.md)
- [CMSAdmin Module](../../Sources/CMSAdmin/README.md)
- [Leaf Documentation](https://docs.vapor.codes/leaf/overview/)
- [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing)
