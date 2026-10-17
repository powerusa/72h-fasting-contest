// Export ImageGen artwork to Apple's exact pixel dimensions in opaque sRGB PNG.
// Usage: xcrun swift scripts/export-app-store-assets.swift [source.png] [output-directory]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let input = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/images/app-store-master.png")
let output = URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "docs/app-store", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let original = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Cannot decode source artwork") }
let exports = [("header-3840x1646.png", 3840, 1646),
               ("universal-header-search-5244x2950.png", 5244, 2950),
               ("search-results-3840x2560.png", 3840, 2560)]
for (name, width, height) in exports {
    let scale = max(Double(width) / Double(original.width), Double(height) / Double(original.height))
    let drawWidth = Double(original.width) * scale
    let drawHeight = Double(original.height) * scale
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("Cannot allocate export") }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .high
    context.draw(original, in: CGRect(x: (Double(width) - drawWidth) / 2,
                                     y: (Double(height) - drawHeight) / 2,
                                     width: drawWidth, height: drawHeight))
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL,
                                                           UTType.png.identifier as CFString, 1, nil) else { fatalError("Cannot write PNG") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Export failed") }
    let check = CGImageSourceCreateWithURL(output.appendingPathComponent(name) as CFURL, nil)!
    let properties = CGImageSourceCopyPropertiesAtIndex(check, 0, nil)! as NSDictionary
    precondition(properties[kCGImagePropertyPixelWidth] as? Int == width)
    precondition(properties[kCGImagePropertyPixelHeight] as? Int == height)
    precondition(properties[kCGImagePropertyHasAlpha] as? Bool != true)
    print("Verified \(name): \(width) × \(height), opaque sRGB PNG")
}
