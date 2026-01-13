import SwiftUI
import Combine
import AVFoundation
import AudioToolbox
import CoreHaptics

class CrackManager: ObservableObject {
    static let shared = CrackManager()
    
    @Published var showCracks = false
    @Published var cracks: [Crack] = []
    @Published var crackOpacity: Double = 1.0
    @Published var crackSoundEnabled = true
    
    private var timer: Timer?
    private var crackGenerationTimer: Timer?
    private let crackDuration: TimeInterval = 30.0  // 30秒总时长
    private var startTime: Date?
    private var currentCrackCenterIndex = 0  // 当前正在生成的破裂中心点索引
    
    private var currentScreenSize: CGSize?
    private var crackCenters: [CGPoint] = []
    private var isCrackGenerationComplete = false
    private var isStopping = false
    private var isActive = false  // 新增：标记是否处于活动状态
    
    private init() {
        let defaults = UserDefaults.standard
        crackSoundEnabled = defaults.object(forKey: "crack_sound") as? Bool ?? true
        print("💥 CrackManager 初始化完成")
    }
    
    func triggerCrack(at position: CGPoint? = nil, screenSize: CGSize? = nil) {
        print("💥 ======== 开始触发玻璃破裂效果 ========")
        
        // 如果已经在运行，不要重新触发
        if isActive {
            print("💥 裂纹效果已经在运行中，跳过此次触发")
            return
        }
        
        guard let screenSizeToUse = screenSize else {
            print("💥 错误：没有提供屏幕尺寸")
            return
        }
        
        currentScreenSize = screenSizeToUse
        print("💥 使用的屏幕尺寸: \(screenSizeToUse)")
        
        // 重置状态
        resetState()
        isActive = true
        showCracks = true
        crackOpacity = 1.0
        startTime = Date()
        
        // 创建破裂中心点
        createCrackCenters(screenSize: screenSizeToUse)
        print("💥 破裂起始位置: 多中心点，数量: \(crackCenters.count)")
        
        // 确保音频会话已激活
        setupAudioSession()
        
        // 播放破裂音效
        if crackSoundEnabled {
            playCrackSound()
            print("💥 播放破裂音效")
        }
        
        // 播放强力触觉反馈
        playHeavyHaptic()
        print("💥 播放强力触觉反馈")
        
        // 立即生成第一个中心点的裂纹
        generateCrackFromCenter(index: 0)
        
        // 开始裂纹生成定时器
        startCrackGenerationTimer()
        
        // 开始裂纹扩展动画
        startCrackExpansion()
        print("💥 开始裂纹扩展定时器")
        
        // 30秒后停止效果
        DispatchQueue.main.asyncAfter(deadline: .now() + crackDuration) { [weak self] in
            Task { @MainActor in
                guard let self = self, self.isActive else { return }
                print("💥 30秒时间到，停止裂纹效果")
                self.stopCracks()
            }
        }
        
        print("💥 玻璃破裂效果已成功启动，将在30秒内缓慢生成")
    }
    
