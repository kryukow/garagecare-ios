import SwiftUI
import UIKit

/// Decorative, local animation. No location access or simulated speed readings.
struct GarageRoadScene: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var paused = false
    var body: some View {
        RoadRepresentable(moving: visible && scenePhase == .active && !reduceMotion && !paused)
            .frame(height: 130)
            .overlay(alignment: .topTrailing) {
                Button { paused.toggle() } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.garageSurface.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
                    .accessibilityLabel(paused ? "Продолжить анимацию дороги" : "Приостановить анимацию дороги")
            }
            .onAppear { visible = true }.onDisappear { visible = false }
    }
}

private struct RoadRepresentable: UIViewRepresentable {
    let moving: Bool
    func makeUIView(context: Context) -> GarageRoadSurface { GarageRoadSurface() }
    func updateUIView(_ view: GarageRoadSurface, context: Context) { view.moving = moving }
}

final class GarageRoadSurface: UIView {
    private final class Target: NSObject {
        weak var view: GarageRoadSurface?
        @objc func tick(_ link: CADisplayLink) { view?.tick(link) }
    }
    private let target = Target()
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private(set) var elapsed: CGFloat = 0
    var moving = false { didSet { configure() } }
    var isAnimating: Bool { link != nil }
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear; isOpaque = false; isUserInteractionEnabled = false
        isAccessibilityElement = false; target.view = self
        NotificationCenter.default.addObserver(self, selector: #selector(configure), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(configure), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(configure), name: .NSProcessInfoPowerStateDidChange, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("Code-only road") }
    deinit { link?.invalidate(); NotificationCenter.default.removeObserver(self) }
    override func didMoveToWindow() { super.didMoveToWindow(); configure() }
    @objc private func configure() {
        let enabled = moving && window != nil && UIApplication.shared.applicationState != .background
        if enabled && link == nil {
            last = 0
            let timer = CADisplayLink(target: target, selector: #selector(Target.tick(_:)))
            timer.add(to: .main, forMode: .common); link = timer
        } else if !enabled { link?.invalidate(); link = nil; last = 0 }
        let rate: Float = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : Float(min(120, window?.screen.maximumFramesPerSecond ?? 60))
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: min(30, rate), maximum: rate, preferred: rate)
        if link == nil { setNeedsDisplay() }
    }
    private func tick(_ link: CADisplayLink) {
        let dt = last == 0 ? 0 : min(0.05, link.timestamp - last); last = link.timestamp
        elapsed += CGFloat(dt); setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext(), bounds.width > 0 else { return }
        let scale = min(bounds.width / 360, bounds.height / 132)
        c.saveGState(); c.translateBy(x: (bounds.width - 360 * scale) / 2, y: (bounds.height - 132 * scale) / 2); c.scaleBy(x: scale, y: scale)
        let dark = traitCollection.userInterfaceStyle == .dark
        let ink = dark ? UIColor(red: 0.75, green: 0.79, blue: 0.84, alpha: 1) : UIColor.darkGray
        func stroke(_ alpha: CGFloat = 0.5, _ width: CGFloat = 0.8, _ points: [CGPoint]) {
            guard let first = points.first else { return }
            c.beginPath(); c.move(to: first); points.dropFirst().forEach { c.addLine(to: $0) }
            c.setStrokeColor(ink.withAlphaComponent(alpha).cgColor); c.setLineWidth(width); c.setLineCap(.round); c.setLineJoin(.round); c.strokePath()
        }
        func line(_ p: [CGFloat], _ alpha: CGFloat = 0.5) {
            let points = stride(from: 0, to: p.count - 1, by: 2).map { CGPoint(x: p[$0], y: p[$0 + 1]) }; stroke(alpha, 0.8, points)
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { line([x,y,x+w,y,x+w,y+h,x,y+h,x,y]) }
        let near = elapsed * 24, far = elapsed * 5
        for i in 0..<3 {
            let x = (CGFloat(i) * 220 - far).truncatingRemainder(dividingBy: 660) - 180
            c.beginPath(); c.move(to: CGPoint(x: x, y: 83)); c.addCurve(to: CGPoint(x: x+200, y: 84), control1: CGPoint(x: x+60, y: 52), control2: CGPoint(x: x+130, y: 90)); c.setStrokeColor(ink.withAlphaComponent(0.12).cgColor); c.setLineWidth(0.6); c.strokePath()
        }
        for i in 0..<8 {
            let raw = CGFloat(i) * 255 - near
            let x = ((raw.truncatingRemainder(dividingBy: 2040) + 2040).truncatingRemainder(dividingBy: 2040)) - 120
            if x < -170 || x > 410 { continue }
            switch i {
            case 0, 5:
                for dx in [CGFloat(0), 147] { line([x+dx,92,x+dx,25]); line([x+dx-10,33,x+dx+10,33]); line([x+dx-7,24,x+dx-7,30]); line([x+dx+7,24,x+dx+7,30]) }
                c.beginPath(); c.move(to: CGPoint(x: x+7,y: 25)); c.addQuadCurve(to: CGPoint(x: x+154,y: 25), control: CGPoint(x: x+80,y: 53)); c.setStrokeColor(ink.withAlphaComponent(0.3).cgColor); c.setLineWidth(0.55); c.strokePath()
            case 1:
                line([x,89,x,67,x+19,52,x+42,67,x+42,89]); line([x-5,68,x+19,49,x+47,68]); box(x+7,71,8,8); box(x+27,74,7,15); line([x+31,60,x+31,47,x+36,47,x+36,64])
            case 2:
                line([x,90,x,57]); c.addEllipse(in: CGRect(x: x-18,y: 35,width: 36,height: 31)); c.setStrokeColor(ink.withAlphaComponent(0.4).cgColor); c.strokePath(); line([x+39,91,x+39,79]); box(x+33,72,16,8)
            case 3:
                line([x,90,x,64,x+40,64,x+40,90]); line([x-5,64,x+20,48,x+45,64]); box(x+7,73,12,17); line([x+26,72,x+34,72]); line([x+26,79,x+34,79])
            case 4:
                line([x,93,x,58]); line([x,75,x-10,70,x-10,61]); line([x,69,x+11,64,x+11,53]); line([x+46,91,x+46,67,x+61,67,x+61,76,x+46,76])
            case 6:
                for j in 0..<5 { line([x+CGFloat(j)*12,91,x+CGFloat(j)*12,78]) }; line([x,82,x+48,82]); line([x,87,x+48,87])
            default:
                line([x,91,x,61]); box(x-11,49,22,12); line([x-6,55,x+6,55,x+3,52]); line([x+6,55,x+3,58])
            }
        }
        line([0,103,360,103],0.4)
        for i in 0..<15 { let raw = CGFloat(i)*33-near*1.6; let x = ((raw.truncatingRemainder(dividingBy: 495)+495).truncatingRemainder(dividingBy: 495))-33; line([x,115,x+13,115],0.25) }
        c.saveGState(); c.translateBy(x: 121,y: 87+sin(elapsed*5)*0.35)
        let body = CGMutablePath(); body.move(to: CGPoint(x: -38,y: 5)); for p in [CGPoint(x:-37,y:-8),CGPoint(x:-23,y:-10),CGPoint(x:-12,y:-21),CGPoint(x:12,y:-21),CGPoint(x:26,y:-9),CGPoint(x:40,y:-6),CGPoint(x:44,y:4),CGPoint(x:33,y:7),CGPoint(x:-35,y:7)] { body.addLine(to:p) }; body.closeSubpath()
        c.addPath(body); c.setFillColor((dark ? UIColor(red:0.04,green:0.06,blue:0.08,alpha:1) : UIColor.systemBackground).cgColor); c.fillPath(); c.addPath(body); c.setStrokeColor(ink.cgColor); c.setLineWidth(0.9); c.strokePath()
        line([-18,-10,-9,-17,10,-17,19,-10,-18,-10],0.65); line([1,-17,1,-10],0.5)
        for x in [CGFloat(-23),26] {
            let wheel = CGRect(x:x-7,y:0,width:14,height:14); c.setFillColor((dark ? UIColor.black : UIColor.white).cgColor); c.fillEllipse(in:wheel); c.setStrokeColor(ink.cgColor); c.strokeEllipse(in:wheel)
            for j in 0..<3 { let a = elapsed*4+CGFloat(j) * CGFloat.pi*2/3; line([x,7,x+cos(a)*4.5,7+sin(a)*4.5],0.5) }
        }
        c.setShadow(offset:.zero,blur:3,color:ink.withAlphaComponent(0.7).cgColor); line([37,-3,42,-2],0.95); c.restoreGState(); c.restoreGState()
    }
}
