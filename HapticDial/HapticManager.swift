
import CoreHaptics
import AVFoundation
import Combine
import AudioToolbox
import CoreGraphics
import UIKit

// MARK: - DialMode 枚举（放在文件顶部，避免重复定义）
public enum DialMode: String, CaseIterable {
    case ratchet
    case aperture
}

class HapticManager: NSObject, ObservableObject {
    static let shared = HapticManager()
    
    // 使用统一音效管理器
    private let unifiedSoundManager = UnifiedSoundManager.shared
    
    // 保留原有属性
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticPatternPlayer?
    private var isEngineStarted = false
    
    // 基本设置
    @Published var currentMode: DialMode = .ratchet
    @Published var isEnabled = true
    @Published var volume: Float = 0.5
    @Published var hapticIntensity: Float = 0.7
    
    // 自定义触感模式
    @Published var customHapticMode: CustomHapticMode = .default
    
    // UserDefaults
    private let defaults = UserDefaults.standard
    private let volumeKey = "haptic_volume"
    private let intensityKey = "haptic_intensity"
    private let hapticModeKey = "custom_haptic_mode"
    
    // 系统声音 ID（保留用于回退）
    private let ratchetSoundID: SystemSoundID = 1104
    private let apertureSoundID: SystemSoundID = 1103
    
    // 触感模式枚举
    public enum CustomHapticMode: String, CaseIterable {
        case `default` = "Default"
        case lightClick = "Light Click"
        case mediumClick = "Medium Click"
        case heavyClick = "Heavy Click"
        case doubleClick = "Double Click"
        case tripleClick = "Triple Click"
        case shortVibration = "Short Vibration"
        case longVibration = "Long Vibration"
        case risingPulse = "Rising Pulse"
        case fallingPulse = "Falling Pulse"
        case wobble = "Wobble"
        
        var description: String {
            switch self {
            case .default: return "System default haptic"
            case .lightClick: return "Gentle light tap"
            case .mediumClick: return "Medium strength click"
            case .heavyClick: return "Strong heavy click"
            case .doubleClick: return "Double tap rhythm"
            case .tripleClick: return "Triple tap rhythm"
            case .shortVibration: return "Short vibration buzz"
            case .longVibration: return "Long vibration buzz"
            case .risingPulse: return "Intensity rising pulse"
            case .fallingPulse: return "Intensity falling pulse"
            case .wobble: return "Wobble effect"
            }
        }
    }
    
    // 触感模式枚举
    public enum HapticPattern {
        case lightClick
        case mediumClick
        case heavyClick
        case doubleClick
        case tripleClick
        case shortVibration
        case longVibration
        case risingPulse
        case fallingPulse
        case wobble
    }
    
    private override init() {
        super.init()
        
        loadSettings()
        prepareHaptics()
        setupAudioSession()
        
        print("🎛️ HapticManager 初始化完成")
    }
    
    private func loadSettings() {
        volume = defaults.float(forKey: volumeKey) == 0 ? 0.5 : defaults.float(forKey: volumeKey)
        hapticIntensity = defaults.float(forKey: intensityKey) == 0 ? 0.7 : defaults.float(forKey: intensityKey)
        
        if let savedHapticMode = defaults.string(forKey: hapticModeKey),
           let mode = CustomHapticMode(rawValue: savedHapticMode) {
            customHapticMode = mode
        }
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("设备不支持高级触觉")
            return
        }
        
        do {
            engine = try CHHapticEngine()
            
            engine?.resetHandler = { [weak self] in
                print("触觉引擎重置")
                self?.isEngineStarted = false
                self?.startEngine()
            }
            
            engine?.stoppedHandler = { reason in
                print("触觉引擎停止: \(reason.rawValue)")
            }
            
            startEngine()
            
        } catch {
            print("创建触觉引擎失败: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("🎛️ HapticManager 音频会话设置成功")
        } catch {
            print("🎛️ 音频设置失败: \(error)")
        }
    }
    
    private func startEngine() {
        guard let engine = engine, !isEngineStarted else { return }
        
        do {
            try engine.start()
            isEngineStarted = true
            print("触觉引擎启动成功")
        } catch {
            print("启动触觉引擎失败: \(error)")
        }
    }
    
    // MARK: - 主要触感播放方法
    
    func playClick(velocity: Double = 1.0) {
        guard isEnabled else { return }
        
        let floatVelocity = Float(velocity)
        
        // 播放触觉反馈
        if isEngineStarted {
            switch customHapticMode {
            case .default:
                playDefaultHaptic(velocity: floatVelocity)
            case .lightClick:
                playCustomPattern(.lightClick, velocity: floatVelocity)
            case .mediumClick:
                playCustomPattern(.mediumClick, velocity: floatVelocity)
            case .heavyClick:
                playCustomPattern(.heavyClick, velocity: floatVelocity)
            case .doubleClick:
                playCustomPattern(.doubleClick, velocity: floatVelocity)
            case .tripleClick:
                playCustomPattern(.tripleClick, velocity: floatVelocity)
            case .shortVibration:
                playCustomPattern(.shortVibration, velocity: floatVelocity)
            case .longVibration:
                playCustomPattern(.longVibration, velocity: floatVelocity)
            case .risingPulse:
                playCustomPattern(.risingPulse, velocity: floatVelocity)
            case .fallingPulse:
                playCustomPattern(.fallingPulse, velocity: floatVelocity)
            case .wobble:
                playCustomPattern(.wobble, velocity: floatVelocity)
            }
        }
        
        // 播放音效
        playSoundForCurrentSelection()
    }
    
