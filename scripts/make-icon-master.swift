// Builds a full-bleed 1024 app-icon master from a source artwork.
//
// Some generated icons leave a transparent margin around the squircle.
// At Dock size that margin makes the icon read smaller than neighbors
// whose artwork paints the full tile. This script flattens the source
// onto its border color and scales it so the visible content fills the
// canvas edge to edge.
//
// Usage:
//   swift scripts/make-icon-master.swift --source icon.png --output master-1024.png \
//     [--size 1024] [--content-fraction 0.95] [--background #000000]
//
// content-fraction is the share of the source canvas the visible artwork
// occupies (measure the outer squircle edge). 1 - fraction is cropped
// evenly from each side; the cropped sliver is replaced by the background
// fill, so the squircle border meets the tile edge like a full-bleed icon.

import AppKit

func argument(_ flag: String) -> String? {
  guard let index = CommandLine.arguments.firstIndex(of: flag),
    index + 1 < CommandLine.arguments.count
  else { return nil }
  return CommandLine.arguments[index + 1]
}

guard let sourcePath = argument("--source"), let outputPath = argument("--output") else {
  FileHandle.standardError.write(
    Data("usage: make-icon-master --source S --output O [--size N] [--content-fraction F] [--background #RRGGBB]\n".utf8)
  )
  exit(2)
}

let side = Int(argument("--size") ?? "1024") ?? 1024
let contentFraction = Double(argument("--content-fraction") ?? "0.95") ?? 0.95
let backgroundHex = argument("--background") ?? "#000000"

func color(fromHex hex: String) -> CGColor {
  var scalar = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
  if scalar.count == 3 { scalar = scalar.map { "\($0)\($0)" }.joined() }
  var value: UInt64 = 0
  Scanner(string: scalar).scanHexInt64(&value)
  return CGColor(
    srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
    green: CGFloat((value >> 8) & 0xFF) / 255,
    blue: CGFloat(value & 0xFF) / 255,
    alpha: 1)
}

guard
  let source = NSImage(contentsOfFile: sourcePath),
  let tiff = source.tiffRepresentation,
  let rep = NSBitmapImageRep(data: tiff),
  let cgSource = rep.cgImage
else {
  FileHandle.standardError.write(Data("error: cannot read \(sourcePath)\n".utf8))
  exit(1)
}

guard
  let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else {
  FileHandle.standardError.write(Data("error: cannot create bitmap context\n".utf8))
  exit(1)
}

context.setFillColor(color(fromHex: backgroundHex))
context.fill(CGRect(x: 0, y: 0, width: side, height: side))
context.interpolationQuality = .high

let drawnSide = CGFloat(side) / CGFloat(contentFraction)
let origin = (CGFloat(side) - drawnSide) / 2
context.draw(cgSource, in: CGRect(x: origin, y: origin, width: drawnSide, height: drawnSide))

guard let composed = context.makeImage() else {
  FileHandle.standardError.write(Data("error: composition failed\n".utf8))
  exit(1)
}
let bitmap = NSBitmapImageRep(cgImage: composed)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
  FileHandle.standardError.write(Data("error: PNG encoding failed\n".utf8))
  exit(1)
}
do {
  try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
  FileHandle.standardError.write(Data("error: \(error)\n".utf8))
  exit(1)
}
print("wrote \(outputPath) (\(side)×\(side), content scaled from \(contentFraction))")
