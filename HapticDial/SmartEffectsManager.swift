// Core/SmartEffectsManager.swift - 新增智能效果管理器
import SwiftUI
import Combine
import CoreMotion

class SmartEffectsManager: ObservableObject {
    static let shared = SmartEffectsManager()
    
    @Published var isAdaptiveEnabled = true
    @Published var timeBasedEffects = true
    @Published var motionBasedEffects = true
    @Published var usageStatistics = UsageStatistics()
    
    private let motionManager = MotionManager()
    private let defaults = UserDefaults.standard
    private var lastInteractionTime = Date()
    private var interactionCount = 0
    private var interactionPattern: [TimeInterval] = []
    private var cancellables = Set<AnyCancellable>()
    
    // 使用统计
    struct UsageStatistics: Codable { // 添加Codable协议
        var totalInteractions = 0
        var averageSpeed: TimeInterval = 0
        var favoriteTimeOfDay = ""
        var peakUsageHour = 0
        var sessions = 0
    }
    
    private init() {
        loadStatistics()
        setupMotionManager()
        startTimeAnalysis()
    }
    
    private func setupMotionManager() {
        if motionBasedEffects {
            motionManager.startMonitoring()
        }
    }
    
    private func startTimeAnalysis() {
        // 每小时分析一次使用模式
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.analyzeUsagePatterns()
            }
            .store(in: &cancellables)
    }
    
    func recordInteraction() {
        guard isAdaptiveEnabled else { return }
        
        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastInteractionTime)
        lastInteractionTime = now
        interactionCount += 1
        usageStatistics.totalInteractions += 1
        
        // 记录交互模式
        interactionPattern.append(timeSinceLast)
        if interactionPattern.count > 20 {
            interactionPattern.removeFirst()
        }
        
        // 分析并调整效果
        if interactionPattern.count >= 5 {
            analyzeAndAdjustEffects()
        }
        
        // 时间相关效果
        if timeBasedEffects {
            applyTimeBasedEffects(now)
        }
        
        // 运动相关效果
        if motionBasedEffects {
            applyMotionBasedEffects()
        }
        
        // 保存统计
        saveStatistics()
    }
    
    private func analyzeAndAdjustEffects() {
        guard interactionPattern.count >= 5 else { return }
        
        let avgInterval = interactionPattern.reduce(0, +) / Double(interactionPattern.count)
        let hapticManager = HapticManager.shared
        
        // 更新平均速度
        usageStatistics.averageSpeed = avgInterval
        
        // 根据交互速度调整效果
        if avgInterval < 0.15 {
            // 极速点击：使用轻微效果避免过载
            hapticManager.hapticIntensity = min(hapticManager.hapticIntensity, 0.4)
            hapticManager.setVolume(min(hapticManager.volume, 0.3))
        } else if avgInterval < 0.3 {
            // 快速点击：适中效果
            hapticManager.hapticIntensity = 0.6
            hapticManager.setVolume(0.5)
        } else if avgInterval < 0.8 {
            // 中等速度：标准效果
            hapticManager.hapticIntensity = 0.7
            hapticManager.setVolume(0.7)
        } else if avgInterval < 1.5 {
            // 慢速点击：增强效果
            hapticManager.hapticIntensity = 0.9
            hapticManager.setVolume(0.9)
        } else {
            // 非常慢：最强效果
            hapticManager.hapticIntensity = 1.0
            hapticManager.setVolume(1.0)
        }
        
        // 根据模式推荐触感
        recommendHapticPattern(avgInterval)
    }
    
    private func recommendHapticPattern(_ avgInterval: TimeInterval) {
        let hapticManager = HapticManager.shared
        
        if avgInterval < 0.2 {
            // 快速点击适合连击模式
            if hapticManager.customHapticMode != .doubleClick &&
               hapticManager.customHapticMode != .tripleClick {
                // 可以在此添加推荐提示
            }
        } else if avgInterval > 1.0 {
            // 慢速点击适合脉冲模式
            if hapticManager.customHapticMode != .risingPulse &&
               hapticManager.customHapticMode != .fallingPulse {
                // 可以在此添加推荐提示
            }
        }
    }
    
    private func applyTimeBasedEffects(_ currentTime: Date) {
        guard timeBasedEffects else { return }
        
        let calendar = Calendar.current
        let hapticManager = HapticManager.shared
        
        // 时间敏感调整
        let hour = calendar.component(.hour, from: currentTime)
        if hour >= 23 || hour <= 6 {
            // 夜间模式：减弱效果，使用柔和模式
            hapticManager.hapticIntensity = min(hapticManager.hapticIntensity, 0.4)
            hapticManager.setVolume(min(hapticManager.volume, 0.3))
            
            // 推荐夜间友好模式
            if hapticManager.customSoundMode != .silent &&
               hapticManager.customSoundMode != .natural {
                // 可以提示切换到静音或自然模式
            }
            
        } else if hour >= 7 && hour <= 10 {
            // 早晨模式：温和效果
            hapticManager.hapticIntensity = 0.5
            hapticManager.setVolume(0.4)
            
        } else if hour >= 12 && hour <= 14 {
            // 午间模式：标准效果
            hapticManager.hapticIntensity = 0.7
            hapticManager.setVolume(0.6)
            
        } else if hour >= 18 && hour <= 22 {
            // 晚间模式：增强效果
            hapticManager.hapticIntensity = 0.8
            hapticManager.setVolume(0.8)
        }
        
        // 确定最喜欢的时段
        determineFavoriteTimeOfDay(hour)
    }
    
    private func determineFavoriteTimeOfDay(_ hour: Int) {
        if hour >= 6 && hour <= 11 {
            usageStatistics.favoriteTimeOfDay = "Morning"
        } else if hour >= 12 && hour <= 17 {
            usageStatistics.favoriteTimeOfDay = "Afternoon"
        } else if hour >= 18 && hour <= 22 {
            usageStatistics.favoriteTimeOfDay = "Evening"
        } else {
            usageStatistics.favoriteTimeOfDay = "Night"
        }
    }
    
    private func applyMotionBasedEffects() {
        guard motionBasedEffects else { return }
        
        let motionData = motionManager.currentMotion
        let hapticManager = HapticManager.shared
        
        if motionData.isShaking {
            // 设备摇晃时：增强触感，使用振动模式
            hapticManager.hapticIntensity = min(1.0, hapticManager.hapticIntensity + 0.2)
            
            if hapticManager.customHapticMode != .wobble &&
               hapticManager.customHapticMode != .longVibration {
                // 推荐摇晃相关模式
            }
            
        } else if motionData.isMovingFast {
            // 设备快速移动时：减弱效果避免干扰
            hapticManager.hapticIntensity = max(0.3, hapticManager.hapticIntensity - 0.3)
            hapticManager.setVolume(max(0.2, hapticManager.volume - 0.3))
            
        } else if motionData.isStationary {
            // 设备静止时：可以增强效果
            hapticManager.hapticIntensity = min(1.0, hapticManager.hapticIntensity + 0.1)
            hapticManager.setVolume(min(1.0, hapticManager.volume + 0.1))
        }
    }
    
    private func analyzeUsagePatterns() {
        // 分析使用模式
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        // 增加会话计数
        if interactionCount > 0 {
            usageStatistics.sessions += 1
        }
        
        // 重置交互计数
        interactionCount = 0
        
        print("📊 Smart Effects Analysis:")
        print("   Total Interactions: \(usageStatistics.totalInteractions)")
        print("   Average Speed: \(String(format: "%.2f", usageStatistics.averageSpeed))s")
        print("   Favorite Time: \(usageStatistics.favoriteTimeOfDay)")
        print("   Peak Hour: \(usageStatistics.peakUsageHour):00")
        print("   Sessions: \(usageStatistics.sessions)")
    }
    
    private func loadStatistics() {
        if let data = defaults.data(forKey: "usage_statistics"),
           let stats = try? JSONDecoder().decode(UsageStatistics.self, from: data) {
            usageStatistics = stats
        }
    }
    
    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(usageStatistics) {
            defaults.set(data, forKey: "usage_statistics")
        }
    }
    
    func resetStatistics() {
        usageStatistics = UsageStatistics()
        interactionPattern = []
        interactionCount = 0
        saveStatistics()
    }
    
    func getUsageInsights() -> String {
        if usageStatistics.totalInteractions == 0 {
            return "No usage data yet"
        }
        
        var insights: [String] = []
        
        if usageStatistics.averageSpeed < 0.3 {
            insights.append("You're a fast tapper! ⚡")
        } else if usageStatistics.averageSpeed > 1.0 {
            insights.append("You prefer slow, deliberate taps 🧘")
        }
        
        if usageStatistics.favoriteTimeOfDay == "Night" {
            insights.append("Night owl detected 🦉")
        } else if usageStatistics.favoriteTimeOfDay == "Morning" {
            insights.append("Early bird! 🌅")
        }
        
        if usageStatistics.sessions > 10 {
            insights.append("Regular user! 👍")
        }
        
        return insights.isEmpty ? "Keep tapping to unlock insights!" : insights.joined(separator: "\n")
    }
}

