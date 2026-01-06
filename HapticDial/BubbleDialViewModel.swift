// ViewModels/BubbleDialViewModel.swift - 修复 Futuristic 模式声音问题
import SwiftUI
import Combine
import AudioToolbox
import AVFoundation

class BubbleDialViewModel: ObservableObject {
    @Published var tapCount: Int = 0
    @Published var bubbleOpacity: Double = 1.0
    @Published var isAnimating = false
    @Published var lastTapTime = Date()
    @Published var tapStreak = 0
    @Published var maxTapSpeed: TimeInterval = 0
    
    private var lastEffectCount = 0
    private var tapTimes: [Date] = []
    private var cancellables = Set<AnyCancellable>()
    
    // 智能效果管理器引用
    private let smartEffectsManager = SmartEffectsManager.shared
    private let hapticManager = HapticManager.shared
    
    // 连击奖励
    private let streakThreshold = 10
    private let speedThreshold: TimeInterval = 0.2 // 200ms内点击算快速连击
    
    // 统计
    private var totalTaps = 0
    private var sessionStartTime = Date()
    
    // 系统声音ID - 使用可靠的声音ID
    private let systemClickSoundID: SystemSoundID = 1104  // 轻微点击声
    private let systemTickSoundID: SystemSoundID = 1103  // 更柔和的点击声
    private let systemPopSoundID: SystemSoundID = 1105   // 轻微破裂声
    private let systemWaterSoundID: SystemSoundID = 1005 // 水滴声
    private let systemWoodSoundID: SystemSoundID = 1100  // 木击声
    
    // 修复：Futuristic 模式使用自定义音频播放器
    private var laserSoundPlayer: AVAudioPlayer?
    private var synthSoundPlayer: AVAudioPlayer?
    private var energySoundPlayer: AVAudioPlayer?
    private var digitalClickPlayer: AVAudioPlayer?
    private var digitalTickPlayer: AVAudioPlayer?
    private var digitalPopPlayer: AVAudioPlayer?
    
    init() {
        loadSavedData()
        setupObservers()
        setupCustomAudioPlayers() // 初始化自定义音频播放器
        print("🎯 BubbleDialViewModel 初始化完成")
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
        hapticManager.$customSoundMode
            .sink { [weak self] _ in
                // 声音模式变化时更新声音设置
                print("🎵 声音模式已更新")
            }
            .store(in: &cancellables)
    }
    
    private func setupCustomAudioPlayers() {
        // 尝试加载自定义音频文件
        setupFuturisticSounds()
        setupDigitalSounds()
    }
    
    private func setupFuturisticSounds() {
        // 尝试加载 Futuristic 模式的声音文件
        // 注意：需要在项目中添加这些音频文件，或者使用系统声音作为后备
        
        // 激光声音
        if let laserURL = Bundle.main.url(forResource: "laser", withExtension: "wav") {
            do {
                laserSoundPlayer = try AVAudioPlayer(contentsOf: laserURL)
                laserSoundPlayer?.prepareToPlay()
                print("✅ 激光声音加载成功")
            } catch {
                print("❌ 加载激光声音失败: \(error)")
                // 设置后备方案
                laserSoundPlayer = nil
            }
        } else {
            print("⚠️ 未找到激光声音文件，使用系统声音替代")
            laserSoundPlayer = nil
        }
        
        // 合成器声音
        if let synthURL = Bundle.main.url(forResource: "synth", withExtension: "wav") {
            do {
                synthSoundPlayer = try AVAudioPlayer(contentsOf: synthURL)
                synthSoundPlayer?.prepareToPlay()
                print("✅ 合成器声音加载成功")
            } catch {
                print("❌ 加载合成器声音失败: \(error)")
                synthSoundPlayer = nil
            }
        } else {
            print("⚠️ 未找到合成器声音文件，使用系统声音替代")
            synthSoundPlayer = nil
        }
        
        // 能量声音
        if let energyURL = Bundle.main.url(forResource: "energy", withExtension: "wav") {
            do {
                energySoundPlayer = try AVAudioPlayer(contentsOf: energyURL)
                energySoundPlayer?.prepareToPlay()
                print("✅ 能量声音加载成功")
            } catch {
                print("❌ 加载能量声音失败: \(error)")
                energySoundPlayer = nil
            }
        } else {
            print("⚠️ 未找到能量声音文件，使用系统声音替代")
            energySoundPlayer = nil
        }
    }
    private func setupDigitalSounds() {
        // 设置 Digital 模式的自定义声音（可选）
        // 可以在这里添加数字音效的自定义音频文件
    }
    
