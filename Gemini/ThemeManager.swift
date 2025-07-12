import SwiftUI
import Combine
import UniformTypeIdentifiers

class ThemeManager: ObservableObject {
    init() {
        do {
            self.wallpapers = try fetchSavedWallpapers()
        } catch {
            print(error.localizedDescription)
            self.wallpapers = []
        }
    }
    static let shared = ThemeManager()
    
    @Published var wallpapers: [Wallpaper]
    
    static var baseApplicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }
    
    static var wallpaperFilesLocation: URL {
        baseApplicationSupportDirectory.appendingPathComponent("WallpaperPlists", conformingTo: .folder)
    }
    
    static var wallpaperLocation: URL {
        baseApplicationSupportDirectory.appendingPathComponent("Wallpapers", conformingTo: .folder)
    }
    
    func saveWallpaper(pngData: Data, name: String) throws {
        let newID = UUID()
        let wallpaperItem = Wallpaper(id: newID, name: name, dateLastModified: Date())
        let encoder = PropertyListEncoder()
        let encoded = try encoder.encode(wallpaperItem)
        let wallpaperSaveLocation = Self.wallpaperLocation.appendingPathComponent(newID.uuidString, conformingTo: .png)
        try pngData.write(to: wallpaperSaveLocation)
        let wallpaperFileLocation = Self.wallpaperFilesLocation.appendingPathComponent(newID.uuidString, conformingTo: .propertyList)
        try encoded.write(to: wallpaperFileLocation)
        refetchSavedWallpapers()
        UserDefaults.standard.set(newID.uuidString, forKey: "selectedWallpaper")
    }
    
    func refetchSavedWallpapers() {
        let currentWallpapers = wallpapers
        do {
            wallpapers = []
            wallpapers = try fetchSavedWallpapers()
        } catch {
            print(error.localizedDescription)
            wallpapers = currentWallpapers
        }
    }
    
    func removeWallpaper(for id: UUID) {
        wallpapers.removeAll(where: { $0.id == id })
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let wallpaperFile = Self.wallpaperFilesLocation.appendingPathComponent(id.uuidString, conformingTo: .propertyList)
            try? FileManager.default.removeItem(at: wallpaperFile)
            let wallpaper = Self.wallpaperLocation.appendingPathComponent(id.uuidString, conformingTo: .png)
            try? FileManager.default.removeItem(at: wallpaper)
        }
    }
}

