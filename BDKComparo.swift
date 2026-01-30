import SwiftUI
import UniformTypeIdentifiers

// MARK: - App Entry Point
@main
struct BDKComparoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}

// MARK: - Color Theme
struct AppColors {
    static let background = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.18)
    static let cardBackgroundHover = Color(red: 0.16, green: 0.16, blue: 0.22)
    static let accent = Color(red: 0.4, green: 0.6, blue: 1.0)
    static let accentGradientStart = Color(red: 0.3, green: 0.5, blue: 1.0)
    static let accentGradientEnd = Color(red: 0.6, green: 0.4, blue: 1.0)
    static let success = Color(red: 0.2, green: 0.8, blue: 0.5)
    static let warning = Color(red: 1.0, green: 0.7, blue: 0.2)
    static let error = Color(red: 1.0, green: 0.4, blue: 0.4)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
    static let divider = Color(white: 0.2)
    static let leftAccent = Color(red: 0.3, green: 0.8, blue: 0.9)
    static let rightAccent = Color(red: 0.9, green: 0.5, blue: 0.7)
    static let centerAccent = Color(red: 0.6, green: 0.4, blue: 1.0)
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var folder1URL: URL?
    @State private var folder2URL: URL?
    @State private var comparisonResult: ComparisonResult?
    @State private var isComparing = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var selectedFile: ComparedFile?
    @State private var showDetails = false
    @State private var showSyncConfirmation = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HeaderView(
                    canCompare: folder1URL != nil && folder2URL != nil,
                    isComparing: isComparing,
                    hasResults: comparisonResult != nil,
                    canSync: (comparisonResult?.onlyInSourceCount ?? 0) > 0,
                    isSyncing: isSyncing,
                    onCompare: compareFolders,
                    onRefresh: compareFolders,
                    onSync: { showSyncConfirmation = true }
                )

                if let error = errorMessage {
                    ErrorBanner(message: error) {
                        errorMessage = nil
                    }
                }

                if let success = successMessage {
                    SuccessBanner(message: success) {
                        successMessage = nil
                    }
                }

                // Folder selection row
                FolderSelectionRow(
                    folder1URL: $folder1URL,
                    folder2URL: $folder2URL
                )

                // Summary bar (shows after comparison)
                if let result = comparisonResult {
                    SummaryBarView(
                        result: result,
                        showDetails: $showDetails,
                        selectedFile: selectedFile
                    )
                }

                // Main comparison table
                if isComparing {
                    ComparingAnimationView()
                        .frame(maxHeight: .infinity)
                } else if let result = comparisonResult {
                    ComparisonTableView(
                        files: result.allFiles,
                        selectedFile: $selectedFile
                    )
                } else {
                    WelcomeView()
                        .frame(maxHeight: .infinity)
                }

                // Detail Panel (hidden until Details button clicked)
                if showDetails, let file = selectedFile {
                    DetailPanelView(
                        file: file,
                        folder1URL: folder1URL,
                        folder2URL: folder2URL,
                        onClose: { showDetails = false }
                    )
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .sheet(isPresented: $showSyncConfirmation) {
            SyncConfirmationView(
                fileCount: comparisonResult?.onlyInSourceCount ?? 0,
                onConfirm: {
                    showSyncConfirmation = false
                    syncFiles()
                },
                onCancel: {
                    showSyncConfirmation = false
                }
            )
        }
    }

    private func syncFiles() {
        guard let sourceURL = folder1URL,
              let destURL = folder2URL,
              let result = comparisonResult else { return }

        let filesToSync = result.allFiles.filter { $0.status == .onlyInSource }
        guard !filesToSync.isEmpty else { return }

        isSyncing = true
        errorMessage = nil
        successMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            var copiedCount = 0
            var failedCount = 0

            for file in filesToSync {
                let sourcePath = sourceURL.appendingPathComponent(file.relativePath)
                let destPath = destURL.appendingPathComponent(file.relativePath)

                // Create destination directory if needed
                let destDir = destPath.deletingLastPathComponent()
                do {
                    if !fileManager.fileExists(atPath: destDir.path) {
                        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
                    }

                    // Copy the file
                    try fileManager.copyItem(at: sourcePath, to: destPath)
                    copiedCount += 1
                } catch {
                    failedCount += 1
                    print("Failed to copy \(file.relativePath): \(error)")
                }
            }

            DispatchQueue.main.async {
                self.isSyncing = false

                if failedCount == 0 {
                    self.successMessage = "Successfully copied \(copiedCount) file\(copiedCount == 1 ? "" : "s") to destination"
                } else if copiedCount > 0 {
                    self.successMessage = "Copied \(copiedCount) file\(copiedCount == 1 ? "" : "s"), \(failedCount) failed"
                } else {
                    self.errorMessage = "Failed to copy files. Check permissions."
                }

                // Auto-refresh after sync
                self.compareFolders()
            }
        }
    }

    private func compareFolders() {
        guard let url1 = folder1URL, let url2 = folder2URL else { return }

        isComparing = true
        errorMessage = nil
        comparisonResult = nil
        selectedFile = nil
        showDetails = false

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try FolderComparer.compare(source: url1, destination: url2)
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.comparisonResult = result
                    }
                    self.isComparing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isComparing = false
                }
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    let canCompare: Bool
    let isComparing: Bool
    let hasResults: Bool
    let canSync: Bool
    let isSyncing: Bool
    let onCompare: () -> Void
    let onRefresh: () -> Void
    let onSync: () -> Void

    var body: some View {
        HStack {
            // Logo and title
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accentGradientStart, AppColors.accentGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("BDK Comparo")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Folder Comparison Tool")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                // Refresh button (only shown after comparison)
                if hasResults {
                    Button(action: onRefresh) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Refresh")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColors.cardBackgroundHover)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.divider, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isComparing || isSyncing)

                    // Sync button (only shown when there are source-only files)
                    if canSync {
                        Button(action: onSync) {
                            HStack(spacing: 6) {
                                if isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.right.doc.on.clipboard")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text(isSyncing ? "Syncing..." : "Sync to Dest")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: !isSyncing
                                        ? [AppColors.leftAccent.opacity(0.8), AppColors.leftAccent]
                                        : [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isComparing || isSyncing)
                    }
                }

                // Compare button
                Button(action: onCompare) {
                    HStack(spacing: 8) {
                        if isComparing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isComparing ? "Comparing..." : "Compare")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: canCompare && !isComparing
                                ? [AppColors.accentGradientStart, AppColors.accentGradientEnd]
                                : [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(!canCompare || isComparing || isSyncing)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppColors.cardBackground)
    }
}

// MARK: - Folder Selection Row
struct FolderSelectionRow: View {
    @Binding var folder1URL: URL?
    @Binding var folder2URL: URL?

    var body: some View {
        HStack(spacing: 0) {
            // Source folder
            FolderSelectorCompact(
                title: "SOURCE",
                subtitle: "Internal Drive",
                folderURL: $folder1URL,
                accentColor: AppColors.leftAccent
            )

            // Divider
            Rectangle()
                .fill(AppColors.divider)
                .frame(width: 1)

            // Center spacer with icon
            ZStack {
                AppColors.cardBackground
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.centerAccent)
            }
            .frame(width: 120)

            // Divider
            Rectangle()
                .fill(AppColors.divider)
                .frame(width: 1)

            // Destination folder
            FolderSelectorCompact(
                title: "DESTINATION",
                subtitle: "External Drive",
                folderURL: $folder2URL,
                accentColor: AppColors.rightAccent
            )
        }
        .frame(height: 70)
        .background(AppColors.cardBackground)
    }
}

// MARK: - Folder Selector Compact
struct FolderSelectorCompact: View {
    let title: String
    let subtitle: String
    @Binding var folderURL: URL?
    let accentColor: Color
    @State private var isHovering = false

    var body: some View {
        Button(action: selectFolder) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "folder.fill")
                        .foregroundColor(accentColor)
                        .font(.system(size: 16))
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                        Text(title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accentColor)
                    }

                    if let url = folderURL {
                        Text(url.lastPathComponent)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Click to select folder...")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isHovering ? AppColors.cardBackgroundHover : AppColors.cardBackground)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
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
            folderURL = panel.url
        }
    }
}

