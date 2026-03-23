# BDK Comparo — Project History

## The Need

BDK Comparo was born from a practical need: a clean, visual way to compare two folders on macOS and see exactly what's different — what's only in one place, what's in both, and what's changed. The kind of thing you need when syncing project folders, verifying backups, or just understanding what's where.

## How It Was Built

The project was developed as a native macOS application using Swift and SwiftUI, with no external dependencies — just the Swift standard library and system frameworks (AppKit for folder selection, FileManager for file operations, UniformTypeIdentifiers). The entire application lives in a single Swift file (BDKComparo.swift, ~1,450 lines), compiled directly with `swiftc`.

A simpler alternative implementation (FolderCompare.swift, ~375 lines) was also created — same core comparison logic in a more minimal, tabbed interface.

The compiled binaries date to January 19, 2026, predating the git history (January 30, 2026), suggesting the app was built and refined through direct iteration before being committed as a complete, working tool.

## What It Does

The comparison engine recursively walks both folder trees, skipping hidden files, and categorizes every file into one of four states: identical (same name and size in both), source-only, destination-only, or different (same name, different size). Results are sorted by status priority, then alphabetically.

The interface is a rich dark theme with a dual-panel layout — select source and destination folders, run the comparison, browse results by category, and inspect individual files. Status indicators are color-coded (cyan for source, pink for destination, purple for shared). There's an animated progress indicator during comparison and a summary panel showing counts for each category.

The sync feature copies files one-way from source to destination, creating directories as needed. It's non-destructive — it never deletes anything from the destination. A confirmation dialog appears before any file operations begin, with error and success banners for feedback.

## Design Choices

The app deliberately avoids complex file hashing for comparison, using file size as the primary differentiator. For the intended use cases (folder syncing, backup verification), this is a pragmatic tradeoff that keeps the comparison fast while being correct enough for most scenarios.

The single-file architecture was also intentional — BDK Comparo is meant to be a utility you can build and run with one command, not a project you manage.

## Technical Notes

- **Language**: Swift (macOS native)
- **UI**: SwiftUI
- **Dependencies**: None (pure system frameworks)
- **Build**: `swiftc -parse-as-library -o BDKComparo BDKComparo.swift -framework SwiftUI -framework AppKit`
- **License**: MIT
