import Foundation
import Combine

class SearchViewModel: ObservableObject { // Must inherit from ObservableObject
    @Published var searchText: String = ""
    @Published var searchResults: [NoteFile] = [] // Must be @Published
    @Published var isSearching: Bool = false // Must be @Published

    private var searchCancellable: AnyCancellable?
    private let noteViewModel: NoteViewModel

    init(noteViewModel: NoteViewModel) {
        self.noteViewModel = noteViewModel
        setupSearchSubscription()
    }

    private func setupSearchSubscription() {
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self,
                      let vaultPath = self.noteViewModel.rootFiles.first?.path else { return }
                self.noteViewModel.searchNotes(query: query, in: vaultPath)
            }
    }

    func clearSearch() {
        searchText = ""
        isSearching = false
    }
}
