// Stillread/Services/DisplayLinkDriver.swift

import QuartzCore

/// Calls a handler once per screen refresh, asking for 120 Hz on ProMotion displays.
/// Keeps the display at a steady high rate while reading, so each word change
/// lands on the refresh closest to its scheduled time (within ~4 ms at 120 Hz).
@MainActor
final class DisplayLinkDriver: NSObject {
    typealias FrameHandler = @MainActor (_ targetTimestamp: CFTimeInterval, _ frameDuration: CFTimeInterval) -> Void

    private var link: CADisplayLink?
    private var handler: FrameHandler?

    var isRunning: Bool { link != nil }

    func start(_ handler: @escaping FrameHandler) {
        stop()
        self.handler = handler
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        handler = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        handler?(link.targetTimestamp, link.targetTimestamp - link.timestamp)
    }
}