    private func resetState() {
        isStopping = false
        isCrackGenerationComplete = false
        cracks.removeAll()
        currentCrackCenterIndex = 0
        crackCenters.removeAll()
        timer?.invalidate()
        timer = nil
        crackGenerationTimer?.invalidate()
        crackGenerationTimer = nil
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("💥 CrackManager 音频会话设置失败: \(error)")
        }
    }
    
    private func createCrackCenters(screenSize: CGSize) {
        let centerCount = Int.random(in: 3...5)
        
        for i in 0..<centerCount {
            let x = CGFloat.random(in: screenSize.width * 0.2...screenSize.width * 0.8)
            let y: CGFloat
            
            let sectionHeight = screenSize.height / CGFloat(centerCount + 1)
            y = sectionHeight * CGFloat(i + 1) + CGFloat.random(in: -30...30)
            
            let center = CGPoint(x: x, y: y)
            crackCenters.append(center)
            print("💥 创建破裂中心点 \(i): \(center)")
        }
    }
    
    private func generateCrackFromCenter(index: Int) {
        guard index < crackCenters.count else {
            print("💥 索引超出范围: \(index)，中心点数量: \(crackCenters.count)")
            return
        }
        
        let center = crackCenters[index]
        print("💥 生成第 \(index+1) 个中心点的裂纹，位置: \(center)")
        
        let mainCrackCount = Int.random(in: 3...5)
        
        for i in 0..<mainCrackCount {
            let baseAngle = Double(i) * (360.0 / Double(mainCrackCount))
            let angle = baseAngle + Double.random(in: -30...30)
            
            let maxLength = max(currentScreenSize?.width ?? 400, currentScreenSize?.height ?? 800) * 0.5
            let length = CGFloat.random(in: maxLength * 0.4...maxLength * 0.7)
            
            let crack = Crack(
                id: UUID(),
                startPoint: center,
                endPoint: calculateEndpoint(from: center, angle: angle, length: length),
                thickness: CGFloat.random(in: 1.5...2.5),
                depth: 1,
                parentCrackId: nil,
                hasSubCracks: true,
                animationProgress: 0,
                growthSpeed: Double.random(in: 0.01...0.02)
            )
            
            cracks.append(crack)
        }
    }
    
    private func calculateEndpoint(from start: CGPoint, angle: Double, length: CGFloat) -> CGPoint {
        let radian = angle * Double.pi / 180
        return CGPoint(
            x: start.x + CGFloat(length * cos(radian)),
            y: start.y + CGFloat(length * sin(radian))
        )
    }
    
    private func startCrackGenerationTimer() {
        crackGenerationTimer?.invalidate()
        
        currentCrackCenterIndex = 1
        
        guard crackCenters.count > 1 else {
            print("💥 只有一个中心点，不需要生成定时器")
            isCrackGenerationComplete = true
            return
        }
        
        let nextInterval = Double.random(in: 4.0...7.0)
        print("💥 将在 \(String(format: "%.1f", nextInterval)) 秒后生成下一个中心点")
        
        crackGenerationTimer = Timer.scheduledTimer(withTimeInterval: nextInterval, repeats: false) { [weak self] timer in
            guard let self = self, self.isActive else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                self.generateNextCrackCenter(timer: timer)
            }
        }
    }
    
    private func generateNextCrackCenter(timer: Timer) {
        guard currentCrackCenterIndex < crackCenters.count else {
            print("💥 所有中心点裂纹已生成完成")
            timer.invalidate()
            crackGenerationTimer = nil
            isCrackGenerationComplete = true
            return
        }
        
        generateCrackFromCenter(index: currentCrackCenterIndex)
        playSubtleHaptic()
        
        currentCrackCenterIndex += 1
        
        if currentCrackCenterIndex < crackCenters.count {
            let nextInterval = Double.random(in: 4.0...7.0)
            print("💥 将在 \(String(format: "%.1f", nextInterval)) 秒后生成下一个中心点")
            
            crackGenerationTimer = Timer.scheduledTimer(withTimeInterval: nextInterval, repeats: false) { [weak self] nextTimer in
                guard let self = self, self.isActive else {
                    nextTimer.invalidate()
                    return
                }
                
                DispatchQueue.main.async {
                    self.generateNextCrackCenter(timer: nextTimer)
                }
            }
        } else {
            print("💥 所有中心点裂纹已生成完成")
            timer.invalidate()
            crackGenerationTimer = nil
            isCrackGenerationComplete = true
        }
    }
    
    private func playCrackSound() {
        print("🔊 播放玻璃破裂音效")
        
        // 先播放系统破裂声音
        AudioServicesPlaySystemSound(1105)
        
        // 主线程延迟播放更多音效
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AudioServicesPlaySystemSound(1304)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            AudioServicesPlaySystemSound(1108)
        }
    }
    
    private func playSubtleHaptic() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                try engine.start()
                
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
                
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
                
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                
            } catch {
                print("轻微触觉反馈播放失败: \(error)")
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        } else {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    private func playHeavyHaptic() {
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        heavyGenerator.prepare()
        heavyGenerator.impactOccurred()
        
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                try engine.start()
                
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                
                let events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)], relativeTime: 0.05),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)], relativeTime: 0.1)
                ]
                
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                
            } catch {
                print("触觉反馈播放失败: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
                    mediumGenerator.impactOccurred()
                }
            }
        }
    }
    
    private func startCrackExpansion() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                guard self.isActive, !self.isStopping else {
                    timer.invalidate()
                    return
                }
                
                self.expandExistingCracks()
                
                if Double.random(in: 0...1) < 0.15 {
                    self.generateBranchCracks()
                }
                
                if let startTime = self.startTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed > self.crackDuration - 5 {
                        self.crackOpacity = max(0, 1 - (elapsed - (self.crackDuration - 5)) / 5)
                    }
                }
            }
        }
    }
    
    private func expandExistingCracks() {
        for i in cracks.indices {
            if cracks[i].animationProgress < 1.0 {
                cracks[i].animationProgress = min(1.0, cracks[i].animationProgress + cracks[i].growthSpeed)
            }
        }
    }
    
    private func generateBranchCracks() {
        var newCracks: [Crack] = []
        
        for crack in cracks where crack.depth < 3 && crack.animationProgress >= 0.7 && crack.hasSubCracks {
            if Double.random(in: 0...1) < 0.2 {
                let branchCount = Int.random(in: 1...2)
                
                for _ in 0..<branchCount {
                    let randomProgress = CGFloat.random(in: 0.2...0.8)
                    let branchPoint = CGPoint(
                        x: crack.startPoint.x + (crack.endPoint.x - crack.startPoint.x) * randomProgress,
                        y: crack.startPoint.y + (crack.endPoint.y - crack.startPoint.y) * randomProgress
                    )
                    
                    let mainAngle = atan2(
                        crack.endPoint.y - crack.startPoint.y,
                        crack.endPoint.x - crack.startPoint.x
                    ) * 180 / Double.pi
                    
                    let branchAngle = mainAngle + Double.random(in: 20...70) * (Double.random(in: 0...1) > 0.5 ? 1 : -1)
                    let branchLength = CGFloat.random(in: 30...80) / CGFloat(crack.depth + 1)
                    
                    let branchCrack = Crack(
                        id: UUID(),
                        startPoint: branchPoint,
                        endPoint: calculateEndpoint(from: branchPoint, angle: branchAngle, length: branchLength),
                        thickness: crack.thickness * 0.6,
                        depth: crack.depth + 1,
                        parentCrackId: crack.id,
                        hasSubCracks: crack.depth < 2,
                        animationProgress: 0,
                        growthSpeed: crack.growthSpeed * 0.8
                    )
                    
                    newCracks.append(branchCrack)
                }
                
                if let index = cracks.firstIndex(where: { $0.id == crack.id }) {
                    cracks[index].hasSubCracks = false
                }
            }
        }
        
        cracks.append(contentsOf: newCracks)
    }
    
    func stopCracks() {
        guard isActive else { return }
        
        print("💥 停止玻璃破裂效果")
        isStopping = true
        
        timer?.invalidate()
        timer = nil
        
        crackGenerationTimer?.invalidate()
        crackGenerationTimer = nil
        
        withAnimation(.easeOut(duration: 1.0)) {
            crackOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.showCracks = false
                self.cracks.removeAll()
                self.crackCenters.removeAll()
                self.isStopping = false
                self.isCrackGenerationComplete = false
                self.isActive = false
                print("💥 玻璃破裂效果已完全清除")
            }
        }
    }
    
    func toggleSound() {
        crackSoundEnabled.toggle()
        UserDefaults.standard.set(crackSoundEnabled, forKey: "crack_sound")
        print("💥 裂痕音效已\(crackSoundEnabled ? "启用" : "禁用")")
    }
    
    deinit {
        timer?.invalidate()
        crackGenerationTimer?.invalidate()
    }
}

struct Crack: Identifiable {
    let id: UUID
    let startPoint: CGPoint
    let endPoint: CGPoint
    let thickness: CGFloat
    let depth: Int
    let parentCrackId: UUID?
    var hasSubCracks: Bool
    var animationProgress: Double
    var growthSpeed: Double
}
