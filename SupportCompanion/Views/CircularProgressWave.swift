//
//  CircularProgressWave.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-16.
//

import AppKit
import Foundation
import SwiftUI

struct CircularProgressWithWave: View {
    var progress: CGFloat
    var size: CGFloat
    var waveHeight: CGFloat
    var tint: NSColor
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Accent ring
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? Color(nsColor: .gray).opacity(0.5)
                        : Color(nsColor: .gray).opacity(0.3),
                    lineWidth: size * 0.02
                )// Thinner ring
                .frame(width: size, height: size)

            // Wave masked to a circle
            WaveLayerView(progress: progress, waveHeight: waveHeight, isMoving: !reduceMotion, tint: tint)
                .frame(width: size, height: size)
                .clipShape(Circle())

            // Progress text in the center
            Text("\(Int(progress * 100))%")
                .font(.largeTitle)
                .bold()
                .foregroundColor(colorScheme == .dark ? .white : .black) // Adapt text color
        }
        .frame(width: size, height: size)
    }
}

/// Renders the wave with Core Animation instead of SwiftUI.
///
/// Any SwiftUI animation, even one that only moves an offset, updates the view graph in the app on
/// every frame; for this wave that cost ~35% CPU for as long as the Home page was open. A CAAnimation
/// is played by the render server, so the app does no per-frame work. The earlier `.drawingGroup()`
/// version also allocated ~140 MB of Metal buffers.
private struct WaveLayerView: NSViewRepresentable {
    var progress: CGFloat
    var waveHeight: CGFloat
    var isMoving: Bool
    var tint: NSColor

    func makeNSView(context: Context) -> WaveNSView {
        WaveNSView()
    }

    func updateNSView(_ view: WaveNSView, context: Context) {
        view.progress = progress
        view.waveHeight = waveHeight
        view.isMoving = isMoving
        view.tint = tint
    }
}

private final class WaveNSView: NSView {
    var progress: CGFloat = 0 { didSet { if progress != oldValue { needsLayout = true } } }
    var waveHeight: CGFloat = 0 { didSet { if waveHeight != oldValue { needsLayout = true } } }
    var isMoving = false { didSet { if isMoving != oldValue { updateAnimation() } } }
    var tint: NSColor = .controlAccentColor { didSet { if tint != oldValue { updateColors() } } }

    /// Seconds for the wave to travel one full period
    private let wavePeriod: CFTimeInterval = 4
    private let animationKey = "waveMotion"
    private let gradientLayer = CAGradientLayer()
    private let waveMask = CAShapeLayer()
    /// Width the running animation was built for; the slide distance depends on it
    private var animatedWidth: CGFloat?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(gradientLayer)
        gradientLayer.mask = waveMask
        // Top to bottom, matching the previous SwiftUI LinearGradient (layer y points up on macOS)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        // The mask is two periods wide; sliding it left by one period loops seamlessly
        waveMask.bounds = CGRect(x: 0, y: 0, width: bounds.width * 2, height: bounds.height)
        waveMask.anchorPoint = .zero
        waveMask.position = .zero
        waveMask.path = wavePath(width: bounds.width * 2, height: bounds.height)
        CATransaction.commit()
        updateAnimation()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAnimation()
    }

    /// Top stop is a lighter shade of the tint, so the wave keeps its sense of depth on any accent.
    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            guard let base = tint.usingColorSpace(.sRGB) else {
                gradientLayer.colors = [tint.cgColor, tint.cgColor]
                return
            }
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            let top = NSColor(
                hue: hue,
                saturation: max(saturation - 0.25, 0),
                brightness: min(brightness + 0.2, 1),
                alpha: alpha
            )
            gradientLayer.colors = [top.cgColor, base.cgColor]
        }
    }

    private func updateAnimation() {
        let shouldAnimate = isMoving && window != nil && bounds.width > 0
        let isAnimating = waveMask.animation(forKey: animationKey) != nil
        // Leave a running animation alone unless the width changed, so layout passes don't restart it
        if shouldAnimate && isAnimating && animatedWidth == bounds.width { return }

        waveMask.removeAnimation(forKey: animationKey)
        animatedWidth = nil
        guard shouldAnimate else { return }
        animatedWidth = bounds.width

        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = 0
        animation.toValue = -bounds.width
        animation.duration = wavePeriod
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        waveMask.add(animation, forKey: animationKey)
    }

    /// Filled area below a sine wave with two periods across `width`, at `progress` of the height.
    private func wavePath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let level = height * progress
        let periodWidth = width / 2
        let step: CGFloat = 2

        path.move(to: CGPoint(x: 0, y: 0))
        var x: CGFloat = 0
        while x <= width {
            let y = level + waveHeight * sin(x / periodWidth * 2 * .pi)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        path.addLine(to: CGPoint(x: width, y: level + waveHeight * sin(2 * 2 * .pi)))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        return path
    }
}