// MARK: - Summary Bar View
struct SummaryBarView: View {
    let result: ComparisonResult
    @Binding var showDetails: Bool
    let selectedFile: ComparedFile?

    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            if result.foldersAreIdentical {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.success)
                    Text("Folders Match!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.success)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.warning)
                    Text("Differences Found")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.warning)
                }
            }

            Divider()
                .frame(height: 24)
                .background(AppColors.divider)

            // Stats
            HStack(spacing: 16) {
                StatPill(count: result.identicalCount, label: "Identical", color: AppColors.success)
                StatPill(count: result.onlyInSourceCount, label: "Source Only", color: AppColors.leftAccent)
                StatPill(count: result.onlyInDestCount, label: "Dest Only", color: AppColors.rightAccent)
                StatPill(count: result.differentCount, label: "Different", color: AppColors.error)
            }

            Spacer()

            // Details button
            Button(action: { showDetails.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: showDetails ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 14))
                    Text("Details")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(selectedFile != nil ? AppColors.centerAccent : AppColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    showDetails
                        ? AppColors.centerAccent.opacity(0.2)
                        : AppColors.cardBackgroundHover
                )
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(showDetails ? AppColors.centerAccent.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedFile == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppColors.cardBackground)
        .overlay(
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Stat Pill
struct StatPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.error)
            Text(message)
                .foregroundColor(AppColors.textPrimary)
                .font(.system(size: 13))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(AppColors.error.opacity(0.2))
    }
}

