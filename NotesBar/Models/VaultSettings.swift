import Foundation

struct VaultSettings: Equatable, Identifiable, Codable {
    enum VaultType: String, Codable {
        case obsidian
        case appleNotes
    }
    
    let id: UUID
    let path: String
    let name: String
    var type: VaultType = .obsidian
    private var _bookmarkData: Data?
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
        case name
        case type
        case _bookmarkData
    }
    
    init(path: String, name: String, type: VaultType = .obsidian) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.type = type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.path = try container.decode(String.self, forKey: .path)
        self.name = try container.decode(String.self, forKey: .name)
        self._bookmarkData = try container.decodeIfPresent(Data.self, forKey: ._bookmarkData)
        self.type = try container.decodeIfPresent(VaultType.self, forKey: .type) ?? .obsidian
    }
    
    var bookmarkData: Data? {
        get {
            _bookmarkData ?? UserDefaults.standard.data(forKey: "vaultBookmark_\(id.uuidString)")
        }
        set {
            _bookmarkData = newValue
            if let data = newValue {
                UserDefaults.standard.set(data, forKey: "vaultBookmark_\(id.uuidString)")
            } else {
                UserDefaults.standard.removeObject(forKey: "vaultBookmark_\(id.uuidString)")
            }
        }
    }
    
    static func loadFromDefaults() -> [VaultSettings] {
        guard let vaultsData = UserDefaults.standard.data(forKey: "savedVaults") else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([VaultSettings].self, from: vaultsData)
        } catch {
            print("Error loading vaults: \(error)")
            return []
        }
    }
    
    func saveToDefaults() {
        var vaults = VaultSettings.loadFromDefaults()
        if let index = vaults.firstIndex(where: { $0.id == self.id }) {
            vaults[index] = self
        } else {
            vaults.append(self)
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(vaults)
            UserDefaults.standard.set(data, forKey: "savedVaults")
        } catch {
            print("Error saving vaults: \(error)")
        }
    }
    
    static func == (lhs: VaultSettings, rhs: VaultSettings) -> Bool {
        return lhs.id == rhs.id
    }
} 