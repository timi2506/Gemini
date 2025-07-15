import SwiftUI
import AppIntents
import WidgetKit
import FoundationModels
import Combine

struct ModelWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "com.timi2506.Gemini-Model-Widget", intent: ModelWidgetConfiguration.self, provider: TimeLineProvider()) { entry in
            ModelWidgetView(entry: entry)
        }
        .configurationDisplayName("Model Widget")
        .description("Get Quick Access to a Selected Model")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
struct TimeLineProvider: AppIntentTimelineProvider {
    typealias Intent = ModelWidgetConfiguration
    typealias Entry = ModelEntry

    func placeholder(in context: Context) -> ModelEntry {
        ModelEntry(date: Date(), selectedModel: GeminiModel(name: "Gemini 2.0 Flash", id: "gemini-2.0-flash"), devMode: false)
    }
    
    func snapshot(for configuration: ModelWidgetConfiguration, in context: Context) async -> ModelEntry {
        if let configName = configuration.modelName, let configID = configuration.modelID {
            let entry = ModelEntry(date: Date(), selectedModel: GeminiModel(name: configName, id: configID), devMode: configuration.debug ?? false)
            return entry
        } else {
            let entry = ModelEntry(date: Date(), selectedModel: nil, devMode: configuration.debug ?? false)
            return entry
        }
    }

    func timeline(for configuration: ModelWidgetConfiguration, in context: Context) async -> Timeline<ModelEntry> {
        if let configName = configuration.modelName, let configID = configuration.modelID {
            let entry = ModelEntry(date: Date(), selectedModel: GeminiModel(name: configName, id: configID), devMode: configuration.debug ?? false)
            let nextUpdate = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } else {
            let entry = ModelEntry(date: Date(), selectedModel: nil, devMode: configuration.debug ?? false)
            let nextUpdate = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }
    }
}

struct ModelEntry: TimelineEntry {
    let date: Date
    let selectedModel: GeminiModel?
    let devMode: Bool
}

struct ModelWidgetView: View {
    var entry: ModelEntry
    var body: some View {
        ZStack {
            if entry.devMode {
                Text(entry.date, format: .dateTime)
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 12.5)
            }
            if let selectedModel = entry.selectedModel {
                VStack {
                    Text(selectedModel.name)
                        .lineLimit(2)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text(selectedModel.id)
                        .lineLimit(2)
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Link(destination: URL(string: "gchat://selectModel?name=\(selectedModel.name)&id=\(selectedModel.id)")!) {
                        Label("Select", systemImage: "checkmark")
                            .bold()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
                .ignoresSafeArea(edges: .all)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack {
                    Text("No Model selected")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Please select one by Press and holding this widget and selecting \"Edit Widget\"")
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 5)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

class GeminiModelStore: ObservableObject {
    private let userDefaultsKey = "models"
    
    // This returns a fresh copy from UserDefaults every time it's read
    var models: [GeminiModel] {
        get {
            if let data = UserDefaults(suiteName: "group.timi2506.Gemini")!.data(forKey: userDefaultsKey),
               let decoded = try? JSONDecoder().decode([GeminiModel].self, from: data) {
                return decoded
            } else {
                return defaultModels
            }
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults(suiteName: "group.timi2506.Gemini")!.set(encoded, forKey: userDefaultsKey)
                objectWillChange.send()
            }
        }
    }
    var intelligenceAvailable: Bool {
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        } else {
            return false
        }
    }
    var defaultModels: [GeminiModel] {
        if intelligenceAvailable {
            [
                GeminiModel(name: "Gemini 2.0 Flash", id: "gemini-2.0-flash"),
                GeminiModel(name: "Gemini 2.0 Flash-Lite", id: "gemini-2.0-flash-lite"),
                GeminiModel(name: "Gemini 1.5 Flash", id: "gemini-1.5-flash"),
                GeminiModel(name: "Gemini 1.5 Flash-8B", id: "gemini-1.5-flash-8b"),
                GeminiModel(name: "Gemini 1.5 Pro", id: "gemini-1.5-pro"),
                GeminiModel(name: "Apple Intelligence", id: "apple-intelligence")
            ]
        } else {
            [
                GeminiModel(name: "Gemini 2.0 Flash", id: "gemini-2.0-flash"),
                GeminiModel(name: "Gemini 2.0 Flash-Lite", id: "gemini-2.0-flash-lite"),
                GeminiModel(name: "Gemini 1.5 Flash", id: "gemini-1.5-flash"),
                GeminiModel(name: "Gemini 1.5 Flash-8B", id: "gemini-1.5-flash-8b"),
                GeminiModel(name: "Gemini 1.5 Pro", id: "gemini-1.5-pro"),
            ]
        }
    }
    
    func resetModels() {
        models = defaultModels
    }
}


struct GeminiModel: Codable, Identifiable, Hashable {
    let name: String
    let id: String
}

@main
struct PortalWidgetBundle: WidgetBundle {
    var body: some Widget {
        ModelWidget()
    }
}

struct ModelWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Widget"
    static var description = IntentDescription("Configure the Model to Display in the Widget")
    
    @Parameter(title: "Model Name", description: "The Name of the Model (for example: Gemini 2.0 Flash")
    var modelName: String?
    
    @Parameter(title: "Model ID", description: "The ID of the Model (for example: gemini-2.0-flash")
    var modelID: String?
    
    @Parameter(title: "Show Debug Info", description: "Shows additional debug info like the date the widget was updated at")
    var debug: Bool?
}

enum ModelWidgetError: LocalizedError {
    case modelNotInStore
    
    var errorDescription: String? {
        switch self {
        case .modelNotInStore:
            return "Model not saved in Gemini Model Store"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .modelNotInStore:
            "The Model has not been saved inside the App"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelNotInStore:
            "Try adding the Model inside of the App first"
        }
    }
}

