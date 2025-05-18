import Foundation

struct VaultSettings: Equatable {
    let path: String
    let name: String
    private var _bookmarkData: Data?
    
    init(path: String, name: String) {
        self.path = path
        self.name = name
    }
    
    var bookmarkData: Data? {
        get {
            _bookmarkData ?? UserDefaults.standard.data(forKey: "vaultBookmark")
        }
        set {
            _bookmarkData = newValue
            if let data = newValue {
                UserDefaults.standard.set(data, forKey: "vaultBookmark")
            } else {
                UserDefaults.standard.removeObject(forKey: "vaultBookmark")
            }
        }
    }
    
    static func loadFromDefaults() -> VaultSettings? {
        guard let vaultPath = UserDefaults.standard.string(forKey: "vaultPath"),
              let vaultName = UserDefaults.standard.string(forKey: "vaultName") else {
            return nil
        }
        return VaultSettings(path: vaultPath, name: vaultName)
    }
    
    func saveToDefaults() {
        UserDefaults.standard.set(path, forKey: "vaultPath")
        UserDefaults.standard.set(name, forKey: "vaultName")
    }
    
    static func == (lhs: VaultSettings, rhs: VaultSettings) -> Bool {
        return lhs.path == rhs.path && lhs.name == rhs.name
    }
} 