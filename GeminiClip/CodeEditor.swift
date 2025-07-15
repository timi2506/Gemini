import SwiftUI
import CodeEditor

struct CodeEditorView: View {
    @Binding var source: String
    @State private var language = CodeEditor.Language.swift
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack {
            HStack {
                Picker("Language", selection: $language) {
                    ForEach(CodeEditor.availableLanguages) { language in
                        Text("\(language.rawValue.capitalized)")
                            .tag(language)
                    }
                }
                Spacer()
                Button("Done", action: dismiss.callAsFunction)
            }
            .padding()
            CodeEditor(source: $source, language: language)
        }
    }
}

#Preview {
    CodeEditorView(source: .constant("Hi"))
}
