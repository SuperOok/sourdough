import CoreGraphics
import ImageIO
import Foundation

// Usage: swift flatten.swift <in.png> <out.png>
// Draws the input onto an opaque RGB canvas filled with the brand green #2F5D50 of the same size and writes a PNG without alpha.
let args = CommandLine.arguments
guard args.count == 3 else { fatalError("usage: flatten.swift <in.png> <out.png>") }
let inURL = URL(fileURLWithPath: args[1]) as CFURL
let outURL = URL(fileURLWithPath: args[2]) as CFURL
guard let source = CGImageSourceCreateWithURL(inURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("cannot read \(args[1])") }
let width = image.width, height = image.height
let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("no context") }
context.setFillColor(CGColor(red: 47.0 / 255, green: 93.0 / 255, blue: 80.0 / 255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
guard let flat = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(outURL, "public.png" as CFString, 1, nil) else { fatalError("no output") }
CGImageDestinationAddImage(destination, flat, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("write failed") }
