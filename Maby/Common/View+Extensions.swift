import Factory
import SwiftUI

// MARK: - Debug extensions
extension View {
    /// Adds all the mocked dependencies to a view. Use ONLY on previews.
    @ViewBuilder
    public func mockedDependencies(empty: Bool = false) -> some View {
        #if DEBUG
        let viewContext =
            empty
             ? Container.emptyPreviewContainer().viewContext
             : Container.previewContainer().viewContext

        self
            .environment(\.managedObjectContext, viewContext)
        #else
        self
        #endif
    }
}
