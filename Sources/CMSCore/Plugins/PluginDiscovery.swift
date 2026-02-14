import Vapor

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

    /// Validate plugin manifests and detect circular dependencies.
    public static func discoverWithValidation(modulesPath: String = "Modules") throws -> [PluginManifest] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: modulesPath) else {
            return []
        }

        var manifests: [PluginManifest] = []
        for dir in dirs {
            let manifestPath = "\(modulesPath)/\(dir)/plugin.json"
            guard fm.fileExists(atPath: manifestPath),
                  let data = fm.contents(atPath: manifestPath)
            else {
                continue
            }

            do {
                let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
                manifests.append(manifest)
            } catch {
                throw Abort(.internalServerError, reason: "Failed to parse plugin manifest at \(manifestPath): \(error)")
            }
        }

        // Validate and sort by dependencies with cycle detection
        return try sortByDependenciesWithValidation(manifests)
    }

    /// Topological sort of manifests by dependency order.
    static func sortByDependencies(_ manifests: [PluginManifest]) -> [PluginManifest] {
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

    /// Validates manifests and performs topological sort with cycle detection.
    private static func sortByDependenciesWithValidation(_ manifests: [PluginManifest]) throws -> [PluginManifest] {
        // Build dependency graph
        var graph: [String: Set<String>] = [:]
        var manifestMap: [String: PluginManifest] = [:]

        for manifest in manifests {
            manifestMap[manifest.name] = manifest
            graph[manifest.name] = Set(manifest.dependencies ?? [])

            // Validate all dependencies exist
            if let deps = manifest.dependencies {
                for dep in deps {
                    guard manifestMap[dep] != nil || manifests.contains(where: { $0.name == dep }) else {
                        throw Abort(.internalServerError, reason: "Plugin '\(manifest.name)' depends on unknown plugin '\(dep)'")
                    }
                }
            }
        }

        // Topological sort with cycle detection (Kahn's algorithm)
        var sorted: [PluginManifest] = []
        var inDegree: [String: Int] = [:]

        // Calculate in-degrees
        for (node, deps) in graph {
            inDegree[node] = inDegree[node] ?? 0
            for dep in deps {
                inDegree[dep] = (inDegree[dep] ?? 0) + 1
            }
        }

        // Find all nodes with no incoming edges
        var queue = graph.keys.filter { inDegree[$0] == 0 }

        while !queue.isEmpty {
            let node = queue.removeFirst()
            guard let manifest = manifestMap[node] else { continue }

            sorted.append(manifest)

            // Reduce in-degree for all neighbors
            if let neighbors = graph[node] {
                for neighbor in neighbors {
                    inDegree[neighbor] = (inDegree[neighbor] ?? 0) - 1
                    if inDegree[neighbor] == 0 {
                        queue.append(neighbor)
                    }
                }
            }
        }

        // Check for cycles
        guard sorted.count == manifests.count else {
            // Find nodes in cycles
            let remaining = Set(manifestMap.keys).subtracting(sorted.map { $0.name })
            throw Abort(.internalServerError, reason: "Circular dependency detected in plugins: \(remaining.joined(separator: ", "))")
        }

        return sorted
    }
}

// MARK: - Plugin Manager Extension

extension ModuleManager {

    /// Discover and register all plugins from Modules/ directory.
    /// This method will load manifests, check dependencies, and attempt to register
    /// plugins using the registry. Plugins must be pre-registered in the registry.
    public func discoverAndRegisterPlugins(
        modulesPath: String = "Modules",
        logger: Logger
    ) {
        do {
            let manifests = try PluginDiscovery.discoverWithValidation(modulesPath: modulesPath)
            logger.info("Plugin discovery: found \(manifests.count) plugins")

            // Register each plugin
            for manifest in manifests {
                if registerPlugin(byName: manifest.name) {
                    logger.info("  - \(manifest.name) v\(manifest.version) - registered")

                    // Log dependencies if any
                    if let deps = manifest.dependencies, !deps.isEmpty {
                        logger.info("    depends on: \(deps.joined(separator: ", "))")
                    }
                } else {
                    logger.warning("  - \(manifest.name) v\(manifest.version) - NOT registered (no builder found)")
                }
            }
        } catch {
            logger.error("Plugin discovery failed: \(error)")
        }
    }
}
