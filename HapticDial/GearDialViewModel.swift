// ViewModels/GearDialViewModel.swift - 完整修复版
import SwiftUI
import Combine
import AudioToolbox
import AVFoundation

class GearDialViewModel: ObservableObject {
    @Published var spinCount: Int = 0
    @Published var isSpinning = false
    @Published var rotationAngle: Double = 0.0
    @Published var spinSpeed: Double = 0.0
    @Published var lastSpinTime = Date()
    @Published var spinStreak = 0
    @Published var maxSpinSpeed: Double = 0.0
    
    private var lastEffectCount = 0
    private var spinTimes: [Date] = []
    private var spinAngles: [Double] = []
    private var cancellables = Set<AnyCancellable>()
    
    // 智能效果管理器引用
    private let smartEffectsManager = SmartEffectsManager.shared
    private let hapticManager = HapticManager.shared
    private let unifiedSoundManager = UnifiedSoundManager.shared // 添加统一音效管理器
    
    // 连击奖励
    private let streakThreshold = 5
    private let speedThreshold: TimeInterval = 0.5 // 500ms内旋转算快速连击
    
    // 统计
    private var totalSpins = 0
    private var totalRotation: Double = 0.0
    private var sessionStartTime = Date()
    
    // 系统声音ID
    private let systemClickSoundID: SystemSoundID = 1104  // 轻微点击声
    private let systemTickSoundID: SystemSoundID = 1103  // 更柔和的点击声
    private let systemPopSoundID: SystemSoundID = 1105   // 轻微破裂声
    private let systemWaterSoundID: SystemSoundID = 1005 // 水滴声
    private let systemWoodSoundID: SystemSoundID = 1100  // 木击声
    private let systemLaserSoundID: SystemSoundID = 4095 // 激光声
    private let systemSynthSoundID: SystemSoundID = 4094 // 合成器声
    private let systemEnergySoundID: SystemSoundID = 4097 // 能量声
    private let digitalClickSoundID: SystemSoundID = 1057 // 数字点击声
    private let digitalTickSoundID: SystemSoundID = 1053 // 数字滴答声
    private let digitalPopSoundID: SystemSoundID = 1055  // 数字弹出声
    
    init() {
        loadSavedData()
        setupObservers()
        print("⚙️ GearDialViewModel 初始化完成")
    }
    
    private func setupObservers() {
        // 监听应用状态变化
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveCurrentState()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveCurrentState()
        }
        
