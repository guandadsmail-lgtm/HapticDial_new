// Core/CrackManager.swift
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
    
    // 移除原有的 screenSize，改为在触发时从 GeometryReader 获取
    private var currentScreenSize: CGSize?
    
    // 裂纹中心点数组
    private var crackCenters: [CGPoint] = []
    
    private init() {
        // 从UserDefaults加载设置
        let defaults = UserDefaults.standard
        crackSoundEnabled = defaults.object(forKey: "crack_sound") as? Bool ?? true
        print("💥 CrackManager 初始化完成")
    }
    
    func triggerCrack(at position: CGPoint? = nil, screenSize: CGSize? = nil) {
        print("💥 ======== 开始触发玻璃破裂效果 ========")
        
        // 使用传入的屏幕尺寸
        guard let screenSizeToUse = screenSize else {
            print("💥 错误：没有提供屏幕尺寸")
            return
        }
        
        currentScreenSize = screenSizeToUse
        
        print("💥 使用的屏幕尺寸: \(screenSizeToUse)")
        print("💥 当前位置状态: showCracks=\(showCracks)")
        
        guard !showCracks else {
            print("💥 裂纹效果已经在显示中，跳过")
            return
        }
        
        // 重置状态
        showCracks = true
        crackOpacity = 1.0
        cracks.removeAll()
        currentCrackCenterIndex = 0
        
        // 创建破裂中心点
        createCrackCenters(screenSize: screenSizeToUse)
        
        // 记录开始时间
        startTime = Date()
        
        print("💥 破裂起始位置: 多中心点，数量: \(crackCenters.count)")
        
        // 播放破裂音效
        if crackSoundEnabled {
            playCrackSound()
            print("💥 播放破裂音效")
        }
        
        // 播放强力触觉反馈
        playHeavyHaptic()
        print("💥 播放强力触觉反馈")
        
        // 开始生成第一个裂纹（第一个中心点）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.generateCrackFromCenter(index: 0)
        }
        
        // 开始裂纹生成定时器（每隔4-7秒生成一个中心点的裂纹）
        startCrackGenerationTimer()
        
        // 开始裂纹扩展动画
        startCrackExpansion()
        print("💥 开始裂纹扩展定时器")
        
        // 30秒后停止效果
        DispatchQueue.main.asyncAfter(deadline: .now() + crackDuration) {
            Task { @MainActor in
                print("💥 30秒时间到，停止裂纹效果")
                self.stopCracks()
            }
        }
        
        print("💥 玻璃破裂效果已成功启动，将在30秒内缓慢生成")
    }
    
    private func createCrackCenters(screenSize: CGSize) {
        // 创建3-5个破裂中心点（比原来少一些）
        let centerCount = Int.random(in: 3...5)
        crackCenters.removeAll()
        
        for i in 0..<centerCount {
            // 确保中心点不要太靠近边缘
            let x = CGFloat.random(in: screenSize.width * 0.2...screenSize.width * 0.8)
            let y: CGFloat
            
            // 按顺序从上到下分布中心点
            let sectionHeight = screenSize.height / CGFloat(centerCount + 1)
            y = sectionHeight * CGFloat(i + 1) + CGFloat.random(in: -30...30)
            
            let center = CGPoint(x: x, y: y)
            crackCenters.append(center)
            print("💥 创建破裂中心点 \(i): \(center)")
        }
    }
    
    private func generateCrackFromCenter(index: Int) {
        guard index < crackCenters.count else { return }
        
        let center = crackCenters[index]
        print("💥 生成第 \(index+1) 个中心点的裂纹，位置: \(center)")
        
        // 每个中心点生成3-5条主要裂纹（比原来少）
        let mainCrackCount = Int.random(in: 3...5)
        
        for i in 0..<mainCrackCount {
            // 基础角度加上随机偏移
            let baseAngle = Double(i) * (360.0 / Double(mainCrackCount))
            let angle = baseAngle + Double.random(in: -30...30)
            
            // 裂纹长度：延伸到屏幕边缘
            let maxLength = max(currentScreenSize?.width ?? 400, currentScreenSize?.height ?? 800) * 0.5
            let length = CGFloat.random(in: maxLength * 0.4...maxLength * 0.7)
            
            let crack = Crack(
                id: UUID(),
                startPoint: center,
                endPoint: calculateEndpoint(from: center, angle: angle, length: length),
                thickness: CGFloat.random(in: 1.5...2.5),  // 更细的裂纹
                depth: 1,
                parentCrackId: nil,
                hasSubCracks: true,
                animationProgress: 0,
                growthSpeed: Double.random(in: 0.01...0.02)  // 大幅降低生长速度
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
        
        // 每隔4-7秒生成下一个中心点的裂纹
        let interval = Double.random(in: 4.0...7.0)
        
        crackGenerationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                self.currentCrackCenterIndex += 1
                
                if self.currentCrackCenterIndex < self.crackCenters.count {
                    // 生成下一个中心点的裂纹
                    self.generateCrackFromCenter(index: self.currentCrackCenterIndex)
                    
                    // 播放轻微的触觉反馈
                    self.playSubtleHaptic()
                } else {
                    // 所有中心点都已生成，停止生成定时器
                    timer.invalidate()
                    self.crackGenerationTimer = nil
                    print("💥 所有中心点裂纹已生成完成")
                }
            }
        }
    }
    
    private func playCrackSound() {
        // 播放系统破裂声音
        AudioServicesPlaySystemSound(1105) // 轻微破裂声
    }
    
    private func playSubtleHaptic() {
        // 播放轻微的触觉反馈
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
            }
        }
    }
    
    private func playHeavyHaptic() {
        // 播放强力的触觉反馈
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                try engine.start()
                
                // 创建更强烈的触觉反馈
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                
                // 多个触觉事件模拟玻璃破裂
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
            
            Task { @MainActor in
                // 扩展现有裂纹
                self.expandExistingCracks()
                
                // 少量生成分支裂纹（减少频率）
                if Double.random(in: 0...1) < 0.15 {  // 从40%降低到15%
                    self.generateBranchCracks()
                }
                
                // 逐渐淡出（最后5秒开始）
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
            // 如果裂纹还没完全扩展
            if cracks[i].animationProgress < 1.0 {
                cracks[i].animationProgress = min(1.0, cracks[i].animationProgress + cracks[i].growthSpeed)
            }
        }
    }
    
    private func generateBranchCracks() {
        // 从现有的主要裂纹生成分支（大幅减少数量）
        var newCracks: [Crack] = []
        
        for crack in cracks where crack.depth < 3 && crack.animationProgress >= 0.7 && crack.hasSubCracks {
            // 降低生成分支的几率
            if Double.random(in: 0...1) < 0.2 {  // 从40%降低到20%
                let branchCount = Int.random(in: 1...2)  // 减少分支数量
                
                for _ in 0..<branchCount {
                    // 从裂纹的随机点生成分支
                    let randomProgress = CGFloat.random(in: 0.2...0.8)
                    let branchPoint = CGPoint(
                        x: crack.startPoint.x + (crack.endPoint.x - crack.startPoint.x) * randomProgress,
                        y: crack.startPoint.y + (crack.endPoint.y - crack.startPoint.y) * randomProgress
                    )
                    
                    // 计算主裂纹的角度
                    let mainAngle = atan2(
                        crack.endPoint.y - crack.startPoint.y,
                        crack.endPoint.x - crack.startPoint.x
                    ) * 180 / Double.pi
                    
                    // 分支角度在 ±20 到 ±70 度范围内
                    let branchAngle = mainAngle + Double.random(in: 20...70) * (Double.random(in: 0...1) > 0.5 ? 1 : -1)
                    let branchLength = CGFloat.random(in: 30...80) / CGFloat(crack.depth + 1)  // 缩短分支长度
                    
                    let branchCrack = Crack(
                        id: UUID(),
                        startPoint: branchPoint,
                        endPoint: calculateEndpoint(from: branchPoint, angle: branchAngle, length: branchLength),
                        thickness: crack.thickness * 0.6,  // 分支更细
                        depth: crack.depth + 1,
                        parentCrackId: crack.id,
                        hasSubCracks: crack.depth < 2,
                        animationProgress: 0,
                        growthSpeed: crack.growthSpeed * 0.8  // 分支生长更慢
                    )
                    
                    newCracks.append(branchCrack)
                }
                
                // 标记此裂纹已经生成了分支
                if let index = cracks.firstIndex(where: { $0.id == crack.id }) {
                    cracks[index].hasSubCracks = false
                }
            }
        }
        
        cracks.append(contentsOf: newCracks)
    }
    
    func stopCracks() {
        print("💥 停止玻璃破裂效果")
        
        timer?.invalidate()
        timer = nil
        
        crackGenerationTimer?.invalidate()
        crackGenerationTimer = nil
        
        withAnimation(.easeOut(duration: 1.0)) {
            crackOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task { @MainActor in
                self.showCracks = false
                self.cracks.removeAll()
                self.crackCenters.removeAll()
            }
        }
    }
    
    func toggleSound() {
        crackSoundEnabled.toggle()
        UserDefaults.standard.set(crackSoundEnabled, forKey: "crack_sound")
    }
    
    deinit {
        timer?.invalidate()
        crackGenerationTimer?.invalidate()
    }
}

// 裂纹数据模型
struct Crack: Identifiable {
    let id: UUID
    let startPoint: CGPoint
    let endPoint: CGPoint
    let thickness: CGFloat
    let depth: Int // 裂纹深度（层级）
    let parentCrackId: UUID? // 父裂纹ID，用于构建裂纹树
    var hasSubCracks: Bool // 是否还有未生成的分支
    var animationProgress: Double // 动画进度 0.0-1.0
    var growthSpeed: Double // 裂纹生长速度
}

