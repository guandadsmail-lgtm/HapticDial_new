// Core/CoinManager.swift
import SwiftUI
import Combine
import AVFoundation
import CoreHaptics

class CoinManager: ObservableObject {
    static let shared = CoinManager()
    
    @Published var showCoins = false
    @Published var coins: [Coin] = []
    @Published var coinOpacity: Double = 1.0
    @Published var coinSoundEnabled = true
    
    private var timer: Timer?
    private var coinGenerationTimer: Timer?
    private let coinDuration: TimeInterval = 12.0  // 12秒总时长
    private var startTime: Date?
    private var audioPlayer: AVAudioPlayer?
    
    // 屏幕尺寸（在触发时从 GeometryReader 获取）
    private var currentScreenSize: CGSize?
    
    // 金币类型定义
    private let coinTypes = [
        (color: Color(red: 1.0, green: 0.84, blue: 0.0), size: 25.0, value: 1),   // 金币
        (color: Color(red: 0.8, green: 0.8, blue: 0.8), size: 20.0, value: 5),    // 银币
        (color: Color(red: 0.8, green: 0.5, blue: 0.2), size: 22.0, value: 10)    // 铜币
    ]
    
    private init() {
        // 从UserDefaults加载设置
        let defaults = UserDefaults.standard
        coinSoundEnabled = defaults.object(forKey: "coin_sound") as? Bool ?? true
        
        // 预加载音效
        loadSound()
        print("💰 CoinManager 初始化完成")
    }
    