    func incrementCount() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        // 更新统计
        totalTaps += 1
        tapTimes.append(now)
        
        // 保持最近50次点击时间
        if tapTimes.count > 50 {
            tapTimes.removeFirst()
        }
        
        // 计算点击速度
        if timeSinceLastTap > 0 {
            let currentSpeed = timeSinceLastTap
            if currentSpeed < maxTapSpeed || maxTapSpeed == 0 {
                maxTapSpeed = currentSpeed
            }
        }
        
        // 更新连击
        if timeSinceLastTap < speedThreshold {
            tapStreak += 1
        } else {
            tapStreak = 1
        }
        
        lastTapTime = now
        
        // 主计数增加
        tapCount += 1
        bubbleOpacity = 0.7
        
        // 记录智能效果交互
        smartEffectsManager.recordInteraction()
        
        // 检查连击奖励
        checkStreakReward()
        
        // 检查是否需要触发特殊效果
        checkForEffect()
        
        // 根据点击速度调整触感强度
        let hapticVelocity = calculateHapticVelocity(timeSinceLastTap)
        
        // 播放触感反馈
        hapticManager.playClick(velocity: hapticVelocity)
        
        // 播放声音（如果启用）
        if hapticManager.customSoundMode != .silent {
            playTapSound(forSpeed: timeSinceLastTap)
        }
        
        // 添加动画效果
        triggerVisualFeedback()
        
