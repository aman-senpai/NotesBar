import Foundation

/// Model for Obsidian .canvas JSON files
struct CanvasData: Codable {
    let nodes: [CanvasNode]
    let edges: [CanvasEdge]
}

struct CanvasNode: Codable {
    let id: String
    let x: Int
    let y: Int
    let width: Int?
    let height: Int?
    let type: String // "text", "file", "group", "link"
    let file: String?
    let text: String?
    let label: String?
    let url: String?
    let color: String?
}

struct CanvasEdge: Codable {
    let id: String
    let fromNode: String
    let fromSide: String?
    let toNode: String
    let toSide: String?
    let color: String?
    let label: String?
}
