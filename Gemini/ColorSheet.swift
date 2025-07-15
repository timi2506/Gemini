import SwiftUI

struct ColorSheet: View {
    @Binding var color: Color
    @Environment(\.dismiss) var dismiss
    var colors: [Color] = [
        .red,
        Color(hue: 0.03, saturation: 0.8, brightness: 1.0), // coral-ish
        .orange,
        .yellow,
        .mint,
        .green,
        .teal,
        .cyan,
        Color(hue: 0.6, saturation: 0.5, brightness: 1.0), // soft blue
        Color(hue: 0.58, saturation: 0.7, brightness: 0.9), // Bright blue-purple,
        .blue,
        .indigo,
        .purple,
        Color(hue: 0.9, saturation: 0.4, brightness: 1.0), // lavender-pink
        .pink,
        .brown,
        Color(uiColor: .darkGray),
        .gray,
    ]
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 52))
            ]) {
                ForEach(colors, id: \.self) { colorItem in
                    ColorButton(selection: $color, color: colorItem)
                }
            }
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ColorPicker("Custom Color", selection: $color, supportsOpacity: false)
                        .labelsHidden()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        dismiss()
                    }, label: {
                        Group {
                            if #available(iOS 26, *) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .bold))
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 25))
                            }
                        }
                        .fontDesign(.rounded)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.gray)
                    })
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Accent Color")
        }
    }
}

struct ColorButton: View {
    @Binding var selection: Color
    var color: Color
    
    var body: some View {
        Button(action: { selection = color }) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay {
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: 2)
                }
                .padding(5)
                .overlay {
                    if selection == color {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct ColorSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var color: Color
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ColorSheet(color: $color)
                    .presentationDetents([.fraction(0.3)])
                    .presentationBackground {
                        ZStack {
                            Color(uiColor: UIColor.secondarySystemBackground)
                            LinearGradient(colors: [
                                color.opacity(0.05),
                                color.opacity(0.1),
                                color.opacity(0.15),
                                color.opacity(0.2),
                            ], startPoint: .top, endPoint: .bottom)
                        }
                    }
            }
    }
}

extension View {
    func colorSheet(isPresented: Binding<Bool>, color: Binding<Color>) -> some View {
        self.modifier(ColorSheetModifier(isPresented: isPresented, color: color))
    }
}