// MARK: - Success Banner
struct SuccessBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
            Text(message)
                .foregroundColor(AppColors.textPrimary)
                .font(.system(size: 13))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(AppColors.success.opacity(0.2))
    }
}

// MARK: - Sync Confirmation View
struct SyncConfirmationView: View {
    let fileCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.leftAccent.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: "arrow.right.doc.on.clipboard")
                    .font(.system(size: 36))
                    .foregroundColor(AppColors.leftAccent)
            }

            // Title and description
            VStack(spacing: 8) {
                Text("Sync Files to Destination")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text("This will copy \(fileCount) file\(fileCount == 1 ? "" : "s") from the source folder to the destination folder.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Info box
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppColors.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Non-destructive sync")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Only files missing from the destination will be copied. Existing files will not be modified or deleted.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(16)
            .background(AppColors.accent.opacity(0.1))
            .cornerRadius(10)

            // Buttons
            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.cardBackgroundHover)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.divider, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.doc.on.clipboard")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Sync \(fileCount) File\(fileCount == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [AppColors.leftAccent.opacity(0.8), AppColors.leftAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(width: 450)
        .background(AppColors.cardBackground)
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accentGradientStart, AppColors.accentGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Ready to Compare")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text("Select folders above, then click Compare")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

// MARK: - Comparing Animation View
struct ComparingAnimationView: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(AppColors.accent.opacity(0.2), lineWidth: 4)
                    .frame(width: 70, height: 70)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accentGradientStart, AppColors.accentGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(rotation))
            }
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            Text("Comparing files...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

// MARK: - Comparison Table View (Single synchronized scroll)
struct ComparisonTableView: View {
    let files: [ComparedFile]
    @Binding var selectedFile: ComparedFile?

    var body: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                // Source header
                ColumnHeader(title: "SOURCE FILE", accentColor: AppColors.leftAccent)

                // Status header
                ZStack {
                    AppColors.cardBackground
                    Text("STATUS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.centerAccent)
                }
                .frame(width: 120)

                // Destination header
                ColumnHeader(title: "DESTINATION FILE", accentColor: AppColors.rightAccent)
            }
            .frame(height: 36)
            .overlay(
                Rectangle()
                    .fill(AppColors.divider)
                    .frame(height: 1),
                alignment: .bottom
            )

            // Scrollable comparison rows (single scroll view)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(files) { file in
                        ComparisonRowView(
                            file: file,
                            isSelected: selectedFile?.id == file.id
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedFile = file
                            }
                        }

                        Divider()
                            .background(AppColors.divider.opacity(0.5))
                    }
                }
            }
            .background(AppColors.background)
        }
    }
}