    private func playDefaultHaptic(velocity: Float) {
        guard let engine = engine else { return }
        
        let sharpness: Float
        let baseIntensity: Float
        
        switch currentMode {
        case .ratchet:
            sharpness = 0.9
            baseIntensity = 0.7
        case .aperture:
            sharpness = 0.3
            baseIntensity = 0.4
        }
        
        let userIntensity = hapticIntensity
        let baseWithUser = baseIntensity * userIntensity
        let intensity = Float(min(1.0, Double(baseWithUser) * Double(velocity)))
        
        do {
            let clickEvent = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
                ],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [clickEvent], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("播放默认触觉失败: \(error)")
        }
    }
    
    // MARK: - 声音播放
    
    private func playSoundForCurrentSelection() {
        guard volume > 0 else { return }
        
        ensureAudioSessionActive()
        
        if let selectedSound = unifiedSoundManager.selectedSound {
            print("🎛️ HapticManager 播放音效: \(selectedSound.name)")
            
            // 直接调用统一的播放方法
            unifiedSoundManager.playSound(selectedSound)
        } else {
            playFallbackSound()
        }
    }

    private func ensureAudioSessionActive() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("🎛️ 激活音频会话失败: \(error)")
        }
    }
    
    private func playUnifiedSound(_ soundOption: UnifiedSoundManager.SoundOption) {
        guard volume > 0 else { return }
        
        print("🎛️ HapticManager 播放音效: \(soundOption.name)")
        
        // 直接使用统一音效管理器测试音效
        unifiedSoundManager.testSound(soundOption)
    }
    
    private func playFallbackSound() {
        let soundID: SystemSoundID
        switch currentMode {
        case .ratchet:
            soundID = ratchetSoundID
        case .aperture:
            soundID = apertureSoundID
        }
        
        print("🎛️ 播放备用系统音效 ID: \(soundID)")
        AudioServicesPlaySystemSound(soundID)
        
        // 🔴 模拟器特殊处理
        #if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AudioServicesPlaySystemSound(soundID)
        }
        #endif
    }
    
    // MARK: - 自定义触感模式
    
    public func playCustomPattern(_ pattern: HapticPattern, velocity: Float = 1.0) {
        guard let engine = engine, isEngineStarted else { return }
        
        do {
            var events: [CHHapticEvent] = []
            let intensityMultiplier = hapticIntensity * velocity
            
            switch pattern {
            case .lightClick:
                events = createClickPattern(intensity: 0.3 * intensityMultiplier, sharpness: 0.5, count: 1)
            case .mediumClick:
                events = createClickPattern(intensity: 0.5 * intensityMultiplier, sharpness: 0.7, count: 1)
            case .heavyClick:
                events = createClickPattern(intensity: 0.8 * intensityMultiplier, sharpness: 0.9, count: 1)
            case .doubleClick:
                events = createClickPattern(intensity: 0.5 * intensityMultiplier, sharpness: 0.6, count: 2, interval: 0.1)
            case .tripleClick:
                events = createClickPattern(intensity: 0.4 * intensityMultiplier, sharpness: 0.5, count: 3, interval: 0.08)
            case .shortVibration:
                events = [
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6 * intensityMultiplier),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                        ],
                        relativeTime: 0,
                        duration: 0.1
                    )
                ]
            case .longVibration:
                events = [
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7 * intensityMultiplier),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                        ],
                        relativeTime: 0,
                        duration: 0.3
                    )
                ]
            case .risingPulse:
                events = createRisingPulsePattern(intensity: intensityMultiplier)
            case .fallingPulse:
                events = createFallingPulsePattern(intensity: intensityMultiplier)
            case .wobble:
                events = createWobblePattern(intensity: intensityMultiplier)
            }
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("播放自定义触觉失败: \(error)")
        }
    }
    
    private func createClickPattern(intensity: Float, sharpness: Float, count: Int, interval: TimeInterval = 0.0) -> [CHHapticEvent] {
        var events: [CHHapticEvent] = []
        
        for i in 0..<count {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: TimeInterval(i) * interval
            )
            events.append(event)
        }
        
        return events
    }
    
    private func createRisingPulsePattern(intensity: Float) -> [CHHapticEvent] {
        var events: [CHHapticEvent] = []
        
        for i in 0..<5 {
            let pulseIntensity = intensity * (0.3 + Float(i) * 0.15)
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: pulseIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: TimeInterval(i) * 0.05
            )
            events.append(event)
        }
        
        return events
    }
    
    private func createFallingPulsePattern(intensity: Float) -> [CHHapticEvent] {
        var events: [CHHapticEvent] = []
        
        for i in 0..<5 {
            let pulseIntensity = intensity * (0.8 - Float(i) * 0.12)
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: pulseIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: TimeInterval(i) * 0.05
            )
            events.append(event)
        }
        
        return events
    }
    
    private func createWobblePattern(intensity: Float) -> [CHHapticEvent] {
        var events: [CHHapticEvent] = []
        
        let wobbleSequence = [
            (intensity: 0.5, time: 0.0),
            (intensity: 0.7, time: 0.05),
            (intensity: 0.4, time: 0.1),
            (intensity: 0.6, time: 0.15),
            (intensity: 0.3, time: 0.2)
        ]
        
        for wobble in wobbleSequence {
            let wobbleIntensity = Float(wobble.intensity)
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * wobbleIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: wobble.time
            )
            events.append(event)
        }
        
        return events
    }
    
    // MARK: - 获取当前音效信息
    
    func getCurrentSoundName() -> String {
        return unifiedSoundManager.getCurrentSoundName()
    }
    
    func isSoundEnabled() -> Bool {
        return unifiedSoundManager.isSoundEnabled()
    }
    
    // MARK: - 设置管理
    
    func setCustomHapticMode(_ mode: CustomHapticMode) {
        customHapticMode = mode
        defaults.set(mode.rawValue, forKey: hapticModeKey)
        defaults.synchronize()
    }
    
    func setVolume(_ value: Float) {
        volume = value
        defaults.set(value, forKey: volumeKey)
        defaults.synchronize()
    }
    
    func setHapticIntensity(_ value: Float) {
        hapticIntensity = value
        defaults.set(value, forKey: intensityKey)
        defaults.synchronize()
    }
    
    // MARK: - 测试方法
    
    func testHapticMode(_ mode: CustomHapticMode) {
        switch mode {
        case .default:
            playClick()
        case .lightClick:
            playCustomPattern(.lightClick, velocity: 1.0)
        case .mediumClick:
            playCustomPattern(.mediumClick, velocity: 1.0)
        case .heavyClick:
            playCustomPattern(.heavyClick, velocity: 1.0)
        case .doubleClick:
            playCustomPattern(.doubleClick, velocity: 1.0)
        case .tripleClick:
            playCustomPattern(.tripleClick, velocity: 1.0)
        case .shortVibration:
            playCustomPattern(.shortVibration, velocity: 1.0)
        case .longVibration:
            playCustomPattern(.longVibration, velocity: 1.0)
        case .risingPulse:
            playCustomPattern(.risingPulse, velocity: 1.0)
        case .fallingPulse:
            playCustomPattern(.fallingPulse, velocity: 1.0)
        case .wobble:
            playCustomPattern(.wobble, velocity: 1.0)
        }
    }
    
    // MARK: - 其他方法
    
    func startContinuousHaptic(intensity: Float = 0.5, sharpness: Float = 0.5) {
        guard let engine = engine, isEngineStarted else { return }
        
        do {
            let continuousEvent = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0,
                duration: 1.0
            )
            
            let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
            continuousPlayer = try engine.makePlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("创建持续触觉失败: \(error)")
        }
    }
    
    func updateContinuousHaptic(intensity: Float, sharpness: Float) {
        do {
            let dynamicParameter = CHHapticDynamicParameter(
                parameterID: .hapticIntensityControl,
                value: intensity,
                relativeTime: 0
            )
            try continuousPlayer?.sendParameters([dynamicParameter], atTime: 0)
        } catch {
            print("更新持续触觉失败: \(error)")
        }
    }
    
    func stopContinuousHaptic() {
        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {
            print("停止持续触觉失败: \(error)")
        }
    }
    
    func testHaptic() {
        playClick()
    }
    
    func getAvailableHapticModes() -> [String] {
        return CustomHapticMode.allCases.map { $0.rawValue }
    }
    
    // MARK: - 新增方法
    
    func playSoftClick() {
        // 使用轻柔的触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.5)
    }
    
    // MARK: - 修复第586行附近的 try-catch 块
    // 原来的代码可能有这样的问题：
    // do {
    //     // 这里没有调用任何可能抛出错误的函数
    // } catch {
    //     print("Error")
    // }
    
    // 修复为：
    func someSafeOperation() {
        // 直接执行操作，不使用 try-catch，因为没有抛出错误
        print("执行安全操作")
    }
    
    // MARK: - 清理
    
    func cleanup() {
        // 停止并清理触觉引擎
        if let engine = engine {
            do {
                try engine.stop()
            } catch {
                print("停止触觉引擎失败: \(error)")
            }
        }
        
        engine = nil
        isEngineStarted = false
        
        print("🧹 HapticManager 清理完成")
    }
    
    deinit {
        cleanup()
    }
}
