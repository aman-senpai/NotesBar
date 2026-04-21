import Foundation
import AppKit

class AppleNotesManager {
    static let shared = AppleNotesManager()
    
    private var cachedNotes: [NoteFile]? = nil
    private var isFetching = false
    private var pendingCompletions: [([NoteFile]) -> Void] = []
    
    func preloadCache() {
        guard cachedNotes == nil, !isFetching else { return }
        fetchNotes { _ in }
    }
    
    func fetchNotes(completion: @escaping ([NoteFile]) -> Void) {
        // Immediately return cached notes if available for instant UI
        if let cached = cachedNotes, !cached.isEmpty {
            DispatchQueue.main.async {
                completion(cached)
            }
        }
        
        pendingCompletions.append(completion)
        
        // Prevent concurrent fetches
        guard !isFetching else { return }
        isFetching = true
        
        // Ensure Notes is running
        if NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Notes").isEmpty {
            NSWorkspace.shared.launchApplication("Notes")
            // Give it a moment to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.performFetch { notes in
                    self.finishFetching(with: notes)
                }
            }
        } else {
            performFetch { notes in
                self.finishFetching(with: notes)
            }
        }
    }
    
    private func finishFetching(with notes: [NoteFile]) {
        self.cachedNotes = notes
        self.isFetching = false
        let completions = self.pendingCompletions
        self.pendingCompletions.removeAll()
        for completion in completions {
            completion(notes)
        }
    }
    
    private func runAppleScriptWithRetry(_ scriptSource: String, maxRetries: Int = 3, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var attempt = 0
            var finalOutput: String? = nil
            
            while attempt < maxRetries {
                attempt += 1
                guard let script = NSAppleScript(source: scriptSource) else {
                    print("Failed to compile AppleScript")
                    break
                }
                
                var errorInfo: NSDictionary?
                let descriptor = script.executeAndReturnError(&errorInfo)
                
                if let errorInfo = errorInfo {
                    let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
                    let errorMessage = errorInfo[NSAppleScript.errorMessage] as? String ?? ""
                    print("AppleScript attempt \(attempt) failed: \(errorMessage) (\(errorNumber))")
                    
                    if attempt < maxRetries {
                        if errorNumber == -600 || errorNumber == -10004 {
                            DispatchQueue.main.async {
                                NSWorkspace.shared.launchApplication("Notes")
                            }
                        }
                        Thread.sleep(forTimeInterval: 1.5)
                    }
                } else {
                    finalOutput = descriptor.stringValue
                    break
                }
            }
            
            DispatchQueue.main.async {
                completion(finalOutput)
            }
        }
    }

    private func performFetch(completion: @escaping ([NoteFile]) -> Void) {
        let scriptSource = """
        tell application "Notes"
            set epoch to current date
            set year of epoch to 1970
            set month of epoch to 1
            set day of epoch to 1
            set time of epoch to 0
            set out to ""
            repeat with acc in accounts
                repeat with aFolder in folders of acc
                    set fName to name of aFolder
                    if fName is not "Recently Deleted" then
                        repeat with aNote in notes of aFolder
                            set uTime to (modification date of aNote) - epoch
                            set out to out & (id of aNote) & "|||" & (name of aNote) & "|||" & fName & "|||" & uTime & "\\n"
                        end repeat
                    end if
                end repeat
            end repeat
            return out
        end tell
        """
        
        runAppleScriptWithRetry(scriptSource) { output in
            guard let output = output else {
                completion([])
                return
            }
            
            var folderDict: [String: [NoteFile]] = [:]
            var seenIds = Set<String>()
            
            let lines = output.components(separatedBy: .newlines)
            for line in lines where !line.isEmpty {
                let parts = line.components(separatedBy: "|||")
                if parts.count >= 4 {
                    let id = parts[0]
                    
                    if seenIds.contains(id) { continue }
                    seenIds.insert(id)
                    
                    let name = parts[1]
                    let folderName = parts[2]
                    let timeInterval = TimeInterval(parts[3]) ?? 0
                    let modificationDate = Date(timeIntervalSince1970: timeInterval)
                    
                    let noteFile = NoteFile(
                        id: id,
                        name: name,
                        path: id, // Using ID as path for Apple Notes
                        relativePath: "\(folderName)/\(name)",
                        isDirectory: false,
                        source: .appleNotes,
                        modificationDate: modificationDate
                    )
                    
                    folderDict[folderName, default: []].append(noteFile)
                }
            }
            
            var resultNotes: [NoteFile] = []
            for (folderName, childNotes) in folderDict {
                // Initial sorting will be handled by the UI based on SortOption, 
                // but we can default sort here just in case.
                let sortedChildren = childNotes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                
                let folderNode = NoteFile(
                    id: "folder-\(folderName)",
                    name: folderName,
                    path: "folder-\(folderName)", // Dummy path for folder
                    relativePath: folderName,
                    isDirectory: true,
                    children: sortedChildren,
                    source: .appleNotes,
                    modificationDate: nil // Folders themselves don't strictly need a mod date for sorting if we only sort files
                )
                resultNotes.append(folderNode)
            }
            
            let sortedResult = resultNotes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            completion(sortedResult)
        }
    }
    
    func fetchNoteBody(id: String, completion: @escaping (String) -> Void) {
        let scriptSource = "tell application \"Notes\" to get body of note id \"\(id)\""
        runAppleScriptWithRetry(scriptSource) { output in
            completion(output ?? "Error loading note.")
        }
    }
    
    func openNoteInNotesApp(id: String) {
        let scriptSource = "tell application \"Notes\" to show note id \"\(id)\""
        guard let script = NSAppleScript(source: scriptSource) else { return }
        script.executeAndReturnError(nil)
        NSWorkspace.shared.launchApplication("Notes")
    }
    
    func createNewNote() {
        let scriptSource = """
        tell application "Notes"
            activate
            set newNote to make new note
            show newNote
        end tell
        """
        guard let script = NSAppleScript(source: scriptSource) else { return }
        script.executeAndReturnError(nil)
    }
}
