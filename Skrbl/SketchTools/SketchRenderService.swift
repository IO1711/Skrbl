import CoreGraphics

actor SketchRenderService {
    func render(_ elements: [SketchElement]) -> RenderedSketch {
        RenderedSketch(image: SketchRenderer.render(elements))
    }
}
