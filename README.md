# NotesBar

NotesBar is a professional macOS utility designed to unify personal knowledge from Obsidian and Apple Notes into a single, high-performance interface. It provides system-wide search, instant previews, and seamless context preservation, enabling you to interact with your notes without disrupting your primary workflow.

---

## Architecture

The diagram below outlines the core components and data flow within the application.

```mermaid
graph TD
    A[Global Search Controller] --> B[Vault Provider]
    B --> C[Obsidian Vaults]
    B --> D[Apple Notes Service]
    A --> E[Spotlight Indexer]
    A --> F[Dual-Pane Search View]
    F --> G[Markdown Preview Engine]
    G --> H[Mermaid/KaTeX Rendering]
    F --> I[Floating Window Manager]
````

---

## User Workflow

NotesBar streamlines the discovery and interaction of your notes through a unified search-first model.

```mermaid
graph LR
    Start([Global Shortcut]) --> Search[System-Wide Search]
    Search --> Preview[Live Metadata Preview]
    Preview --> Action{Navigation}
    Action --> Floating[Floating Note Window]
    Action --> Native[Native App Handover]
    Action --> Spotlight[Spotlight Tab Search]
```

---

## Core Features

* **Unified Search Interface**
  A high-performance search experience that aggregates content from all Obsidian vaults and Apple Notes simultaneously.

* **Global Accessibility**
  Access your entire knowledge base from any application using a dedicated system-wide shortcut (`Ctrl + N`).

* **Apple Notes Integration**
  Native support for viewing and searching Apple Notes with high-fidelity Markdown previews.

* **Spotlight System Integration**
  Deep integration with macOS Spotlight, including support for specialized “Tab to Search” functionality for rapid note retrieval.

* **Markdown and Diagram Rendering**
  High-performance rendering of Markdown content, including complex Mermaid diagrams and KaTeX mathematical notation.

* **Persistent Floating Windows**
  Pin specific notes in independent, floating windows for continuous reference during complex tasks.

* **Context Preservation**
  Operates entirely from the menu bar and floating panels, ensuring your primary workspace remains undisturbed.

---

## Installation

### Requirements

* macOS 13.0 or later
* Obsidian (optional, required only for obsidian vault integration)

### Install from Release

1. **Download the latest version**
   Visit the [Releases page](https://github.com/aman-senpai/NotesBar/releases) and download the latest `.zip` archive.

2. **Extract the archive**
   Double-click the downloaded ZIP file to unpack it.

3. **Move to Applications**
   Drag `NotesBar.app` into your `/Applications` folder.

4. **Launch the app**
   Open NotesBar from Applications.

5. **Grant permissions (first launch)**

   * Allow directory access for Obsidian vault indexing
   * Grant permission for Apple Notes access when prompted

### Gatekeeper Note (First Launch Issue)

If macOS blocks the app with a security warning:

* Open **System Settings → Privacy & Security**
* Scroll down and click **“Open Anyway”** for NotesBar
* Or right-click the app and select **Open**

---

## Development

### Prerequisites

* Xcode 15.0 or later
* Swift 5.10+ toolchain

### Build Process

1. Clone the repository:

   ```bash
   git clone https://github.com/aman-senpai/NotesBar.git
   ```

2. Open the project:

   ```bash
   open NotesBar.xcodeproj
   ```

3. Build and run using `Cmd + R` in Xcode.

---

## Acknowledgments

* Obsidian ecosystem and URI schemes
* Apple Notes framework and automation services
* Mermaid.js for diagram rendering
* KaTeX for mathematical notation support

```
```