        // 淡入动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                self.bubbleOpacity = 1.0
            }
        }
        
        // 自动保存（每10次点击）
        if tapCount % 10 == 0 {
            saveCurrentState()
        }
    }
    
    func resetCount() {
        // 保存最终统计
        saveSessionStats()
        
        // 重置计数器
        tapCount = 0
        lastEffectCount = 0
        tapStreak = 0
        maxTapSpeed = 0
        tapTimes.removeAll()
        
        // 播放重置触感
        hapticManager.playCustomPattern(.doubleClick)
        
        // 播放重置声音（如果启用）
        if hapticManager.customSoundMode != .silent {
            AudioServicesPlaySystemSound(systemPopSoundID)
        }
        
        // 记录重置操作
        print("🔄 气泡计数器已重置")
    }
    
    private func checkForEffect() {
        // 当达到100或100的倍数时触发效果
        if tapCount >= 100 && tapCount % 100 == 0 && tapCount > lastEffectCount {
            lastEffectCount = tapCount
            
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.hapticManager.playCustomPattern(.risingPulse)
            }
            
            // 播放庆祝声音
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                self.playCelebrationSound()
            }
            
            // 记录成就
            recordAchievement(milestone: tapCount)
        }
    }
    
    private func checkStreakReward() {
        // 检查连击成就
        if tapStreak >= streakThreshold && tapStreak % 5 == 0 {
            // 连击成就触发
            triggerStreakReward()
        }
        
        // 特别连击成就
        if tapStreak == 20 {
            triggerSpecialStreakAchievement()
        }
    }
    
    private func triggerStreakReward() {
        print("🔥 连击成就: \(tapStreak) 次连续点击!")
        
        // 增强触感反馈
        let pattern: HapticManager.HapticPattern = tapStreak >= 15 ? .tripleClick : .doubleClick
        hapticManager.playCustomPattern(pattern)
        
        // 如果启用了声音，播放连击音效
        if hapticManager.customSoundMode != .silent {
            playStreakSound()
        }
        
        // 视觉反馈
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.bubbleOpacity = 0.5
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    self.bubbleOpacity = 1.0
                }
            }
        }
    }
    
    private func triggerSpecialStreakAchievement() {
        print("🏆 特别成就: 20次连续点击!")
        
        // 播放特殊触感序列
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) { [weak self] in
            guard let self = self else { return }
            self.hapticManager.playCustomPattern(.risingPulse)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.hapticManager.playCustomPattern(.fallingPulse)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            self.hapticManager.playCustomPattern(.wobble)
        }
        
        // 播放特别成就声音
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.playSpecialAchievementSound()
        }
    }
    
    private func calculateHapticVelocity(_ timeSinceLastTap: TimeInterval) -> Double {
        // 根据点击速度计算触感强度
        if timeSinceLastTap < 0.05 {
            return 1.2 // 超快速点击 - 增强触感
        } else if timeSinceLastTap < 0.15 {
            return 1.0 // 快速点击 - 标准触感
        } else if timeSinceLastTap < 0.5 {
            return 0.8 // 中等速度 - 稍弱触感
        } else if timeSinceLastTap < 1.0 {
            return 0.6 // 慢速点击 - 较弱触感
        } else {
            return 0.4 // 非常慢 - 轻微触感
        }
    }
    
    private func playTapSound(forSpeed timeSinceLastTap: TimeInterval) {
        // 根据点击速度选择不同的声音
        let soundMode = hapticManager.customSoundMode
        
        switch soundMode {
        case .default:
            // 使用默认系统声音 - HapticManager会自动处理
            AudioServicesPlaySystemSound(systemClickSoundID)
            
        case .mechanical:
            if timeSinceLastTap < 0.1 {
                AudioServicesPlaySystemSound(systemTickSoundID)
            } else {
                AudioServicesPlaySystemSound(systemClickSoundID)
            }
            
        case .digital:
            // Digital 模式 - 使用干净的数字声音
            if timeSinceLastTap < 0.1 {
                // 尝试使用自定义数字音效
                digitalTickPlayer?.play()
                // 后备：使用系统声音
                AudioServicesPlaySystemSound(1053) // 数字滴答声
            } else {
                digitalClickPlayer?.play()
                AudioServicesPlaySystemSound(1057) // 数字点击声
            }
            
        case .natural:
            if tapCount % 3 == 0 {
                AudioServicesPlaySystemSound(systemWaterSoundID)
            } else if tapCount % 3 == 1 {
                AudioServicesPlaySystemSound(systemWoodSoundID)
            } else {
                AudioServicesPlaySystemSound(systemPopSoundID)
            }
            
        case .futuristic:
            // 修复：Futuristic 模式使用自定义音频或系统声音
            if timeSinceLastTap < 0.15 {
                // 快速点击：激光声音
                if let laserPlayer = laserSoundPlayer, laserPlayer.prepareToPlay() {
                    laserPlayer.currentTime = 0
                    laserPlayer.play()
                } else {
                    // 后备：使用高科技感的系统声音
                    AudioServicesPlaySystemSound(1030) // 钟声，类似科幻音效
                }
            } else {
                // 慢速点击：合成器声音
                if let synthPlayer = synthSoundPlayer, synthPlayer.prepareToPlay() {
                    synthPlayer.currentTime = 0
                    synthPlayer.play()
                } else {
                    // 后备：使用合成器感的系统声音
                    AudioServicesPlaySystemSound(1013) // 科幻感的声音
                }
            }
            
        case .silent:
            // Silent 模式：故意不播放任何声音
            break // 无声音
        }
    }
    
    private func playStreakSound() {
        let soundMode = hapticManager.customSoundMode
        
        switch soundMode {
        case .mechanical:
            AudioServicesPlaySystemSound(systemPopSoundID)
        case .digital:
            // 数字连击声音
            digitalPopPlayer?.play()
            AudioServicesPlaySystemSound(1055) // 数字弹出声
        case .natural:
            AudioServicesPlaySystemSound(systemPopSoundID)
        case .futuristic:
            // 未来感连击声音
            if let energyPlayer = energySoundPlayer, energyPlayer.prepareToPlay() {
                energyPlayer.currentTime = 0
                energyPlayer.play()
            } else {
                AudioServicesPlaySystemSound(1035) // 科幻感的声音
            }
        default:
            AudioServicesPlaySystemSound(systemPopSoundID)
        }
    }
    
    private func playCelebrationSound() {
        let soundMode = hapticManager.customSoundMode
        
        switch soundMode {
        case .default, .mechanical, .natural:
            AudioServicesPlaySystemSound(systemPopSoundID)
        case .digital:
            digitalPopPlayer?.play()
            AudioServicesPlaySystemSound(1055) // 数字庆祝声
        case .futuristic:
            // 未来感庆祝声音
            if let energyPlayer = energySoundPlayer, energyPlayer.prepareToPlay() {
                energyPlayer.currentTime = 0
                energyPlayer.volume = 1.0
                energyPlayer.play()
            } else {
                AudioServicesPlaySystemSound(1025) // 庆祝钟声
            }
        case .silent:
            break
        }
    }
    
    private func playSpecialAchievementSound() {
        let soundMode = hapticManager.customSoundMode
        
        // 播放成就庆祝声音序列
        switch soundMode {
        case .default, .mechanical:
            AudioServicesPlaySystemSound(systemClickSoundID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                AudioServicesPlaySystemSound(self.systemTickSoundID)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                AudioServicesPlaySystemSound(self.systemPopSoundID)
            }
            
        case .digital:
            AudioServicesPlaySystemSound(1057)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard self != nil else { return }
                AudioServicesPlaySystemSound(1053)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard self != nil else { return }
                AudioServicesPlaySystemSound(1055)
            }
            
        case .natural:
            AudioServicesPlaySystemSound(systemWaterSoundID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                AudioServicesPlaySystemSound(systemWoodSoundID)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                AudioServicesPlaySystemSound(systemPopSoundID)
            }
            
        case .futuristic:
            // 未来感成就声音序列
            if let laserPlayer = laserSoundPlayer, laserPlayer.prepareToPlay() {
                laserPlayer.currentTime = 0
                laserPlayer.volume = 0.8
                laserPlayer.play()
            } else {
                AudioServicesPlaySystemSound(1030)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                if let synthPlayer = self.synthSoundPlayer, synthPlayer.prepareToPlay() {
                    synthPlayer.currentTime = 0
                    synthPlayer.volume = 0.9
                    synthPlayer.play()
                } else {
                    AudioServicesPlaySystemSound(1013)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                if let energyPlayer = self.energySoundPlayer, energyPlayer.prepareToPlay() {
                    energyPlayer.currentTime = 0
                    energyPlayer.volume = 1.0
                    energyPlayer.play()
                } else {
                    AudioServicesPlaySystemSound(1025)
                }
            }
            
        case .silent:
            break
        }
    }
    
    private func triggerVisualFeedback() {
        // 触发视觉反馈动画
        isAnimating = true
        
        // 短暂的缩放动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.isAnimating = false
            }
        }
    }
    
    private func recordAchievement(milestone: Int) {
        // 记录成就
        let defaults = UserDefaults.standard
        var achievements = defaults.array(forKey: "bubble_achievements") as? [Int] ?? []
        
        if !achievements.contains(milestone) {
            achievements.append(milestone)
            defaults.set(achievements, forKey: "bubble_achievements")
            
            print("🏅 成就解锁: \(milestone) 次点击")
            
            // 如果是特殊里程碑，播放特殊效果
            if milestone == 100 || milestone == 500 || milestone == 1000 {
                playMilestoneCelebration(milestone: milestone)
            }
        }
    }
    
    private func playMilestoneCelebration(milestone: Int) {
        // 里程碑庆祝
        print("🎉 里程碑达成: \(milestone) 次点击!")
        
        // 播放庆祝触感序列
        let patterns: [HapticManager.HapticPattern] = [.risingPulse, .fallingPulse, .wobble]
        
        for (index, pattern) in patterns.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) { [weak self] in
                guard let self = self else { return }
                self.hapticManager.playCustomPattern(pattern)
            }
        }
        
        // 播放庆祝声音序列
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.playCelebrationSound()
        }
    }
    
    // MARK: - 数据持久化
    
    private func loadSavedData() {
        let defaults = UserDefaults.standard
        
        // 加载点击计数
        tapCount = defaults.integer(forKey: "bubble_tap_count")
        
        // 加载总点击数
        totalTaps = defaults.integer(forKey: "bubble_total_taps")
        
        // 加载最大连击
        tapStreak = defaults.integer(forKey: "bubble_max_streak")
        
        print("📊 加载气泡数据: \(tapCount) 次点击, 总点击: \(totalTaps), 最大连击: \(tapStreak)")
    }
    
    private func saveCurrentState() {
        let defaults = UserDefaults.standard
        
        // 保存当前计数
        defaults.set(tapCount, forKey: "bubble_tap_count")
        
        // 保存总点击数
        defaults.set(totalTaps, forKey: "bubble_total_taps")
        
        // 保存最大连击
        let currentMaxStreak = defaults.integer(forKey: "bubble_max_streak")
        if tapStreak > currentMaxStreak {
            defaults.set(tapStreak, forKey: "bubble_max_streak")
        }
        
        // 保存会话统计
        saveSessionStats()
        
        defaults.synchronize()
        
        print("💾 气泡数据已保存: \(tapCount) 次点击")
    }
    
    private func saveSessionStats() {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        let tapsPerMinute = totalTaps > 0 ? Double(totalTaps) / (sessionDuration / 60) : 0
        
        let defaults = UserDefaults.standard
        
        // 保存会话统计
        var sessionStats = defaults.array(forKey: "bubble_session_stats") as? [[String: Any]] ?? []
        
        let newSession = [
            "date": Date(),
            "duration": sessionDuration,
            "taps": totalTaps,
            "taps_per_minute": tapsPerMinute,
            "max_streak": tapStreak,
            "max_speed": maxTapSpeed
        ] as [String : Any]
        
        sessionStats.append(newSession)
        
        // 只保留最近50个会话
        if sessionStats.count > 50 {
            sessionStats.removeFirst()
        }
        
        defaults.set(sessionStats, forKey: "bubble_session_stats")
        
        print("📈 会话统计: \(Int(tapsPerMinute)) 次/分钟, 最大连击: \(tapStreak)")
        
        // 重置会话开始时间
        sessionStartTime = Date()
    }
    
    // MARK: - 统计获取
    
    func getStatistics() -> [String: Any] {
        let defaults = UserDefaults.standard
        
        let totalTaps = defaults.integer(forKey: "bubble_total_taps")
        let maxStreak = defaults.integer(forKey: "bubble_max_streak")
        let sessionStats = defaults.array(forKey: "bubble_session_stats") as? [[String: Any]] ?? []
        
        // 计算平均点击速度
        let averageSpeed: TimeInterval = tapTimes.count > 1 ?
            tapTimes.last!.timeIntervalSince(tapTimes.first!) / Double(tapTimes.count - 1) : 0
        
        return [
            "current_count": tapCount,
            "total_taps": totalTaps,
            "max_streak": maxStreak,
            "current_streak": tapStreak,
            "max_speed": maxTapSpeed,
            "average_speed": averageSpeed,
            "session_count": sessionStats.count,
            "last_session_date": sessionStats.last?["date"] as? Date ?? Date()
        ]
    }
    
    func getAchievements() -> [Int] {
        let defaults = UserDefaults.standard
        return defaults.array(forKey: "bubble_achievements") as? [Int] ?? []
    }
    
    func getSessionHistory() -> [[String: Any]] {
        let defaults = UserDefaults.standard
        return defaults.array(forKey: "bubble_session_stats") as? [[String: Any]] ?? []
    }
    
    // MARK: - 音频测试方法
    
    // 在 BubbleDialViewModel.swift 中修改以下部分：

    // MARK: - 音频测试方法

    func testSoundMode(_ mode: HapticManager.CustomSoundMode) {  // 修改这里
        print("🔊 测试声音模式: \(mode)")
        
        // 临时切换到测试模式
        let originalMode = hapticManager.customSoundMode
        hapticManager.customSoundMode = mode
        
        // 播放测试声音
        playTapSound(forSpeed: 0.2)
        
        // 恢复原模式
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.hapticManager.customSoundMode = originalMode
        }
    }

    func testAllSoundModes() {
        print("🎵 测试所有声音模式...")
        
        let modes: [HapticManager.CustomSoundMode] = [.default, .mechanical, .digital, .natural, .futuristic, .silent]  // 修改这里
        
        for (index, mode) in modes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.0) { [weak self] in
                guard let self = self else { return }
                print("测试: \(mode)")
                self.testSoundMode(mode)
            }
        }
    }
    
    deinit {
        // 清理观察者
        NotificationCenter.default.removeObserver(self)
        
        // 保存最终状态
        saveCurrentState()
        
        // 清理音频播放器
        laserSoundPlayer = nil
        synthSoundPlayer = nil
        energySoundPlayer = nil
        digitalClickPlayer = nil
        digitalTickPlayer = nil
        digitalPopPlayer = nil
        
        print("🧹 BubbleDialViewModel 清理完成")
    }
}
