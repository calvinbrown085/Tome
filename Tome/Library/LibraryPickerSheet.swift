import SwiftUI

struct LibraryPickerSheet: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(deps.librarySelection.libraries) { library in
                    Button {
                        deps.librarySelection.select(library.id)
                        Haptics.selection()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: iconName(for: library))
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            Text(library.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if library.id == deps.librarySelection.selectedLibraryID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Libraries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func iconName(for library: LibraryDTO) -> String {
        switch library.icon {
        case "audiobookshelf", "books-1", "book": return "books.vertical.fill"
        case "microphone", "podcast": return "mic.fill"
        default: return "books.vertical.fill"
        }
    }
}

#if DEBUG
#Preview("Library picker") {
    LibraryPickerSheet()
        .environment(PreviewSupport.dependencies())
}
#endif
