import Foundation
import Nuke

/// Konfiguriert die globale Nuke-ImagePipeline mit persistentem Disk-Cache.
/// Wird einmalig beim App-Start aus `ScentBoxApp.init()` aufgerufen.
enum ImagePipelineConfig {

    static func configure() {
        let dataCache = try? DataCache(name: "de.scentboxd.images")
        dataCache?.sizeLimit = 150 * 1024 * 1024 // 150 MB

        let imageCache = ImageCache()
        imageCache.costLimit = 50 * 1024 * 1024   // 50 MB decoded images in memory
        imageCache.countLimit = 100                 // max 100 images in memory

        let pipeline = ImagePipeline {
            $0.dataCache = dataCache
            $0.imageCache = imageCache

            let config = URLSessionConfiguration.default
            config.urlCache = nil
            $0.dataLoader = DataLoader(configuration: config)

            $0.dataCachePolicy = .automatic
        }

        ImagePipeline.shared = pipeline
    }
}