// MARK: - Column Header
struct ColumnHeader: View {
    let title: String
    let accentColor: Color

    var body: some View {
        HStack {
            Circle()
                .fill(accentColor)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accentColor)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
    }
}

// MARK: - Comparison Row View (aligned across all three columns)
struct ComparisonRowView: View {
    let file: ComparedFile
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // Source file cell
            FileCellView(
                fileName: file.relativePath.components(separatedBy: "/").last ?? file.relativePath,
                fullPath: file.relativePath,
                size: file.sourceSize,
                exists: file.existsInSource,
                accentColor: AppColors.leftAccent
            )
            .frame(maxWidth: .infinity)

            // Status cell (center)
            StatusCellView(status: file.status)
                .frame(width: 120)

            // Destination file cell
            FileCellView(
                fileName: file.relativePath.components(separatedBy: "/").last ?? file.relativePath,
                fullPath: file.relativePath,
                size: file.destinationSize,
                exists: file.existsInDestination,
                accentColor: AppColors.rightAccent
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .background(
            isSelected
                ? AppColors.centerAccent.opacity(0.15)
                : (isHovering ? AppColors.cardBackgroundHover : AppColors.background)
        )
        .overlay(
            Rectangle()
                .fill(isSelected ? AppColors.centerAccent : Color.clear)
                .frame(width: 3),
            alignment: .leading
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - File Cell View
struct FileCellView: View {
    let fileName: String
    let fullPath: String
    let size: Int?
    let exists: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 10) {
            // File icon
            Image(systemName: fileIcon)
                .foregroundColor(exists ? accentColor : AppColors.textSecondary.opacity(0.2))
                .font(.system(size: 14))
                .frame(width: 20)

            if exists {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if fullPath.contains("/") {
                        Text(String(fullPath.dropLast(fileName.count + 1)))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }

                Spacer()

                if let size = size {
                    Text(formatFileSize(size))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                Text("—")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary.opacity(0.3))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }

    var fileIcon: String {
        guard exists else { return "doc" }
        let ext = (fullPath as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic":
            return "photo"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "mp3", "wav", "aac", "m4a":
            return "music.note"
        case "pdf":
            return "doc.fill"
        case "zip", "tar", "gz", "rar":
            return "doc.zipper"
        case "txt", "md":
            return "doc.text"
        case "swift", "js", "py", "java", "cpp", "h":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc"
        }
    }

    func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 { return String(format: "%.1f GB", gb) }
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        if kb >= 1 { return String(format: "%.1f KB", kb) }
        return "\(bytes) B"
    }
}

// MARK: - Status Cell View
struct StatusCellView: View {
    let status: FileStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(statusColor)

            Text(statusLabel)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(4)
    }

    var statusIcon: String {
        switch status {
        case .identical: return "checkmark.circle.fill"
        case .onlyInSource: return "arrow.right.circle.fill"
        case .onlyInDestination: return "arrow.left.circle.fill"
        case .different: return "exclamationmark.circle.fill"
        }
    }

    var statusColor: Color {
        switch status {
        case .identical: return AppColors.success
        case .onlyInSource: return AppColors.leftAccent
        case .onlyInDestination: return AppColors.rightAccent
        case .different: return AppColors.error
        }
    }

    var statusLabel: String {
        switch status {
        case .identical: return "MATCH"
        case .onlyInSource: return "SOURCE ONLY"
        case .onlyInDestination: return "DEST ONLY"
        case .different: return "DIFFERENT"
        }
    }
}

// MARK: - Detail Panel View
struct DetailPanelView: View {
    let file: ComparedFile
    let folder1URL: URL?
    let folder2URL: URL?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppColors.centerAccent)
                Text("File Details")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(file.relativePath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppColors.cardBackgroundHover)

