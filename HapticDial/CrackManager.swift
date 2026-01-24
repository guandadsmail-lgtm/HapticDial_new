import SwiftUI
import Combine
import AVFoundation
import CoreHaptics

class CrackManager: ObservableObject {
    static let shared = CrackManager()
    
    // MARK: - Published Properties
    @Published var showCracks = false
    @Published var cracks: [CrackModel] = []
    @Published var impactPoints: [ImpactPoint] = []
    @Published var crackOpacity: Double = 1.0
    
    // MARK: - Public State
    // 让外部可以读取状态，防止重复触发
    @Published private(set) var isActive = false
    
    // MARK: - Private Properties
    private var animationTimer: Timer?
    private var engine: CHHapticEngine?
    
    // 序列控制
    private var hitCount = 0
    private let timeBetweenHits: TimeInterval = 5.5 // 两次敲击的间隔
    
    // MARK: - Initialization
    private init() {
        setupHaptics()
        setupAudioSession()
    }
    
    // MARK: - Public API
    
    /// 开始自动化的三次碎裂流程
    func triggerCrack(screenSize: CGSize? = nil) {
        // [关键修复] 防抖：如果当前正在运行碎裂流程，直接忽略新的触发，防止重置
        if isActive {
            print("💥 裂纹效果已经在运行中，跳过此次触发")
            return
        }
        
        // 获取尺寸
        let effectiveSize: CGSize
        if let size = screenSize {
            effectiveSize = size
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first {
            effectiveSize = window.bounds.size
        } else {
            effectiveSize = CGSize(width: 390, height: 844)
        }
        
        // 重置状态并开始
        resetState()
        isActive = true
        showCracks = true
        crackOpacity = 1.0
        
        print("💥 开始慢速碎裂序列：每次持续5秒，共3次")
        
        // 启动高频动画计时器 (60FPS)
        startAnimationLoop()
        
        // --- 核心时间轴 ---
        
        // 第1击：立即开始
        performHit(in: effectiveSize)
        
        // 第2击：5.5秒后
        DispatchQueue.main.asyncAfter(deadline: .now() + timeBetweenHits) { [weak self] in
            // 检查 isActive 确保没有被强制停止
            guard let self = self, self.isActive else { return }
            self.performHit(in: effectiveSize)
        }
        
        // 第3击：11秒后
        DispatchQueue.main.asyncAfter(deadline: .now() + timeBetweenHits * 2) { [weak self] in
            guard let self = self, self.isActive else { return }
            self.performHit(in: effectiveSize)
        }
        
        // 结束：18秒后 (等待第3击展示完毕)
        DispatchQueue.main.asyncAfter(deadline: .now() + 18.0) { [weak self] in
            // 只有当还在运行且没有被手动停止时才自动结束
            if let self = self, self.isActive {
                self.stopCracks()
            }
        }
    }
    
    /// 兼容手动点击
    func triggerCrack(at tapPosition: CGPoint, screenSize: CGSize) {
        // 手动点击允许叠加，或者你可以选择在这里也加 isActive 判断
        if !isActive {
            resetState()
            isActive = true
            showCracks = true
            startAnimationLoop()
        }
        performHit(at: tapPosition, in: screenSize)
    }
    
    func reset() {
        stopCracks()
    }
    
    // 停止并清理裂纹效果
    func stopCracks() {
        // 如果已经停止，就不再重复执行
        if !isActive && !showCracks { return }
        
        print("💥 流程结束，清理所有效果")
        isActive = false
        // 不立即停止 Timer，让 fadeOut 动画跑完
        
        withAnimation(.easeOut(duration: 2.0)) {
            self.crackOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.resetState()
            self.showCracks = false
        }
    }
    
    // MARK: - Internal Logic
    
    private func performHit(in screenSize: CGSize) {
        let marginX = screenSize.width * 0.25
        let marginY = screenSize.height * 0.2
        let randomX = CGFloat.random(in: marginX...(screenSize.width - marginX))
        let randomY = CGFloat.random(in: marginY...(screenSize.height - marginY))
        let point = CGPoint(x: randomX, y: randomY)
        
        performHit(at: point, in: screenSize)
    }
    
    private func performHit(at point: CGPoint, in screenSize: CGSize) {
        hitCount += 1
        print("💥 执行第 \(hitCount) 次破碎")
        
        let impact = ImpactPoint(id: UUID(), position: point, startTime: Date())
        impactPoints.append(impact)
        
        generateSlowSpiderWeb(center: point, screenSize: screenSize)
        
        playGlassBreakSound()
        playGlassHaptic()
    }
    
    private func generateSlowSpiderWeb(center: CGPoint, screenSize: CGSize) {
        var newCracks: [CrackModel] = []
        let maxRadius = max(screenSize.width, screenSize.height) * 1.0
        
        // A. 放射状主裂纹
        let radialCount = Int.random(in: 7...12)
        var radialAngles: [Double] = []
        
        for _ in 0..<radialCount {
            let angle = Double.random(in: 0...360)
            radialAngles.append(angle)
            
            let length = maxRadius * CGFloat.random(in: 0.6...1.2)
            let endPoint = calculatePoint(from: center, angle: angle, distance: length)
            let pathPoints = generateJaggedLine(start: center, end: endPoint, jagAmount: 10)
            
            newCracks.append(CrackModel(
                points: pathPoints,
                width: CGFloat.random(in: 1.5...3.0),
                type: .radial,
                opacity: Double.random(in: 0.9...1.0),
                progress: 0.0,
                growthSpeed: Double.random(in: 0.01...0.02),
                startDelay: Double.random(in: 0.0...0.5)
            ))
        }
        
        radialAngles.sort()
        
        // B. 网状/横向裂纹
        let levels = Int.random(in: 5...9)
        
        for i in 0..<radialAngles.count {
            let currentAngle = radialAngles[i]
            let nextAngle = radialAngles[(i + 1) % radialAngles.count]
            
            var diff = nextAngle - currentAngle
            if diff < 0 { diff += 360 }
            
            if diff < 100 {
                for level in 0..<levels {
                    let distanceRatio = CGFloat(level + 1) / CGFloat(levels)
                    let baseDistance = maxRadius * 0.7 * distanceRatio
                    let distance = baseDistance + CGFloat.random(in: -30...30)
                    
                    let startP = calculatePoint(from: center, angle: currentAngle, distance: distance)
                    let endP = calculatePoint(from: center, angle: nextAngle, distance: distance * CGFloat.random(in: 0.95...1.05))
                    
                    if Double.random(in: 0...1) > 0.2 {
                        let pathPoints = generateJaggedLine(start: startP, end: endP, jagAmount: 5)
                        
                        let delayBase = Double(level) * 0.4
                        let delayRandom = Double.random(in: 0.0...1.5)
                        let totalDelay = min(4.0, delayBase + delayRandom + 0.5)
                        let speed = Double.random(in: 0.005...0.015)
                        
                        newCracks.append(CrackModel(
                            points: pathPoints,
                            width: CGFloat.random(in: 0.8...1.5),
                            type: .connective,
                            opacity: Double.random(in: 0.6...0.85),
                            progress: 0.0,
                            growthSpeed: speed,
                            startDelay: totalDelay
                        ))
                    }
                }
            }
        }
        self.cracks.append(contentsOf: newCracks)
    }
    
    private func startAnimationLoop() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateCrackGrowth()
        }
    }
    
    private func updateCrackGrowth() {
        guard !cracks.isEmpty else { return }
        var hasChanges = false
        
        for i in cracks.indices {
            if cracks[i].startDelay > 0 {
                cracks[i].startDelay -= 0.016
                if cracks[i].startDelay <= 0 { hasChanges = true }
                continue
            }
            if cracks[i].progress < 1.0 {
                cracks[i].progress += cracks[i].growthSpeed
                if cracks[i].progress > 1.0 { cracks[i].progress = 1.0 }
                hasChanges = true
            }
        }
        
        if hasChanges {
            objectWillChange.send()
        }
    }
    
    private func generateJaggedLine(start: CGPoint, end: CGPoint, jagAmount: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = [start]
        let distance = hypot(end.x - start.x, end.y - start.y)
        let segments = max(2, Int(distance / 25))
        
        let vector = CGPoint(x: (end.x - start.x) / CGFloat(segments), y: (end.y - start.y) / CGFloat(segments))
        
        for i in 1..<segments {
            let baseX = start.x + vector.x * CGFloat(i)
            let baseY = start.y + vector.y * CGFloat(i)
            let offsetX = CGFloat.random(in: -jagAmount...jagAmount)
            let offsetY = CGFloat.random(in: -jagAmount...jagAmount)
            points.append(CGPoint(x: baseX + offsetX, y: baseY + offsetY))
        }
        points.append(end)
        return points
    }
    
    private func calculatePoint(from center: CGPoint, angle: Double, distance: CGFloat) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(
            x: center.x + distance * cos(radians),
            y: center.y + distance * sin(radians)
        )
    }
    
    private func resetState() {
        impactPoints.removeAll()
        cracks.removeAll()
        crackOpacity = 0.0
        isActive = false
        hitCount = 0
        animationTimer?.invalidate()
    }
    
    // MARK: - Audio & Haptics
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch { print("Haptic Error: \(error)") }
    }
    
    private func playGlassBreakSound() {
        // 使用系统声音
        AudioServicesPlaySystemSound(1312)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
             AudioServicesPlaySystemSound(1108)
        }
    }
    
    private func playGlassHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred(intensity: 1.0)
            return
        }
        
        do {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let hit = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
            let crackle = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.1, duration: 0.6)
            
            let pattern = try CHHapticPattern(events: [hit, crackle], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch { }
    }
}

enum CrackType { case radial, connective }
struct CrackModel: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let width: CGFloat
    let type: CrackType
    let opacity: Double
    var progress: Double
    var growthSpeed: Double
    var startDelay: Double
}
struct ImpactPoint: Identifiable {
    let id: UUID
    let position: CGPoint
    let startTime: Date
}
