import Foundation
import UIKit

/// TVServices biedt voor een sectierij één afbeelding en één titelregel.
/// Daarom staan clearlogo en afleveringsinformatie samen in een compacte,
/// lokaal gecachete 16:9-afbeelding. Er wordt steeds maar één kaart tegelijk
/// gerenderd om de geheugenlimiet van een Top Shelf-extensie te respecteren.
@MainActor
enum TopShelfArtworkRenderer {
    private static let canvas = CGSize(width: 908, height: 512)
    private static let cacheAge: TimeInterval = 6 * 60 * 60

    static func removeOldArtwork() {
        guard let directory = cacheDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
              ) else { return }
        for file in files {
            guard let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  Date().timeIntervalSince(modified) > 7 * 86_400 else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func imageURL(for item: TopShelfContinueItem) async -> URL? {
        guard let directory = cacheDirectory() else { return nil }
        let file = directory.appendingPathComponent("\(item.id).jpg")
        if let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
           Date().timeIntervalSince(modified) < cacheAge {
            return file
        }

        let urls: (backdrop: URL?, logo: URL?, poster: URL?)
        if let tmdbID = item.tmdbID {
            urls = await TopShelfTMDBArtwork.imageURLs(isShow: item.isShow, tmdbID: tmdbID)
        } else {
            urls = (nil, nil, nil)
        }

        async let backdropData = download(urls.backdrop ?? urls.poster)
        async let logoData = download(urls.logo)
        let backdrop = (await backdropData).flatMap(UIImage.init(data:))
        let logo = (await logoData).flatMap(UIImage.init(data:))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
            let bounds = CGRect(origin: .zero, size: canvas)
            UIColor(red: 0.015, green: 0.07, blue: 0.11, alpha: 1).setFill()
            renderer.cgContext.fill(bounds)

            if let backdrop {
                backdrop.draw(in: aspectFillRect(for: backdrop.size, in: bounds))
            }
            UIColor.black.withAlphaComponent(0.30).setFill()
            renderer.cgContext.fill(bounds)

            let context = renderer.cgContext
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.82).cgColor] as CFArray,
                locations: [0, 1]
            ) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 230),
                    end: CGPoint(x: 0, y: canvas.height),
                    options: []
                )
            }

            if let logo {
                let fitted = aspectFitRect(
                    for: logo.size,
                    in: CGRect(x: 125, y: 105, width: 658, height: 220)
                )
                context.saveGState()
                context.setShadow(offset: .zero, blur: 20, color: UIColor.black.cgColor)
                logo.draw(in: fitted)
                context.restoreGState()
            } else {
                drawText(
                    item.title,
                    in: CGRect(x: 95, y: 162, width: 718, height: 138),
                    size: 52, color: .white, weight: .bold, alignment: .center
                )
            }

            if let season = item.season, let episode = item.episode {
                drawText(
                    "Seizoen \(season) · Aflevering \(episode)",
                    in: CGRect(x: 75, y: 386, width: 758, height: 45),
                    size: 31, color: UIColor(red: 0.08, green: 0.82, blue: 0.96, alpha: 1),
                    weight: .semibold
                )
                if let episodeTitle = item.episodeTitle, !episodeTitle.isEmpty {
                    drawText(
                        episodeTitle,
                        in: CGRect(x: 75, y: 433, width: 758, height: 32),
                        size: 24, color: .white, weight: .medium
                    )
                }
            }
        }

        guard let data = image.jpegData(compressionQuality: 0.84),
              (try? data.write(to: file, options: .atomic)) != nil
        else { return urls.backdrop }
        return file
    }

    private static func cacheDirectory() -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = caches.appendingPathComponent("TopShelfArtwork", isDirectory: true)
        guard (try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )) != nil else { return nil }
        return directory
    }

    private static func download(_ url: URL?) async -> Data? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { return nil }
        return data
    }

    private static func aspectFillRect(for image: CGSize, in bounds: CGRect) -> CGRect {
        guard image.width > 0, image.height > 0 else { return bounds }
        let scale = max(bounds.width / image.width, bounds.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func aspectFitRect(for image: CGSize, in bounds: CGRect) -> CGRect {
        guard image.width > 0, image.height > 0 else { return bounds }
        let scale = min(bounds.width / image.width, bounds.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        size: CGFloat,
        color: UIColor,
        weight: UIFont.Weight,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}
