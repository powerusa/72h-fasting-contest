// Create the large-iPhone App Store size from existing real iPhone captures.
// Images are uniformly scaled and centered; no UI content is synthesized.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let input = root.appendingPathComponent("docs/screenshots/iphone")
let output = root.appendingPathComponent("docs/app-store/screenshots/iphone-large")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for file in try FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil) where file.pathExtension == "png" {
    let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(file as CFURL, nil)!, 0, nil)!
    let width = 1320, height = 2868
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.interpolationQuality = .high
    let scale = max(Double(width) / Double(image.width), Double(height) / Double(image.height))
    let w = Double(image.width) * scale, h = Double(image.height) * scale
    context.draw(image, in: CGRect(x: (Double(width) - w) / 2, y: (Double(height) - h) / 2, width: w, height: h))
    let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(file.lastPathComponent) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
    print("Exported large iPhone: \(file.lastPathComponent), 1320 × 2868, no alpha")
}