            // Detail content
            HStack(spacing: 20) {
                // Source details
                if file.existsInSource {
                    FileDetailCard(
                        title: "Source",
                        fullPath: folder1URL?.appendingPathComponent(file.relativePath).path ?? file.relativePath,
                        size: file.sourceSize,
                        modDate: file.sourceModDate,
                        accentColor: AppColors.leftAccent
                    )
                } else {
                    MissingFileCard(title: "Source", accentColor: AppColors.leftAccent)
                }

                // Comparison indicator
                VStack(spacing: 8) {
                    Image(systemName: comparisonIcon)
                        .font(.system(size: 32))
                        .foregroundColor(comparisonColor)
                    Text(comparisonText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(comparisonColor)

                    if file.status == .different, let srcSize = file.sourceSize, let dstSize = file.destinationSize {
                        let diff = srcSize - dstSize
                        Text(diff > 0 ? "Source is \(formatFileSize(abs(diff))) larger" : "Dest is \(formatFileSize(abs(diff))) larger")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .frame(width: 140)

                // Destination details
                if file.existsInDestination {
                    FileDetailCard(
                        title: "Destination",
                        fullPath: folder2URL?.appendingPathComponent(file.relativePath).path ?? file.relativePath,
                        size: file.destinationSize,
                        modDate: file.destModDate,
                        accentColor: AppColors.rightAccent
                    )
                } else {
                    MissingFileCard(title: "Destination", accentColor: AppColors.rightAccent)
                }
            }
            .padding(20)
            .background(AppColors.cardBackground)
        }
    }

    var comparisonIcon: String {
        switch file.status {
        case .identical: return "equal.circle.fill"
        case .onlyInSource: return "arrow.right.circle.fill"
        case .onlyInDestination: return "arrow.left.circle.fill"
        case .different: return "xmark.circle.fill"
        }
    }

    var comparisonColor: Color {
        switch file.status {
        case .identical: return AppColors.success
        case .onlyInSource: return AppColors.leftAccent
        case .onlyInDestination: return AppColors.rightAccent
        case .different: return AppColors.error
        }
    }

    var comparisonText: String {
        switch file.status {
        case .identical: return "IDENTICAL"
        case .onlyInSource: return "MISSING IN DEST"
        case .onlyInDestination: return "EXTRA IN DEST"
        case .different: return "SIZE DIFFERS"
        }
    }

    func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 { return String(format: "%.2f GB", gb) }
        if mb >= 1 { return String(format: "%.2f MB", mb) }
        if kb >= 1 { return String(format: "%.1f KB", kb) }
        return "\(bytes) bytes"
    }
}

// MARK: - File Detail Card
struct FileDetailCard: View {
    let title: String
    let fullPath: String
    let size: Int?
    let modDate: Date?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accentColor)
            }

            // Full path
            VStack(alignment: .leading, spacing: 4) {
                Text("Path")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Text(fullPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            HStack(spacing: 20) {
                // Size
                if let size = size {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Size")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        Text(formatFileSize(size))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                // Modified date
                if let date = modDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Modified")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        Text(formatDate(date))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 { return String(format: "%.2f GB", gb) }
        if mb >= 1 { return String(format: "%.2f MB", mb) }
        if kb >= 1 { return String(format: "%.1f KB", kb) }
        return "\(bytes) bytes"
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Missing File Card
struct MissingFileCard: View {
    let title: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accentColor.opacity(0.5))
            }

            Spacer()

            Image(systemName: "doc.badge.ellipsis")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textSecondary.opacity(0.2))

            Text("File not present")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackgroundHover.opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.divider, lineWidth: 1)
        )
    }
}