// 运动管理器
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var currentMotion = MotionData()
    
    var isMonitoring: Bool {
        return motionManager.isDeviceMotionActive
    }
    
    struct MotionData {
        var acceleration = CMAcceleration()
        var rotationRate = CMRotationRate()
        var isShaking = false
        var isMovingFast = false
        var isStationary = true
    }
    
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.2 // 降低频率节省电量
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            let acceleration = motion.userAcceleration
            let rotation = motion.rotationRate
            
            self.currentMotion.acceleration = acceleration
            self.currentMotion.rotationRate = rotation
            
            // 检测摇晃
            let shakingThreshold = 1.5
            let isShaking = abs(rotation.x) > shakingThreshold ||
                           abs(rotation.y) > shakingThreshold ||
                           abs(rotation.z) > shakingThreshold
            
            // 检测快速移动
            let speedThreshold = 0.3
            let totalAcceleration = sqrt(pow(acceleration.x, 2) +
                                        pow(acceleration.y, 2) +
                                        pow(acceleration.z, 2))
            let isMovingFast = totalAcceleration > speedThreshold
            
            // 检测静止
            let stationaryThreshold = 0.05
            let isStationary = totalAcceleration < stationaryThreshold &&
                              abs(rotation.x) < 0.1 &&
                              abs(rotation.y) < 0.1 &&
                              abs(rotation.z) < 0.1
            
            self.currentMotion.isShaking = isShaking
            self.currentMotion.isMovingFast = isMovingFast
            self.currentMotion.isStationary = isStationary
        }
    }
    
    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
    }
}
