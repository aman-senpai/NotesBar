import Foundation
import Combine

struct GraphData: Codable {
    var nodes: [GraphNode]
    var links: [GraphLink]
}

struct GraphNode: Codable, Identifiable {
    let id: String
    let name: String
    var group: Int // 1 for notes, 2 for folders, etc.
}

struct GraphLink: Codable {
    let source: String
    let target: String
    let value: Int
}

struct GraphSettings: Codable {
    var nodeSize: Double = 4.0
    var linkDistance: Double = 30.0
    var repulsion: Double = -150.0
    var linkThickness: Double = 1.0
    var nodeColor: String = "#007AFF"
    var backgroundDarkness: Double = 0.2
}

class GraphViewModel: ObservableObject {
    @Published var graphData = GraphData(nodes: [], links: [])
    @Published var isScanning = false
    @Published var settings = GraphSettings()
    @Published var showSettings = false
    @Published var centerTrigger = 0
    
    static let presetColors = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#AF52DE", // Purple
        "#FF9500", // Orange
        "#FF3B30", // Red
        "#5AC8FA"  // Cyan
    ]
    
    var vaultPath: String?
    private var cancellables = Set<AnyCancellable>()
    
    func centerView() {
        centerTrigger += 1
    }
    
    func updateVaultPath(_ path: String) {
        self.vaultPath = path
        scanVault()
    }
    
    func scanVault() {
        guard let path = vaultPath else { return }
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let data = self.performScan(at: path)
            
            DispatchQueue.main.async {
                self.graphData = data
                self.isScanning = false
            }
        }
    }
    
    private func performScan(at path: String) -> GraphData {
        let fileManager = FileManager.default
        let baseURL = URL(fileURLWithPath: path)
        var nodes: [GraphNode] = []
        var links: [GraphLink] = []
        var fileMap: [String: String] = [:] // Name (without ext) -> Full Path
        
        // 1. Collect all notes, canvases, and excalidraw files
        let enumerator = fileManager.enumerator(at: baseURL, includingPropertiesForKeys: [.isRegularFileKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Skip hidden files and folders
            if fileURL.lastPathComponent.hasPrefix(".") {
                continue
            }
            
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "md" || ext == "canvas" || ext == "excalidraw" else { continue }
            
            let relativePath = fileURL.path.replacingOccurrences(of: path + "/", with: "")
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            
            let group: Int
            switch ext {
            case "canvas": group = 2
            case "excalidraw": group = 3
            default: group = 1
            }
            
            nodes.append(GraphNode(id: relativePath, name: fileName, group: group))
            fileMap[fileName] = relativePath
        }
        
        // 2. Parse links from each file
        for i in 0..<nodes.count {
            let fileURL = baseURL.appendingPathComponent(nodes[i].id)
            let ext = fileURL.pathExtension.lowercased()
            
            if ext == "canvas" {
                // Parse links inside Canvas JSON
                if let data = try? Data(contentsOf: fileURL),
                   let canvas = try? JSONDecoder().decode(CanvasData.self, from: data) {
                    for canvasNode in canvas.nodes {
                        if canvasNode.type == "file", let fileLink = canvasNode.file {
                            // Obsidian canvas file links can be full paths or just names
                            let targetName = (fileLink as NSString).lastPathComponent.replacingOccurrences(of: ".md", with: "")
                            if let targetPath = fileMap[targetName] {
                                links.append(GraphLink(source: nodes[i].id, target: targetPath, value: 1))
                            }
                        }
                    }
                }
                continue
            }
            
            // Standard Markdown parsing for .md and .excalidraw (since .excalidraw can be MD-based)
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            
            // If it's an MD file but has the excalidraw plugin frontmatter, update group to 3
            if ext == "md" && content.contains("excalidraw-plugin:") {
                nodes[i].group = 3
            }
            
            // Regex for WikiLinks: [[Link]] or [[Link|Alias]]
            let wikiLinkPattern = "\\[\\[([^\\]|]+)(?:\\|[^\\]]+)?\\]\\]"
            let regex = try? NSRegularExpression(pattern: wikiLinkPattern, options: [])
            let matches = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count)) ?? []
            
            for match in matches {
                let linkName = (content as NSString).substring(with: match.range(at: 1))
                
                // Try to resolve the linkName to a path
                let cleanedName = linkName.replacingOccurrences(of: ".md", with: "")
                if let targetPath = fileMap[cleanedName] {
                    links.append(GraphLink(source: nodes[i].id, target: targetPath, value: 1))
                } else {
                    // Check if it's a full path-like link
                    let potentialName = (linkName as NSString).lastPathComponent.replacingOccurrences(of: ".md", with: "")
                    if let targetPath = fileMap[potentialName] {
                        links.append(GraphLink(source: nodes[i].id, target: targetPath, value: 1))
                    }
                }
            }
            
            // Standard Markdown links: [Text](Link.md)
            let mdLinkPattern = "\\[[^\\]]*\\]\\(([^\\)]+\\.md)\\)"
            let mdRegex = try? NSRegularExpression(pattern: mdLinkPattern, options: [])
            let mdMatches = mdRegex?.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count)) ?? []
            
            for match in mdMatches {
                let linkPath = (content as NSString).substring(with: match.range(at: 1))
                let decodedPath = linkPath.removingPercentEncoding ?? linkPath
                let targetName = (decodedPath as NSString).deletingPathExtension
                
                if let targetPath = fileMap[targetName] {
                    links.append(GraphLink(source: nodes[i].id, target: targetPath, value: 1))
                }
            }
        }
        
        return GraphData(nodes: nodes, links: links)
    }
    
    func getGraphDataJSON() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(graphData),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"nodes\":[], \"links\":[]}"
        }
        return json
    }
}
