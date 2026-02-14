import Vapor
import Foundation

// MARK: - Plugin Manifest

/// Describes a plugin's metadata and capabilities.
public struct PluginManifest: Codable, Sendable {
    public let name: String
    public let version: String
    public let description: String?
    public let author: String?
    public let dependencies: [String]?
    public let hooks: [String]?
    public let adminPages: [AdminPageEntry]?
    public let fieldTypes: [String]?

    public struct AdminPageEntry: Codable, Sendable {
        public let label: String
        public let icon: String?
        public let path: String
    }
}

// MARK: - Plugin Discovery

/// Scans the Modules/ directory for plugins and loads them.
public struct PluginDiscovery: Sendable {

    /// Scan for plugin manifests in the given directory.
    public static func discover(modulesPath: String = "Modules") -> [PluginManifest] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: modulesPath) else {
            return []
        }

        var manifests: [PluginManifest] = []
        for dir in dirs {
            let manifestPath = "\(modulesPath)/\(dir)/plugin.json"
            guard fm.fileExists(atPath: manifestPath),
                  let data = fm.contents(atPath: manifestPath),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data)
            else {
                continue
            }
            manifests.append(manifest)
        }

        // Sort by dependencies
        return sortByDependencies(manifests)
    }

    /// Topological sort of manifests by dependency order.
    private static func sortByDependencies(_ manifests: [PluginManifest]) -> [PluginManifest] {
        let nameSet = Set(manifests.map(\.name))
        var sorted: [PluginManifest] = []
        var visited = Set<String>()

        func visit(_ manifest: PluginManifest) {
            guard !visited.contains(manifest.name) else { return }
            visited.insert(manifest.name)
            for dep in manifest.dependencies ?? [] {
                if let depManifest = manifests.first(where: { $0.name == dep }) {
                    visit(depManifest)
                }
            }
            sorted.append(manifest)
        }

        for manifest in manifests {
            visit(manifest)
        }

        return sorted
    }
}

// MARK: - Plugin Manager Extension

extension ModuleManager {

    /// Discover and register all plugins from Modules/ directory.
    public func discoverAndRegisterPlugins(
        modulesPath: String = "Modules",
        logger: Logger
    ) {
        let manifests = PluginDiscovery.discover(modulesPath: modulesPath)
        logger.info("Plugin discovery: found \(manifests.count) plugins")

        for manifest in manifests {
            logger.info("  - \(manifest.name) v\(manifest.version)")
        }
    }
}
