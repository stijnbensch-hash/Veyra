import SwiftUI

/// Kiest één TMDB-bron (films of series) voor de hero — gedeeld door de
/// "Primaire bron"- en "Secundaire bron"-rij in de Hero-instellingen op
/// het Planken-scherm.
struct HeroSourcePickerView: View {
    let title: String
    @Binding var selection: HeroSourceSelection

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Films") {
                ForEach(TMDBShelfList.availableLists(for: .movie), id: \.self) { list in
                    row(kind: .movie, list: list)
                }
            }

            Section("Series") {
                ForEach(TMDBShelfList.availableLists(for: .series), id: \.self) { list in
                    row(kind: .series, list: list)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(kind: ShelfMediaKind, list: TMDBShelfList) -> some View {
        let candidate = HeroSourceSelection(kind: kind, list: list)
        let isSelected = candidate == selection

        return Button {
            selection = candidate
            dismiss()
        } label: {
            HStack {
                Text(list.label(for: kind))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(VeyraColors.cyan)
                }
            }
        }
    }
}
