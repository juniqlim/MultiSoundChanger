//
//  VolumeHUD.swift
//  MultiSoundChanger
//

import Cocoa

final class VolumeHUD {
    static let shared = VolumeHUD()

    private var window: NSWindow?
    private var hideWorkItem: DispatchWorkItem?
    private let chicletCount = 16

    private init() {}

    func show(volume: Float, muted: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.present(volume: volume, muted: muted)
        }
    }

    private func present(volume: Float, muted: Bool) {
        let win = window ?? makeWindow()
        window = win

        let view = win.contentView as? HUDView
        view?.update(volume: volume, muted: muted, chicletCount: chicletCount)

        positionWindow(win)
        win.orderFrontRegardless()

        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)

        win.alphaValue = 1.0
    }

    private func fadeOut() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        })
    }

    private func makeWindow() -> NSWindow {
        let size = NSSize(width: 220, height: 220)
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .statusBar
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        w.hasShadow = false
        w.contentView = HUDView(frame: NSRect(origin: .zero, size: size))
        return w
    }

    private func positionWindow(_ win: NSWindow) {
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main
        guard let screen = screen else { return }
        let frame = screen.frame
        let size = win.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 140
        )
        win.setFrameOrigin(origin)
    }
}

// MARK: - HUD View

final class HUDView: NSView {
    private var volume: Float = 0
    private var muted: Bool = false
    private var chicletCount: Int = 16

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    func update(volume: Float, muted: Bool, chicletCount: Int) {
        self.volume = volume
        self.muted = muted
        self.chicletCount = chicletCount
        needsDisplay = true
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        // Rounded background panel
        let panelRect = bounds.insetBy(dx: 0, dy: 0)
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 22, yRadius: 22)
        NSColor(white: 0.10, alpha: 0.86).setFill()
        panelPath.fill()

        // Speaker icon
        let iconRect = NSRect(x: bounds.midX - 32, y: bounds.maxY - 90, width: 64, height: 64)
        let speakerName: String = muted ? "speaker.slash.fill" : (volume < 1 ? "speaker.fill" : (volume < 50 ? "speaker.wave.1.fill" : (volume < 80 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")))
        if let img = NSImage(systemSymbolName: speakerName, accessibilityDescription: nil) {
            let conf = NSImage.SymbolConfiguration(pointSize: 44, weight: .regular)
            let configured = img.withSymbolConfiguration(conf) ?? img
            configured.isTemplate = true
            let tinted = NSImage(size: configured.size, flipped: false) { rect in
                configured.draw(in: rect)
                NSColor.white.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0,
                        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
        }

        // Chiclets
        let chicletAreaWidth: CGFloat = 180
        let chicletAreaHeight: CGFloat = 14
        let originX = bounds.midX - chicletAreaWidth / 2
        let originY: CGFloat = 50
        let gap: CGFloat = 2
        let totalGap = gap * CGFloat(chicletCount - 1)
        let chicletWidth = (chicletAreaWidth - totalGap) / CGFloat(chicletCount)
        let step = 100.0 / Float(chicletCount)
        let filled = Int((volume / step).rounded())

        for i in 0..<chicletCount {
            let x = originX + CGFloat(i) * (chicletWidth + gap)
            let rect = NSRect(x: x, y: originY, width: chicletWidth, height: chicletAreaHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            if i < filled && !muted {
                NSColor.white.setFill()
            } else {
                NSColor(white: 1.0, alpha: 0.22).setFill()
            }
            path.fill()
        }

        // Percentage text
        let pctText = muted ? "Muted" : "\(Int(volume))%"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: pctText, attributes: attrs)
        let textSize = str.size()
        let textRect = NSRect(
            x: bounds.midX - textSize.width / 2,
            y: 20,
            width: textSize.width,
            height: textSize.height
        )
        str.draw(in: textRect)
    }
}