private func fetchSavedWallpapers() throws -> [Wallpaper] {
    let fileManager = FileManager.default
    
    let baseDir = ThemeManager.baseApplicationSupportDirectory
    let wallpaperFilesDir = ThemeManager.wallpaperFilesLocation
    let wallpaperDir = ThemeManager.wallpaperLocation
    
    if !fileManager.fileExists(atPath: baseDir.path) {
        do {
            try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true, attributes: nil)
            print("Created base application support directory: \(baseDir.path)")
        } catch {
            print("Error creating base application support directory: \(error.localizedDescription)")
            throw error
        }
    }
    
    if !fileManager.fileExists(atPath: wallpaperFilesDir.path) {
        do {
            try fileManager.createDirectory(at: wallpaperFilesDir, withIntermediateDirectories: true, attributes: nil)
            print("Created wallpaperFilesLocation: \(wallpaperFilesDir.path)")
        } catch {
            print("Error creating wallpaperFilesLocation: \(error.localizedDescription)")
            throw error
        }
    }
    
    if !fileManager.fileExists(atPath: wallpaperDir.path) {
        do {
            try fileManager.createDirectory(at: wallpaperDir, withIntermediateDirectories: true, attributes: nil)
            print("Created wallpaperLocation: \(wallpaperDir.path)")
        } catch {
            print("Error creating wallpaperLocation: \(error.localizedDescription)")
            throw error
        }
    }
    
    var loadedWallpapers: [Wallpaper] = []
    
    do {
        let contents = try fileManager.contentsOfDirectory(at: wallpaperFilesDir, includingPropertiesForKeys: [])
        print("Contents of wallpaperFilesLocation: \(contents.map { $0.lastPathComponent })")
        
        for file in contents {
            guard !file.hasDirectoryPath else { continue }
            
            do {
                let fileData = try Data(contentsOf: file)
                let decoder = PropertyListDecoder()
                loadedWallpapers.append(
                    try decoder.decode(Wallpaper.self, from: fileData)
                )
            } catch {
                print("Error decoding wallpaper from \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
    } catch {
        print("Error listing contents of wallpaperFilesLocation: \(error.localizedDescription)")
        throw error
    }
    
    return loadedWallpapers
}

struct Wallpaper: Codable, Identifiable {
    var id: UUID
    var name: String
    var dateLastModified: Date
}

extension URL {
    var safelyAccessed: URL {
        let accessed = self.startAccessingSecurityScopedResource()
        print(accessed)
        return self
    }
}

import PhotosUI
import NotchMyProblem

struct WallpaperPicker: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var manager = ThemeManager.shared
    var screenScale: CGRect {
        UIScreen.main.bounds
    }
    @State var pickerItem: PhotosPickerItem?
    @State var imageData: PickedWallpaperData?
    @AppStorage("selectedWallpaper") var selectedWallpaperID: String = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
    
    var body: some View {
        TabView(selection: $selectedWallpaperID) {
            defaultView
                .tag("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
            ForEach(manager.wallpapers.sorted(by: { $0.dateLastModified < $1.dateLastModified })) { wallpaper in
                wallpaperPickerView(for: wallpaper)
                    .tag(wallpaper.id.uuidString)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .fullScreenCover(item: $imageData, onDismiss: {
            pickerItem = nil
        }) { wall in
            WallpaperPreviewView(wall: wall, imageData: $imageData)
        }
        .onChange(of: pickerItem) {
            if let item = pickerItem {
                Task {
                    do {
                        if let data = try await item.loadTransferable(type: Data.self) {
                            imageData = PickedWallpaperData(data: data)
                            if let uiImage = UIImage(data: data),
                               let pngData = uiImage.pngData() {
                                imageData = PickedWallpaperData(data: pngData) // Only store PNG data
                            }
                        }
                    } catch {
                        print("Failed to load image data: \(error)")
                    }
                }
            }
        }
    }
    @State var renameSheet = false
    func wallpaperPickerView(for wallpaper: Wallpaper) -> some View {
        var binding = Binding(
            get: { return manager.wallpapers.first(where: { $0.id == wallpaper.id })!
            }, set: { newValue in //
                if let index = manager.wallpapers.firstIndex(where: { $0.id == newValue.id }) {
                    manager.wallpapers[index] = newValue
                }
            }        )
        return GeometryReader { geometry in
            VStack {
                HStack {
                    Spacer()
                    Menu(content: {
                        Button("Rename", systemImage: "pencil") {
                            renameSheet.toggle()
                        }
                    }, label: {
                        VStack {
                            Text(wallpaper.name.isEmpty ? "UNTITLED" : wallpaper.name.uppercased())
                                .lineLimit(1)
                                .font(.caption)
                                .bold()
                            Text(wallpaper.id.uuidString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    })
                    .buttonStyle(.plain)
                    .alert("Rename Wallpaper", isPresented: $renameSheet) {
                        TextField("New Name", text: binding.name)
                        Button("OK") {
                            renameSheet = false
                        }
                    } message: {
                        Text("Enter a new name for this wallpaper.")
                    }
                    Spacer()
                }
                Spacer()
                wallpaper.asyncImage(placeholder: {
                    ProgressView()
                }, content: { image in
                    ZStack {
                        image
                            .resizable()
                            .scaledToFill()
                        ScrollView {
                            Message(user: true, message: "Hello, how are you?")
                            Message(user: false, message: "I'm fine, what about you?")
                            Message(user: true, message: "Hey! What's a super quick dinner idea?")
                            Message(user: false, message: "Pasta with pesto & tomatoes! Or quick sheet pan chicken.")
                            Message(user: true, message: "Ooh, sheet pan chicken sounds good. What's the bare minimum I need for that?")
                            Message(user: false, message: "Chicken, your fave veggies (broccoli, bell peppers work great), olive oil, and some seasoning. Toss 'em, bake till done!")
                            Message(user: true, message: "Got it! Thanks! Okay, next: Gimme a fast joke.")
                            Message(user: false, message: "Why did the scarecrow win an award? He was outstanding in his field!")
                            Message(user: true, message: "Haha, nice! Another quick one? My friend needs a chuckle.")
                            Message(user: false, message: "What do you call a fake noodle? An impasta!")
                            Message(user: true, message: "Lol! That's a good one. Alright, last one for real: Insta caption for my fluffy, sleepy dog?")
                            Message(user: false, message: "'Just rolled out of bed, still floofier than your favorite blanket!'")
                            Message(user: true, message: "Haha, perfect! What about for my cat who's judging me from the top of the fridge?")
                            Message(user: false, message: "'My feline overlord's morning inspection.' Or 'Fridge goals achieved. Now, human, fetch me snacks.'")
                            Message(user: true, message: "😂 'Feline overlord' is spot on. Thanks for all the quick ideas!")
                            Message(user: false, message: "Anytime! Happy to help with the important stuff. 😉")
                        }
                        .scrollIndicators(.never)
                        .frame(width: geometry.size.width - 100, height: geometry.size.height - 100)
                        .scaleEffect(0.95)
                        
                    }
                    .frame(width: geometry.size.width - 100, height: geometry.size.height - 100)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .onTapGesture {
                        dismiss()
                    }
                })
                Spacer()
                HStack {
                    PhotosPicker(selection: $pickerItem){
                        Image(systemName: "plus")
                            .resizable()
                            .bold()
                            .scaledToFit()
                            .frame(height: 17.5)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    Button(action: {
                        manager.removeWallpaper(for: wallpaper.id)
                    }){
                        Image(systemName: "trash.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 17.5)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
                
            }
        }
    }
    var defaultView: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    Spacer()
                    VStack {
                        Text("DEFAULT")
                            .font(.caption)
                            .bold()
                        Text("NONE")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
                ZStack {
                    Color(uiColor: .systemBackground)
                    ScrollView {
                        Message(user: true, message: "Hello, how are you?")
                        Message(user: false, message: "I'm fine, what about you?")
                        Message(user: true, message: "Hey! What's a super quick dinner idea?")
                        Message(user: false, message: "Pasta with pesto & tomatoes! Or quick sheet pan chicken.")
                        Message(user: true, message: "Ooh, sheet pan chicken sounds good. What's the bare minimum I need for that?")
                        Message(user: false, message: "Chicken, your fave veggies (broccoli, bell peppers work great), olive oil, and some seasoning. Toss 'em, bake till done!")
                        Message(user: true, message: "Got it! Thanks! Okay, next: Gimme a fast joke.")
                        Message(user: false, message: "Why did the scarecrow win an award? He was outstanding in his field!")
                        Message(user: true, message: "Haha, nice! Another quick one? My friend needs a chuckle.")
                        Message(user: false, message: "What do you call a fake noodle? An impasta!")
                        Message(user: true, message: "Lol! That's a good one. Alright, last one for real: Insta caption for my fluffy, sleepy dog?")
                        Message(user: false, message: "'Just rolled out of bed, still floofier than your favorite blanket!'")
                        Message(user: true, message: "Haha, perfect! What about for my cat who's judging me from the top of the fridge?")
                        Message(user: false, message: "'My feline overlord's morning inspection.' Or 'Fridge goals achieved. Now, human, fetch me snacks.'")
                        Message(user: true, message: "😂 'Feline overlord' is spot on. Thanks for all the quick ideas!")
                        Message(user: false, message: "Anytime! Happy to help with the important stuff. 😉")
                    }
                    .scrollIndicators(.never)
                    .frame(width: geometry.size.width - 100, height: geometry.size.height - 100)
                    .scaleEffect(0.95)
                    
                }
                .frame(width: geometry.size.width - 100, height: geometry.size.height - 100)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .onTapGesture {
                    dismiss()
                }
                Spacer()
                HStack {
                    PhotosPicker(selection: $pickerItem){
                        Image(systemName: "plus")
                            .resizable()
                            .bold()
                            .scaledToFit()
                            .frame(height: 17.5)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
                
            }
        }
    }
}

struct WallpaperPreviewView: View {
    var wall: PickedWallpaperData
    @Binding var imageData: PickedWallpaperData?
    @StateObject var manager = ThemeManager.shared
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Image(uiImage: .init(data: wall.data) ?? UIImage(systemName: "apple.logo")!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height)
                    .background(.background)
                    .ignoresSafeArea()
                HStack {
                    Button(action: { imageData = nil }) {
                        Text("Cancel")
                            .padding(7.5)
                            .padding(.horizontal, 2.5)
                            .background(Capsule().foregroundStyle(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    Spacer()
                    Button(action: {
                        do {
                            try manager.saveWallpaper(pngData: wall.data, name: "")
                            imageData = nil
                        } catch {
                            print(error.localizedDescription)
                        }
                    }) {
                        Text("Save")
                            .padding(7.5)
                            .padding(.horizontal, 2.5)
                            .background(Capsule().foregroundStyle(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
                .padding(.horizontal)
                .padding(.top, proxy.safeAreaInsets.top + 16)
                .frame(maxWidth: .infinity)
                .zIndex(1)
            }
            .edgesIgnoringSafeArea(.all)
            .presentationBackground(.background)
            .statusBarHidden()
        }
    }
}

struct PickedWallpaperData: Identifiable {
    let id = UUID()
    var data: Data
}

#Preview {
    WallpaperPicker()
}

extension Wallpaper {
    func asyncImage<Placeholder: View, Content: View>(placeholder: @escaping () -> Placeholder, content: @escaping (Image) -> Content) -> AsyncImage<_ConditionalContent<Content, Placeholder>> {
        AsyncImage(url: ThemeManager.wallpaperLocation.appendingPathComponent(self.id.uuidString, conformingTo: .png), content: content, placeholder: placeholder)
    }
}
