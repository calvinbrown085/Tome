import Foundation
import UIKit

final class CoverArtCache: @unchecked Sendable {
    static let shared = CoverArtCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200
        return c
    }()

    private init() {}

    func image(for id: String) -> UIImage? {
        cache.object(forKey: id as NSString)
    }

    func store(_ image: UIImage, for id: String) {
        cache.setObject(image, forKey: id as NSString)
    }
}