        // 监听设置变化
        hapticManager.$isEnabled
            .sink { [weak self] _ in
                // 触感启用状态变化时处理
                print("🎵 齿轮触感状态已更新")
            }
            .store(in: &cancellables)
    }
    
    func spinGear() {
        guard !isSpinning else { return }
        
        let now = Date()
        let timeSinceLastSpin = now.timeIntervalSince(lastSpinTime)
        
        isSpinning = true
        spinCount += 1
        totalSpins += 1
        
        // 更新统计
        spinTimes.append(now)
        spinAngles.append(rotationAngle)
        
        // 保持最近50次旋转记录
        if spinTimes.count > 50 {
            spinTimes.removeFirst()
            spinAngles.removeFirst()
        }
        
        // 计算旋转速度
        spinSpeed = calculateSpinSpeed(timeSinceLastSpin)
        if spinSpeed > maxSpinSpeed {
            maxSpinSpeed = spinSpeed
        }
        
        // 更新连击
        if timeSinceLastSpin < speedThreshold {
            spinStreak += 1
        } else {
            spinStreak = 1
        }
        
        lastSpinTime = now
        
        // 记录智能效果交互
        smartEffectsManager.recordInteraction()
        
        // 检查连击奖励
        checkStreakReward()
        
        // 检查是否需要触发特殊效果
        checkForEffect()
        
        // 根据旋转速度调整触感强度
        let hapticVelocity = calculateHapticVelocity(timeSinceLastSpin)
        
        // 主触感反馈
        hapticManager.playClick(velocity: hapticVelocity)
        
        // 播放声音（如果启用）- 使用统一音效管理器
        playSpinSound(forSpeed: timeSinceLastSpin)
        
        // 旋转动画
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            rotationAngle += 360
            totalRotation += 360
        }
        
        // 多段触感反馈模拟齿轮旋转
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.hapticManager.playClick(velocity: hapticVelocity * 0.7)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.hapticManager.playClick(velocity: hapticVelocity * 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.hapticManager.playClick(velocity: hapticVelocity * 0.3)
        }
        
        // 旋转完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isSpinning = false
        }
        
        // 自动保存（每10次旋转）
        if spinCount % 10 == 0 {
            saveCurrentState()
        }
    }
    
    func resetCount() {
        // 保存最终统计
        saveSessionStats()
        
        // 重置计数器
        spinCount = 0
        rotationAngle = 0.0
        lastEffectCount = 0
        spinStreak = 0
        maxSpinSpeed = 0.0
        spinTimes.removeAll()
        spinAngles.removeAll()
        totalRotation = 0.0
        
        // 播放重置触感
        hapticManager.playCustomPattern(.doubleClick)
        
        // 播放重置声音（如果启用）- 使用统一音效管理器
        if unifiedSoundManager.isSoundEnabled() {
            AudioServicesPlaySystemSound(systemPopSoundID)
        }
        
        // 记录重置操作
        print("🔄 齿轮计数器已重置")
    }
    
    private func checkForEffect() {
        // 当达到100或100的倍数时触发效果
        if spinCount >= 100 && spinCount % 100 == 0 && spinCount > lastEffectCount {
            lastEffectCount = spinCount
            
            // 获取屏幕尺寸以传递
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let screenSize = window.frame.size
                
                // 使用全局效果管理器触发效果
                EffectManager.shared.triggerEffect(screenSize: screenSize)
            } else {
                // 备用方案
                EffectManager.shared.triggerEffect()
            }
            
            // 播放庆祝触感
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.hapticManager.playCustomPattern(.risingPulse)
            }
            
            // 播放庆祝声音
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.playCelebrationSound()
            }
            
            // 记录成就
            recordAchievement(milestone: spinCount)
        }
    }
    
    private func checkStreakReward() {
        // 检查连击成就
        if spinStreak >= streakThreshold && spinStreak % 3 == 0 {
            // 连击成就触发
            triggerStreakReward()
        }
        
        // 特别连击成就
        if spinStreak == 10 {
            triggerSpecialStreakAchievement()
        }
    }
    
    private func triggerStreakReward() {
        print("⚙️ 齿轮连击成就: \(spinStreak) 次连续旋转!")
        
        // 增强触感反馈
        let pattern: HapticManager.HapticPattern = spinStreak >= 8 ? .tripleClick : .doubleClick
        hapticManager.playCustomPattern(pattern)
        
        // 如果启用了声音，播放连击音效
        if unifiedSoundManager.isSoundEnabled() {
            playStreakSound()
        }
        
        // 视觉反馈 - 额外旋转
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.rotationAngle += 45
                self.totalRotation += 45
            }
        }
    }
    
    private func triggerSpecialStreakAchievement() {
        print("🏆 齿轮特别成就: 10次连续旋转!")
        
        // 播放特殊触感序列
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
            self.hapticManager.playCustomPattern(.risingPulse)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.hapticManager.playCustomPattern(.fallingPulse)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.hapticManager.playCustomPattern(.wobble)
        }
        
        // 播放特别成就声音
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.playSpecialAchievementSound()
        }
        
        // 额外旋转奖励
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                self.rotationAngle += 90
                self.totalRotation += 90
            }
        }
    }
    
    private func calculateSpinSpeed(_ timeSinceLastSpin: TimeInterval) -> Double {
        // 根据时间计算旋转速度（度/秒）
        if timeSinceLastSpin > 0 {
            return 360.0 / timeSinceLastSpin
        }
        return 0.0
    }
    
    private func calculateHapticVelocity(_ timeSinceLastSpin: TimeInterval) -> Double {
        // 根据旋转速度计算触感强度
        let speed = calculateSpinSpeed(timeSinceLastSpin)
        
        if speed > 2000 {
            return 1.2 // 超快速旋转 - 增强触感
        } else if speed > 1000 {
            return 1.0 // 快速旋转 - 标准触感
        } else if speed > 500 {
            return 0.8 // 中等速度 - 稍弱触感
        } else if speed > 200 {
            return 0.6 // 慢速旋转 - 较弱触感
        } else {
            return 0.4 // 非常慢 - 轻微触感
        }
    }
    
    private func playSpinSound(forSpeed timeSinceLastSpin: TimeInterval) {
        // 使用统一音效管理器播放声音
        guard unifiedSoundManager.isSoundEnabled() else { return }
        
        // 直接播放选中的音效
        if let selectedSound = unifiedSoundManager.selectedSound {
            unifiedSoundManager.playSound(selectedSound)
        }
    }
    
    private func playStreakSound() {
        guard unifiedSoundManager.isSoundEnabled() else { return }
        
        // 播放连击声音
        if let selectedSound = unifiedSoundManager.selectedSound {
            unifiedSoundManager.playSound(selectedSound)
        }
    }
    
    private func playCelebrationSound() {
        guard unifiedSoundManager.isSoundEnabled() else { return }
        
        // 播放庆祝声音
        if let selectedSound = unifiedSoundManager.selectedSound {
            unifiedSoundManager.playSound(selectedSound)
        }
    }
    
    private func playSpecialAchievementSound() {
        guard unifiedSoundManager.isSoundEnabled() else { return }
        
        // 播放成就庆祝声音序列
        if let selectedSound = unifiedSoundManager.selectedSound {
            unifiedSoundManager.playSound(selectedSound)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.unifiedSoundManager.playSound(selectedSound)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.unifiedSoundManager.playSound(selectedSound)
            }
        }
    }
    
    private func recordAchievement(milestone: Int) {
        // 记录成就
        let defaults = UserDefaults.standard
        var achievements = defaults.array(forKey: "gear_achievements") as? [Int] ?? []
        
        if !achievements.contains(milestone) {
            achievements.append(milestone)
            defaults.set(achievements, forKey: "gear_achievements")
            
            print("🏅 齿轮成就解锁: \(milestone) 次旋转")
            
            // 如果是特殊里程碑，播放特殊效果
            if milestone == 100 || milestone == 500 || milestone == 1000 {
                playMilestoneCelebration(milestone: milestone)
            }
        }
    }
    
    private func playMilestoneCelebration(milestone: Int) {
        // 里程碑庆祝
        print("🎉 齿轮里程碑达成: \(milestone) 次旋转!")
        
        // 播放庆祝触感序列
        let patterns: [HapticManager.HapticPattern] = [.risingPulse, .fallingPulse, .wobble]
        
        for (index, pattern) in patterns.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                self.hapticManager.playCustomPattern(pattern)
            }
        }
        
        // 额外旋转庆祝
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.rotationAngle += 180
                self.totalRotation += 180
            }
        }
        
        // 播放庆祝声音
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playCelebrationSound()
        }
    }
    
    // MARK: - 数据持久化
    
    private func loadSavedData() {
        let defaults = UserDefaults.standard
        
        // 加载旋转计数
        spinCount = defaults.integer(forKey: "gear_spin_count")
        
        // 加载总旋转数
        totalSpins = defaults.integer(forKey: "gear_total_spins")
        
        // 加载总旋转角度
        totalRotation = defaults.double(forKey: "gear_total_rotation")
        
        // 加载最大连击
        spinStreak = defaults.integer(forKey: "gear_max_streak")
        
        print("📊 加载齿轮数据: \(spinCount) 次旋转, 总旋转: \(totalSpins), 总角度: \(totalRotation)°, 最大连击: \(spinStreak)")
    }
    
    private func saveCurrentState() {
        let defaults = UserDefaults.standard
        
        // 保存当前计数
        defaults.set(spinCount, forKey: "gear_spin_count")
        
        // 保存总旋转数
        defaults.set(totalSpins, forKey: "gear_total_spins")
        
        // 保存总旋转角度
        defaults.set(totalRotation, forKey: "gear_total_rotation")
        
        // 保存最大连击
        let currentMaxStreak = defaults.integer(forKey: "gear_max_streak")
        if spinStreak > currentMaxStreak {
            defaults.set(spinStreak, forKey: "gear_max_streak")
        }
        
        // 保存最大速度
        let currentMaxSpeed = defaults.double(forKey: "gear_max_speed")
        if maxSpinSpeed > currentMaxSpeed {
            defaults.set(maxSpinSpeed, forKey: "gear_max_speed")
        }
        
        // 保存会话统计
        saveSessionStats()
        
        defaults.synchronize()
        
        print("💾 齿轮数据已保存: \(spinCount) 次旋转, 总角度: \(totalRotation)°")
    }
    
    private func saveSessionStats() {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        let spinsPerMinute = totalSpins > 0 ? Double(totalSpins) / (sessionDuration / 60) : 0
        
        let defaults = UserDefaults.standard
        
        // 保存会话统计
        var sessionStats = defaults.array(forKey: "gear_session_stats") as? [[String: Any]] ?? []
        
        let newSession = [
            "date": Date(),
            "duration": sessionDuration,
            "spins": totalSpins,
            "spins_per_minute": spinsPerMinute,
            "total_rotation": totalRotation,
            "max_streak": spinStreak,
            "max_speed": maxSpinSpeed
        ] as [String : Any]
        
        sessionStats.append(newSession)
        
        // 只保留最近50个会话
        if sessionStats.count > 50 {
            sessionStats.removeFirst()
        }
        
        defaults.set(sessionStats, forKey: "gear_session_stats")
        
        print("📈 齿轮会话统计: \(Int(spinsPerMinute)) 次/分钟, 总旋转角度: \(Int(totalRotation))°, 最大连击: \(spinStreak)")
        
        // 重置会话开始时间
        sessionStartTime = Date()
    }
    
    // MARK: - 统计获取
    
    func getStatistics() -> [String: Any] {
        let defaults = UserDefaults.standard
        
        let totalSpins = defaults.integer(forKey: "gear_total_spins")
        let totalRotation = defaults.double(forKey: "gear_total_rotation")
        let maxStreak = defaults.integer(forKey: "gear_max_streak")
        let maxSpeed = defaults.double(forKey: "gear_max_speed")
        let sessionStats = defaults.array(forKey: "gear_session_stats") as? [[String: Any]] ?? []
        
        // 计算平均旋转速度
        let averageSpeed: Double = spinTimes.count > 1 ?
            spinAngles.last! / (spinTimes.last!.timeIntervalSince(spinTimes.first!)) : 0
        
        return [
            "current_count": spinCount,
            "total_spins": totalSpins,
            "total_rotation": totalRotation,
            "max_streak": maxStreak,
            "current_streak": spinStreak,
            "max_speed": maxSpeed,
            "current_speed": spinSpeed,
            "average_speed": averageSpeed,
            "rotation_angle": rotationAngle,
            "session_count": sessionStats.count,
            "last_session_date": sessionStats.last?["date"] as? Date ?? Date()
        ]
    }
    
    func getAchievements() -> [Int] {
        let defaults = UserDefaults.standard
        return defaults.array(forKey: "gear_achievements") as? [Int] ?? []
    }
    
    func getSessionHistory() -> [[String: Any]] {
        let defaults = UserDefaults.standard
        return defaults.array(forKey: "gear_session_stats") as? [[String: Any]] ?? []
    }
    
    // MARK: - 辅助方法
    
    func getRotationInRevolutions() -> Double {
        return totalRotation / 360.0
    }
    
    func getAverageSpinInterval() -> TimeInterval {
        guard spinTimes.count > 1 else { return 0 }
        
        let totalTime = spinTimes.last!.timeIntervalSince(spinTimes.first!)
        return totalTime / Double(spinTimes.count - 1)
    }
    
    deinit {
        // 清理观察者
        NotificationCenter.default.removeObserver(self)
        
        // 保存最终状态
        saveCurrentState()
        
        print("🧹 GearDialViewModel 清理完成")
    }
}
