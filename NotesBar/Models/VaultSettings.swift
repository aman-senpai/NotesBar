import Foundation

struct VaultSettings: Equatable, Identifiable, Codable {
    let id: UUID
    let path: String
    let name: String
    private var _bookmarkData: Data?
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
        case name
        case _bookmarkData
    }
    
    init(path: String, name: String) {
        self.id = UUID()
        self.path = path
        self.name = name
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