    func loadSound() {
        // 从主Bundle加载音效
        if let url = Bundle.main.url(forResource: "many_coins", withExtension: "caf") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                print("💰 加载金币音效成功")
            } catch {
                print("💰 加载金币音效失败: \(error)")
            }
        } else {
            print("💰 未找到 many_coins.caf 文件")
        }
    }
    
    func triggerCoinRain(screenSize: CGSize? = nil) {
        print("💰 ======== 开始触发金币雨效果 ========")
        
        // 使用传入的屏幕尺寸
        guard let screenSizeToUse = screenSize else {
            print("💰 错误：没有提供屏幕尺寸")
            return
        }
        
        currentScreenSize = screenSizeToUse
        
        print("💰 使用的屏幕尺寸: \(screenSizeToUse)")
        print("💰 当前状态: showCoins=\(showCoins)")
        
        guard !showCoins else {
            print("💰 金币雨效果已经在显示中，跳过")
            return
        }
        
        // 重置状态
        showCoins = true
        coinOpacity = 1.0
        coins.removeAll()
        
        // 记录开始时间
        startTime = Date()
        
        print("💰 金币雨开始，将生成15秒金币")
        
        // 播放金币音效
        if coinSoundEnabled {
            playCoinSound()
            print("💰 播放金币音效")
        }
        
        // 播放触觉反馈
        playCoinHaptic()
        print("💰 播放触觉反馈")
        
        // 立即开始生成第一波金币
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.generateCoinWave()
        }
        
        // 开始金币生成定时器（每隔0.3-0.8秒生成一波金币，加快生成频率）
        startCoinGenerationTimer()
        
        // 开始金币动画定时器
        startCoinAnimationTimer()
        
        // 15秒后停止效果
        DispatchQueue.main.asyncAfter(deadline: .now() + coinDuration) { [weak self] in
            Task { @MainActor in
                print("💰 15秒时间到，停止金币雨效果")
                self?.stopCoins()
            }
        }
        
        print("💰 金币雨效果已成功启动")
    }
    
    private func generateCoinWave() {
        guard let screenSize = currentScreenSize else { return }
        
        // 每波生成8-15个金币（减少数量，让效果更有序）
        let coinCount = Int.random(in: 8...15)
        
        for _ in 0..<coinCount {
            let coinType = coinTypes.randomElement() ?? coinTypes[0]
            
            // 随机起始位置（屏幕顶部上方，水平位置随机）
            let startX = CGFloat.random(in: 20...(screenSize.width - 20)) // 避免太靠近屏幕边缘
            let startY = CGFloat.random(in: -100...0)
            
            // 随机旋转速度（减慢）
            let rotationSpeed = Double.random(in: 0.8...1.5) * (Bool.random() ? 1 : -1)
            
            // 移除水平漂移，让金币垂直下落
            let horizontalDrift: CGFloat = 0
            
            // 随机下落速度（稍微加速，让金币雨更密集）
            let fallSpeed = CGFloat.random(in: 4.0...7.0)
            
            // 添加垂直加速度，模拟重力效果
            let verticalAcceleration = CGFloat.random(in: 0.05...0.15)
            
            // 添加轻微的水平摆动（正弦波效果）
            let wobbleSpeed = Double.random(in: 0.5...1.5)
            let wobbleAmount = CGFloat.random(in: 0.5...1.5)
            
            let coin = Coin(
                id: UUID(),
                position: CGPoint(x: startX, y: startY),
                size: coinType.size,
                color: coinType.color,
                value: coinType.value,
                rotation: 0,
                rotationSpeed: rotationSpeed,
                horizontalDrift: horizontalDrift,
                fallSpeed: fallSpeed,
                verticalAcceleration: verticalAcceleration,
                opacity: 1.0,
                wobble: 0,
                wobbleSpeed: wobbleSpeed,
                wobbleAmount: wobbleAmount
            )
            
            coins.append(coin)
        }
    }
    
    private func startCoinGenerationTimer() {
        coinGenerationTimer?.invalidate()
        
        // 每隔0.3-0.8秒生成一波金币（加快频率）
        let interval = Double.random(in: 0.3...0.8)
        
        coinGenerationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 在主线程执行
            DispatchQueue.main.async {
                self.generateCoinWave()
                
                // 偶尔播放轻微的金币碰撞音效
                if self.coinSoundEnabled && Double.random(in: 0...1) < 0.15 {
                    self.playCoinDropSound()
                }
            }
        }
    }
    
    private func playCoinSound() {
        // 播放主要金币音效
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
    
    private func playCoinDropSound() {
        // 播放单个金币掉落的音效（可以使用系统音效）
        AudioServicesPlaySystemSound(1103) // 硬币掉落声
    }
    
    private func playCoinHaptic() {
        // 播放轻微的触觉反馈
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                try engine.start()
                
                // 创建连续的金币碰撞感
                let events = [
                    CHHapticEvent(eventType: .hapticTransient,
                                 parameters: [
                                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                                 ],
                                 relativeTime: 0),
                    CHHapticEvent(eventType: .hapticTransient,
                                 parameters: [
                                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                                 ],
                                 relativeTime: 0.05),
                    CHHapticEvent(eventType: .hapticTransient,
                                 parameters: [
                                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                                 ],
                                 relativeTime: 0.1)
                ]
                
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                
            } catch {
                print("金币触觉反馈播放失败: \(error)")
            }
        }
    }
    
    private func startCoinAnimationTimer() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // 在主线程执行
            DispatchQueue.main.async {
                self.updateCoins()
                
                // 逐渐淡出（最后3秒开始）
                if let startTime = self.startTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed > self.coinDuration - 3 {
                        self.coinOpacity = max(0, 1 - (elapsed - (self.coinDuration - 3)) / 3)
                    }
                }
            }
        }
    }
    
    private func updateCoins() {
        guard let screenSize = currentScreenSize else { return }
        
        for i in coins.indices {
            var coin = coins[i]
            
            // 垂直下落，增加加速度效果
            let currentFallSpeed = coin.fallSpeed + coin.verticalAcceleration
            
            // 更新位置（垂直下落）
            coin.position.y += currentFallSpeed
            
            // 添加轻微的水平摆动（正弦波效果）
            coin.wobble += coin.wobbleSpeed
            let wobbleOffset = sin(coin.wobble) * Double(coin.wobbleAmount) // 修正：转换为Double
            coin.position.x += CGFloat(wobbleOffset)
            
            // 更新旋转
            coin.rotation += coin.rotationSpeed
            
            // 当金币掉落到屏幕底部时，重置到顶部
            if coin.position.y > screenSize.height + 100 {
                // 重置位置
                coin.position.y = CGFloat.random(in: -100...0)
                coin.position.x = CGFloat.random(in: 20...(screenSize.width - 20))
                
                // 重置物理属性
                coin.fallSpeed = CGFloat.random(in: 4.0...7.0)
                coin.wobbleAmount = CGFloat.random(in: 0.5...1.5)
                coin.opacity = 1.0
            }
            
            // 确保金币不会超出屏幕两侧
            if coin.position.x < 0 {
                coin.position.x = 0
            } else if coin.position.x > screenSize.width {
                coin.position.x = screenSize.width
            }
            
            // 更新金币
            coins[i] = coin
        }
    }
    
    func stopCoins() {
        print("💰 停止金币雨效果")
        
        timer?.invalidate()
        timer = nil
        
        coinGenerationTimer?.invalidate()
        coinGenerationTimer = nil
        
        withAnimation(.easeOut(duration: 1.0)) {
            coinOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.showCoins = false
                self.coins.removeAll()
            }
        }
    }
    
    func toggleSound() {
        coinSoundEnabled.toggle()
        UserDefaults.standard.set(coinSoundEnabled, forKey: "coin_sound")
    }
    
    deinit {
        timer?.invalidate()
        coinGenerationTimer?.invalidate()
    }
}

// 金币数据模型（修改：让某些属性可变）
struct Coin: Identifiable {
    let id: UUID
    var position: CGPoint
    let size: CGFloat
    let color: Color
    let value: Int
    var rotation: Double
    let rotationSpeed: Double
    let horizontalDrift: CGFloat
    var fallSpeed: CGFloat  // 改为var，因为我们要更新它
    let verticalAcceleration: CGFloat
    var opacity: Double
    var wobble: Double
    let wobbleSpeed: Double
    var wobbleAmount: CGFloat  // 改为var，因为我们要更新它
}
