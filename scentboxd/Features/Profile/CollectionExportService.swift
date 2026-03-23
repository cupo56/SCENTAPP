//
//  CollectionExportService.swift
//  scentboxd
//

import SwiftUI

@MainActor
struct CollectionExportService {

    private static let session = PinnedURLSession.makeSession()

    /// Rendert die CollectionShareView als teilbares UIImage.
    /// Bilder werden vorab geladen und synchron an die View übergeben.
    static func renderCollectionImage(
        perfumes: [Perfume],
        username: String,
        favoriteCount: Int
    ) async -> UIImage? {
        let displayPerfumes = Array(perfumes.prefix(8))

        // Bilder parallel vorladen
        let loadedImages = await loadImages(for: displayPerfumes)

        let view = CollectionShareView(
            perfumes: displayPerfumes,
            username: username,
            totalCount: perfumes.count,
            favoriteCount: favoriteCount,
            loadedImages: loadedImages
        )
        .frame(width: 480)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    /// Rendert eine einzelne Parfum-Share-Karte als UIImage.
    static func renderPerfumeImage(perfume: Perfume) async -> UIImage? {
        let perfumeImage = await loadImage(from: perfume.imageUrl)

        let view = PerfumeShareView(perfume: perfume, perfumeImage: perfumeImage)
            .frame(width: 400)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    /// Lädt ein einzelnes Bild von einer URL.
    private static func loadImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    /// Lädt alle Parfum-Bilder parallel und gibt ein Dictionary [PerfumeID: UIImage] zurück.
    private static func loadImages(for perfumes: [Perfume]) async -> [UUID: UIImage] {
        await withTaskGroup(of: (UUID, UIImage?).self, returning: [UUID: UIImage].self) { group in
            for perfume in perfumes {
                guard let url = perfume.imageUrl else { continue }
                let id = perfume.id
                group.addTask {
                    do {
                        let (data, _) = try await session.data(from: url)
                        return (id, UIImage(data: data))
                    } catch {
                        return (id, nil)
                    }
                }
            }

            var result: [UUID: UIImage] = [:]
            for await (id, image) in group {
                if let image {
                    result[id] = image
                }
            }
            return result
        }
    }
}
