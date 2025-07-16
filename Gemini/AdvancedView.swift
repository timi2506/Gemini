import SwiftUI
import QuickLook

struct FileRowView: View {
    let file: String
    let selectedFolder: URL
    let onPreview: (URL) -> Void
    let onDelete: (URL) -> Void

    var fileURL: URL {
        selectedFolder.appending(path: file)
    }

    var isFolder: Bool {
        (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.type] as? FileAttributeType) == .typeDirectory
    }

    var body: some View {
        Group {
            if isFolder {
                NavigationLink(destination: {
                    FolderListView(selectedFolder: fileURL)
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.title)
                            .scaledToFit()
                            .frame(width: 30)
                            .padding(.horizontal, 2.5)
                        VStack(alignment: .leading) {
                            Text(file)
                                .lineLimit(1)
                            Text(fileURL.path())
                                .lineLimit(2)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Button(action: {
                    onPreview(fileURL)
                }) {
                    HStack {
                        Image(systemName: "doc.fill")
                            .font(.title)
                            .scaledToFit()
                            .frame(width: 30)
                            .padding(.horizontal, 2.5)
                        VStack(alignment: .leading) {
                            Text(file)
                                .lineLimit(1)
                            Text(fileURL.path())
                                .lineLimit(2)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            Button("Copy File URL", systemImage: "link") {
                UIPasteboard.general.url = fileURL
            }
            Button("Copy File Path", systemImage: "folder") {
                UIPasteboard.general.string = fileURL.path()
            }
        }
        .swipeActions {
            Button("Delete", systemImage: "trash.fill", role: .destructive) {
                onDelete(fileURL)
            }
        }
    }
}

struct AdvancedView: View {
    var sharedFolder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.timi2506.Gemini")
    var appSupportFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    @Environment(\.dismiss) var dismiss
    @State var selectedFolder: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.timi2506.Gemini")
    @State var folderContents: [String]?
    @State var fileToDisplay: URL?
    @State var fileToDelete: URL?
    @State var deleteFileDialogue = false
    
    var body: some View {
        NavigationStack {
            TabView {
                folderView.tabItem {
                    Label("Folder", systemImage: "folder")
                }
                dangerousView.tabItem {
                    Label("Dangerous", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("Advanced Options")
        }
    }
    var dangerousView: some View {
        Form {
            Button("Reset User Defaults") {
                if let defaults = UserDefaults(suiteName: "group.timi2506.Gemini") {
                    for key in defaults.dictionaryRepresentation().keys {
                        UserDefaults(suiteName: "group.timi2506.Gemini")?.removeObject(forKey: key)
                    }
                }
                for key in UserDefaults.standard.dictionaryRepresentation().keys {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
            Button("Reset App") {
                if let defaults = UserDefaults(suiteName: "group.timi2506.Gemini") {
                    for key in defaults.dictionaryRepresentation().keys {
                        UserDefaults(suiteName: "group.timi2506.Gemini")?.removeObject(forKey: key)
                    }
                }
                for key in UserDefaults.standard.dictionaryRepresentation().keys {
                    UserDefaults.standard.removeObject(forKey: key)
                }
                if let files = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.timi2506.Gemini") {
                    do {
                        try FileManager.default.removeItem(at: files)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                for wallpaper in ThemeManager.shared.wallpapers {
                    ThemeManager.shared.removeWallpaper(for: wallpaper.id)
                }
                ThemeManager.shared.accentColor = .orange
                ChatSaves.shared.messages = []
                ChatSaves.shared.chatHistory = []
                ChatSaves.shared.chatHistoryData = Data()
                ChatSaves.shared.latestChatData = Data()
                ChatSaves.shared.saveHistory()
                ChatSaves.shared.saveLatest()
                restartDialogue()
            }
        }
    }
    var folderView: some View {
        VStack {
            if let folderContents {
                Form {
                    ForEach(folderContents, id: \.self) { file in
                        FileRowView(file: file, selectedFolder: selectedFolder!) { previewURL in
                            fileToDisplay = previewURL
                        } onDelete: { deleteURL in
                            fileToDelete = deleteURL
                            deleteFileDialogue = true
                        }
                    }
                    if folderContents.isEmpty {
                        Text("This Folder is empty or the Folder failed to Load")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .quickLookPreview($fileToDisplay)
                .refreshable(action: { await asyncRefresh() })
            }
        }
        .safeAreaInset(edge: .top) {
            Picker("Folder", selection: $selectedFolder) {
                Text("Shared/Default")
                    .tag(sharedFolder)
                Text("Fallback")
                    .tag(appSupportFolder)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .onChange(of: selectedFolder) {
            refreshFolderContents()
        }
        .onAppear {
            refreshFolderContents()
        }
        .confirmationDialog("Are you sure?", isPresented: $deleteFileDialogue, actions: {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
                deleteFileDialogue = false
            }
            Button("Confirm", role: .destructive) {
                if let fileToDelete {
                    do {
                        try FileManager.default.removeItem(at: fileToDelete)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                fileToDelete = nil
                deleteFileDialogue = false
            }
        }, message: { Text("Deleting \"\(fileToDelete?.lastPathComponent ?? "Unknown File")\" cannot be undone").multilineTextAlignment(.center).font(.caption).foregroundStyle(.secondary) })
    }
    func refreshFolderContents() {
        if let selectedFolder {
            folderContents = try? FileManager.default.contentsOfDirectory(atPath: selectedFolder.path())
        } else {
            folderContents = nil
        }
    }
    func asyncRefresh() async {
        try? await Task.sleep(for: .seconds(1.5))
        refreshFolderContents()
    }
    func restartDialogue() {
        dismiss()
        dismiss()
        guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else { return }
        let alert = UIAlertController(title: "Restart Required", message: "To finish resetting you need to restart the App by closing it from App Switcher and then re-opening it.", preferredStyle: .alert)
        rootVC.present(alert, animated: true)
    }
}

struct FolderListView: View {
    var selectedFolder: URL
    @State var folderContents: [String]?
    @State var fileToDisplay: URL?
    @State var fileToDelete: URL?
    @State var deleteFileDialogue = false
    
    var body: some View {
        Group {
            if let folderContents {
                Form {
                    ForEach(folderContents, id: \.self) { file in
                        let fileURL: URL = selectedFolder.appending(path: file)
                        let isFolder: Bool = {
                            (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.type] as? FileAttributeType) == .typeDirectory
                        }()
                        Group {
                            if isFolder {
                                NavigationLink(destination: {
                                    FolderListView(selectedFolder: fileURL)
                                }) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .font(.title)
                                            .scaledToFit()
                                            .frame(width: 30)
                                            .padding(.horizontal, 2.5)
                                        VStack(alignment: .leading) {
                                            Text(file)
                                                .lineLimit(1)
                                            Text(fileURL.path())
                                                .lineLimit(2)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } else {
                                Button(action: {
                                    let fileURL = selectedFolder.appending(path: file)
                                    fileToDisplay = fileURL
                                }) {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .font(.title)
                                            .scaledToFit()
                                            .frame(width: 30)
                                            .padding(.horizontal, 2.5)
                                        VStack(alignment: .leading) {
                                            Text(file)
                                                .lineLimit(1)
                                            Text(fileURL.path())
                                                .lineLimit(2)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .contextMenu {
                            Button("Copy File URL", systemImage: "link") {
                                UIPasteboard.general.url = fileURL
                            }
                            Button("Copy File Path", systemImage: "folder") {
                                UIPasteboard.general.string = fileURL.path()
                            }
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash.fill", role: .destructive) {
                                let fileURL = selectedFolder.appending(path: file)
                                fileToDelete = fileURL
                                deleteFileDialogue = true
                            }
                        }
                    }
                    if folderContents.isEmpty {
                        Text("This Folder is empty or the Folder failed to Load")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .quickLookPreview($fileToDisplay)
                .refreshable(action: { await asyncRefresh() })
            } else {
                Text("")
            }
        }
        .navigationTitle(selectedFolder.lastPathComponent)
        .onAppear(perform: refreshFolderContents)
    }
    func refreshFolderContents() {
            folderContents = try? FileManager.default.contentsOfDirectory(atPath: selectedFolder.path())
    }
    func asyncRefresh() async {
        try? await Task.sleep(for: .seconds(1.5))
        refreshFolderContents()
    }
}
