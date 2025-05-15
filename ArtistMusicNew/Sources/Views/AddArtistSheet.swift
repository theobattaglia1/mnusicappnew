// ─── AddArtistSheet.swift ──────────────────────────────────────────────────────
import SwiftUI

struct AddArtistSheet: View {
    @EnvironmentObject private var store: ArtistStore
    @Binding var selectedArtistID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Artist name", text: $name)
            }
            .navigationTitle("New Artist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Call on `store`, not `$store`
                        let newArtist = store.createArtist(name: name)
                        selectedArtistID = newArtist.id
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
struct AddArtistSheet_Preview: PreviewProvider {
    static var previews: some View {
        AddArtistSheet(
            selectedArtistID: .constant(UUID())
        )
        .environmentObject(ArtistStore())
    }
}
#endif
