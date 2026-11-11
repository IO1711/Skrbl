import CoreGraphics

struct RenderedSketch: @unchecked Sendable {
    // CGImage is immutable; every render owns its bitmap until makeImage copies it.
    let image: CGImage?
}
