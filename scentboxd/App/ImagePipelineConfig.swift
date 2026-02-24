import Foundation
import Nuke

/// Konfiguriert die globale Nuke-ImagePipeline mit persistentem Disk-Cache.
/// Wird einmalig beim App-Start aus `ScentBoxApp.init()` aufgerufen.
enum ImagePipelineConfig {

    static func configure() {
        // 1. Persistenter Disk-Cache (150 MB) – überlebt App-Neustarts
        let dataCache = try? DataCache(name: "de.scentboxd.images")
        dataCache?.sizeLimit = 150 * 1024 * 1024 // 150 MB

        // 2. Pipeline zusammenbauen
        let pipeline = ImagePipeline {
            // Disk-Cache für fertig geladene Bilder
            $0.dataCache = dataCache

            // URLSession-Cache deaktivieren, da DataCache übernimmt
            let config = URLSessionConfiguration.default
            config.urlCache = nil               // kein doppelter Cache
            $0.dataLoader = DataLoader(configuration: config)

            // Bilder aggressiv aus dem Cache laden, wenn vorhanden
            $0.dataCachePolicy = .automatic
        }

        ImagePipeline.shared = pipeline
    }
}
