import SwiftUI
import UIKit

struct WindowAccessor: UIViewRepresentable {
    var callback: (UIWindow?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No update needed
    }
}

extension View {
    func windowAccess(_ function: @escaping (UIWindow?) -> Void) -> some View {
        self.background(WindowAccessor(callback: function))
    }
}
