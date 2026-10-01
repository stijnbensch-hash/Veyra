// VeyraCollectionArtworkStore.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Lokale opslag voor een eigen collectie-afbeelding (spec §58) -- zelfde bestandsgebaseerde
// patroon als `VeyraCollectionsStore.imagesDirectory`/`saveImage` (VeyraBentoCatalog.swift, voor
// Home-banners), maar in een eigen map zodat de twee losstaande "Collections"-systemen (spec
// expliciet onderscheiden, zie VeyraCollectionModels.swift) elkaars bestanden niet kunnen
// overschrijven. Device-only: zie `VeyraCollectionArtworkResolver`'s doc-comment voor waarom dit
// (nog) niet via VeyraHub syncbaar is (spec §76/§77).

import Foundation

enum VeyraCollectionArtworkStore {
    static var imagesDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("VeyraCollectionArtwork", isDirectory: true)
    }

    /// Bewaart een eigen afbeelding en geeft de bestandsnaam terug (voor `VeyraCollection.artworkReference`).
    static func saveImage(_ data: Data) -> String? {
        let directory = imagesDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }
}
