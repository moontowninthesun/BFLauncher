import AppKit

enum AppArtwork {
    static let bfgEmblem: NSImage? = {
        #if SWIFT_PACKAGE
        let resourceBundles = [Bundle.module, Bundle.main]
        #else
        let resourceBundles = [Bundle.main]
        #endif

        for bundle in resourceBundles {
            if let url = bundle.url(forResource: "BFGEmblem", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }()
}
