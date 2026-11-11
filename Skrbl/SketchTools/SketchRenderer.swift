//
//  SketchRenderer.swift
//  Skrbl
//
//  Created by Codex on 31/07/2026.
//

import CoreGraphics
import Foundation

nonisolated enum SketchRenderer {
    private static let width = 512
    private static let height = 512
    private static let bytesPerPixel = 4
    private static let lineWidth: CGFloat = 4

    static func render(_ elements: [SketchElement]) -> CGImage? {
        guard !elements.isEmpty, !Task.isCancelled else { return nil }

        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](
            repeating: 255,
            count: height * bytesPerRow
        )

        return pixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }

            let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) else {
                return nil
            }

            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setShouldAntialias(true)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let pixelBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)

            for element in elements {
                guard !Task.isCancelled else { return nil }
                switch element.kind {
                case .stroke:
                    guard let stroke = element.stroke else { continue }
                    draw(stroke, in: context)
                case .fill:
                    guard let fill = element.fill else { continue }
                    context.flush()
                    floodFill(
                        fill,
                        pixels: pixelBuffer,
                        bytesPerRow: bytesPerRow
                    )
                }
            }

            context.flush()
            return context.makeImage()
        }
    }

    private static func draw(
        _ stroke: SketchStroke,
        in context: CGContext
    ) {
        guard let firstPoint = stroke.points.first else { return }

        let rgba = stroke.color.rgba
        let color = CGColor(
            red: CGFloat(rgba.red) / 255,
            green: CGFloat(rgba.green) / 255,
            blue: CGFloat(rgba.blue) / 255,
            alpha: CGFloat(rgba.alpha) / 255
        )
        let start = pixelPoint(for: firstPoint)

        if stroke.points.count == 1 {
            context.setFillColor(color)
            context.fillEllipse(
                in: CGRect(
                    x: start.x - lineWidth / 2,
                    y: start.y - lineWidth / 2,
                    width: lineWidth,
                    height: lineWidth
                )
            )
            return
        }

        context.beginPath()
        context.move(to: start)
        for point in stroke.points.dropFirst() {
            context.addLine(to: pixelPoint(for: point))
        }
        context.setStrokeColor(color)
        context.strokePath()
    }

    private static func floodFill(
        _ fill: SketchFill,
        pixels: UnsafeMutablePointer<UInt8>,
        bytesPerRow: Int
    ) {
        let startX = min(
            max(Int(fill.point.x * Double(width)), 0),
            width - 1
        )
        let startY = min(
            max(Int(fill.point.y * Double(height)), 0),
            height - 1
        )
        let startPixel = startY * width + startX
        let startOffset = startY * bytesPerRow + startX * bytesPerPixel
        let target = SketchRGBA(
            red: pixels[startOffset],
            green: pixels[startOffset + 1],
            blue: pixels[startOffset + 2],
            alpha: pixels[startOffset + 3]
        )
        let replacement = fill.color.rgba

        guard !colorsMatch(target, replacement) else { return }

        var queue: [Int] = []
        queue.reserveCapacity(width * height / 4)
        queue.append(startPixel)
        write(replacement, at: startOffset, in: pixels)

        var queueIndex = 0
        while queueIndex < queue.count {
            if queueIndex.isMultiple(of: 1_024), Task.isCancelled { return }
            let pixel = queue[queueIndex]
            queueIndex += 1

            let x = pixel % width
            let y = pixel / width

            if x > 0 {
                enqueueIfMatching(
                    pixel - 1,
                    target: target,
                    replacement: replacement,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    queue: &queue
                )
            }
            if x + 1 < width {
                enqueueIfMatching(
                    pixel + 1,
                    target: target,
                    replacement: replacement,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    queue: &queue
                )
            }
            if y > 0 {
                enqueueIfMatching(
                    pixel - width,
                    target: target,
                    replacement: replacement,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    queue: &queue
                )
            }
            if y + 1 < height {
                enqueueIfMatching(
                    pixel + width,
                    target: target,
                    replacement: replacement,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    queue: &queue
                )
            }
        }
    }

    private static func enqueueIfMatching(
        _ pixel: Int,
        target: SketchRGBA,
        replacement: SketchRGBA,
        pixels: UnsafeMutablePointer<UInt8>,
        bytesPerRow: Int,
        queue: inout [Int]
    ) {
        let x = pixel % width
        let y = pixel / width
        let offset = y * bytesPerRow + x * bytesPerPixel

        guard pixels[offset] == target.red,
              pixels[offset + 1] == target.green,
              pixels[offset + 2] == target.blue,
              pixels[offset + 3] == target.alpha else {
            return
        }

        write(replacement, at: offset, in: pixels)
        queue.append(pixel)
    }

    private static func write(
        _ color: SketchRGBA,
        at offset: Int,
        in pixels: UnsafeMutablePointer<UInt8>
    ) {
        pixels[offset] = color.red
        pixels[offset + 1] = color.green
        pixels[offset + 2] = color.blue
        pixels[offset + 3] = color.alpha
    }

    private static func colorsMatch(
        _ first: SketchRGBA,
        _ second: SketchRGBA
    ) -> Bool {
        first.red == second.red
            && first.green == second.green
            && first.blue == second.blue
            && first.alpha == second.alpha
    }

    private static func pixelPoint(for point: SketchPoint) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x) * CGFloat(width - 1),
            y: CGFloat(point.y) * CGFloat(height - 1)
        )
    }
}