// MARK: - Data Models
enum FileStatus {
    case identical
    case onlyInSource
    case onlyInDestination
    case different
}

struct ComparedFile: Identifiable {
    let id = UUID()
    let relativePath: String
    let status: FileStatus
    let sourceSize: Int?
    let destinationSize: Int?
    let sourceModDate: Date?
    let destModDate: Date?

    var existsInSource: Bool {
        status == .identical || status == .onlyInSource || status == .different
    }

    var existsInDestination: Bool {
        status == .identical || status == .onlyInDestination || status == .different
    }
}

struct ComparisonResult {
    let allFiles: [ComparedFile]

    var identicalCount: Int { allFiles.filter { $0.status == .identical }.count }
    var onlyInSourceCount: Int { allFiles.filter { $0.status == .onlyInSource }.count }
    var onlyInDestCount: Int { allFiles.filter { $0.status == .onlyInDestination }.count }
    var differentCount: Int { allFiles.filter { $0.status == .different }.count }

    var foldersAreIdentical: Bool {
        onlyInSourceCount == 0 && onlyInDestCount == 0 && differentCount == 0
    }
}

// MARK: - Folder Comparer
struct FolderComparer {
    static func compare(source: URL, destination: URL) throws -> ComparisonResult {
        let fileManager = FileManager.default

        let sourceFiles = try getAllFiles(in: source, relativeTo: source, fileManager: fileManager)
        let destFiles = try getAllFiles(in: destination, relativeTo: destination, fileManager: fileManager)

        let sourceSet = Set(sourceFiles.keys)
        let destSet = Set(destFiles.keys)

        var allFiles: [ComparedFile] = []

        // Files only in source
        for path in sourceSet.subtracting(destSet) {
            let info = sourceFiles[path]!
            allFiles.append(ComparedFile(
                relativePath: path,
                status: .onlyInSource,
                sourceSize: info.size,
                destinationSize: nil,
                sourceModDate: info.modDate,
                destModDate: nil
            ))
        }

        // Files only in destination
        for path in destSet.subtracting(sourceSet) {
            let info = destFiles[path]!
            allFiles.append(ComparedFile(
                relativePath: path,
                status: .onlyInDestination,
                sourceSize: nil,
                destinationSize: info.size,
                sourceModDate: nil,
                destModDate: info.modDate
            ))
        }

        // Common files
        for path in sourceSet.intersection(destSet) {
            let sourceInfo = sourceFiles[path]!
            let destInfo = destFiles[path]!

            let status: FileStatus = sourceInfo.size == destInfo.size ? .identical : .different

            allFiles.append(ComparedFile(
                relativePath: path,
                status: status,
                sourceSize: sourceInfo.size,
                destinationSize: destInfo.size,
                sourceModDate: sourceInfo.modDate,
                destModDate: destInfo.modDate
            ))
        }

        // Sort by status priority, then by path
        allFiles.sort { a, b in
            let priorityA = statusPriority(a.status)
            let priorityB = statusPriority(b.status)
            if priorityA != priorityB {
                return priorityA < priorityB
            }
            return a.relativePath < b.relativePath
        }

        return ComparisonResult(allFiles: allFiles)
    }

    private static func statusPriority(_ status: FileStatus) -> Int {
        switch status {
        case .different: return 0
        case .onlyInSource: return 1
        case .onlyInDestination: return 2
        case .identical: return 3
        }
    }

    private static func getAllFiles(
        in directory: URL,
        relativeTo baseURL: URL,
        fileManager: FileManager
    ) throws -> [String: FileInfo] {
        var files: [String: FileInfo] = [:]

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw NSError(domain: "BDKComparo", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not enumerate directory: \(directory.path)"
            ])
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: baseURL.path + "/", with: "")
            let size = resourceValues.fileSize ?? 0
            let modDate = resourceValues.contentModificationDate

            files[relativePath] = FileInfo(size: size, modDate: modDate)
        }

        return files
    }
}

struct FileInfo {
    let size: Int
    let modDate: Date?
}
