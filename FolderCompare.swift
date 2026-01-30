import SwiftUI
import UniformTypeIdentifiers

// MARK: - App Entry Point
@main
struct FolderCompareApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var folder1URL: URL?
    @State private var folder2URL: URL?
    @State private var comparisonResult: ComparisonResult?
    @State private var isComparing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Folder Compare")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Compare two folders to find differences")
                .foregroundColor(.secondary)

            Divider()

            // Folder 1 Selection
            FolderSelectionView(
                label: "Source Folder (Internal Drive)",
                selectedURL: $folder1URL
            )

            // Folder 2 Selection
            FolderSelectionView(
                label: "Destination Folder (External Drive)",
                selectedURL: $folder2URL
            )

            Divider()

            // Compare Button
            Button(action: comparefolders) {
                HStack {
                    if isComparing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 5)
                    }
                    Text(isComparing ? "Comparing..." : "Compare Folders")
                }
                .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .disabled(folder1URL == nil || folder2URL == nil || isComparing)

            // Error Message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // Results
            if let result = comparisonResult {
                ResultsView(result: result)
            }

            Spacer()
        }
        .padding(30)
        .frame(minWidth: 600, minHeight: 500)
    }

    private func comparefolders() {
        guard let url1 = folder1URL, let url2 = folder2URL else { return }

        isComparing = true
        errorMessage = nil
        comparisonResult = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try FolderComparer.compare(source: url1, destination: url2)
                DispatchQueue.main.async {
                    self.comparisonResult = result
                    self.isComparing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.isComparing = false
                }
            }
        }
    }
}

// MARK: - Folder Selection View
struct FolderSelectionView: View {
    let label: String
    @Binding var selectedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .fontWeight(.medium)

            HStack {
                Text(selectedURL?.path ?? "No folder selected")
                    .foregroundColor(selectedURL == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Select...") {
                    selectFolder()
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.message = "Select a folder to compare"

        if panel.runModal() == .OK {
            selectedURL = panel.url
        }
    }
}

// MARK: - Results View
struct ResultsView: View {
    let result: ComparisonResult
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Summary
            HStack(spacing: 30) {
                SummaryItem(
                    title: "Identical",
                    count: result.identicalFiles.count,
                    color: .green
                )
                SummaryItem(
                    title: "Only in Source",
                    count: result.onlyInSource.count,
                    color: .orange
                )
                SummaryItem(
                    title: "Only in Destination",
                    count: result.onlyInDestination.count,
                    color: .blue
                )
                SummaryItem(
                    title: "Different",
                    count: result.differentFiles.count,
                    color: .red
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Status Message
            if result.foldersAreIdentical {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Folders are identical! Safe to delete from source.")
                        .fontWeight(.medium)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Folders have differences. Review before deleting.")
                        .fontWeight(.medium)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Detailed file lists
            if !result.foldersAreIdentical {
                TabView(selection: $selectedTab) {
                    FileListView(
                        title: "Files only in Source (need to copy)",
                        files: result.onlyInSource,
                        emptyMessage: "No files unique to source"
                    )
                    .tabItem { Text("Only in Source (\(result.onlyInSource.count))") }
                    .tag(0)

                    FileListView(
                        title: "Files only in Destination",
                        files: result.onlyInDestination,
                        emptyMessage: "No files unique to destination"
                    )
                    .tabItem { Text("Only in Destination (\(result.onlyInDestination.count))") }
                    .tag(1)

                    FileListView(
                        title: "Files that differ (same name, different content)",
                        files: result.differentFiles,
                        emptyMessage: "No differing files"
                    )
                    .tabItem { Text("Different (\(result.differentFiles.count))") }
                    .tag(2)
                }
                .frame(minHeight: 200)
            }
        }
    }
}

struct SummaryItem: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct FileListView: View {
    let title: String
    let files: [String]
    let emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .fontWeight(.medium)

            if files.isEmpty {
                Text(emptyMessage)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(files, id: \.self) { file in
                            Text(file)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
            }
        }
        .padding()
    }
}

// MARK: - Comparison Logic
struct ComparisonResult {
    let identicalFiles: [String]
    let onlyInSource: [String]
    let onlyInDestination: [String]
    let differentFiles: [String]

    var foldersAreIdentical: Bool {
        onlyInSource.isEmpty && onlyInDestination.isEmpty && differentFiles.isEmpty
    }
}

struct FolderComparer {
    static func compare(source: URL, destination: URL) throws -> ComparisonResult {
        let fileManager = FileManager.default

        // Get all files recursively from both folders
        let sourceFiles = try getAllFiles(in: source, relativeTo: source, fileManager: fileManager)
        let destFiles = try getAllFiles(in: destination, relativeTo: destination, fileManager: fileManager)

        let sourceSet = Set(sourceFiles.keys)
        let destSet = Set(destFiles.keys)

        // Find differences
        let onlyInSource = sourceSet.subtracting(destSet).sorted()
        let onlyInDestination = destSet.subtracting(sourceSet).sorted()
        let common = sourceSet.intersection(destSet)

        // Compare common files by size and modification date
        var identicalFiles: [String] = []
        var differentFiles: [String] = []

        for relativePath in common {
            guard let sourceInfo = sourceFiles[relativePath],
                  let destInfo = destFiles[relativePath] else { continue }

            if sourceInfo.size == destInfo.size {
                identicalFiles.append(relativePath)
            } else {
                differentFiles.append(relativePath)
            }
        }

        return ComparisonResult(
            identicalFiles: identicalFiles.sorted(),
            onlyInSource: Array(onlyInSource),
            onlyInDestination: Array(onlyInDestination),
            differentFiles: differentFiles.sorted()
        )
    }

    private static func getAllFiles(
        in directory: URL,
        relativeTo baseURL: URL,
        fileManager: FileManager
    ) throws -> [String: FileInfo] {
        var files: [String: FileInfo] = [:]

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw NSError(domain: "FolderCompare", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not enumerate directory: \(directory.path)"
            ])
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: baseURL.path + "/", with: "")
            let size = resourceValues.fileSize ?? 0

            files[relativePath] = FileInfo(size: size)
        }

        return files
    }
}

struct FileInfo {
    let size: Int
}
