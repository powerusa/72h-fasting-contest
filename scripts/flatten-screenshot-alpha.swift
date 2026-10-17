// Re-encode native simulator screenshots as opaque sRGB PNG without resizing.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let folder = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/screenshots", isDirectory: true)
let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)!.allObjects.compactMap { $0 as? URL }.filter { $0.pathExtension == "png" }
for file in files {
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
          let original = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: original.width, height: original.height,
                                  bitsPerComponent: 8, bytesPerRow: original.width * 4, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("Cannot decode \(file.path)") }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    let rect = CGRect(x: 0, y: 0, width: original.width, height: original.height)
    context.fill(rect)
    context.draw(original, in: rect)
    let result = context.makeImage()!
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, result, nil)
    precondition(CGImageDestinationFinalize(destination))
    try (data as Data).write(to: file, options: .atomic)
    print("Opaque PNG: \(file.lastPathComponent), \(original.width) × \(original.height)")
}
