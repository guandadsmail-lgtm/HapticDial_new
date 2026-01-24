import CoreHaptics
import AVFoundation
import Combine
import AudioToolbox
import CoreGraphics
import UIKit

// MARK: - DialMode 枚举
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
    @Published var customHapticMode: CustomHapticMode = .default
    
    // UserDefaults
    private let defaults = UserDefaults.standard
    private let volumeKey = "haptic_volume"
    private let intensityKey = "haptic_intensity"
    private let hapticModeKey = "custom_haptic_mode"
    
    // 系统声音 ID
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
        
        var description: String { rawValue }
    }
    
    public enum HapticPattern {
        case lightClick, mediumClick, heavyClick, doubleClick, tripleClick
        case shortVibration, longVibration, risingPulse, fallingPulse, wobble
    }
    
    private override init() {
        super.init()
        loadSettings()
        prepareHaptics()
        setupAudioSession()
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
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                self?.isEngineStarted = false
                self?.startEngine()
            }
            startEngine()
        } catch {
            print("创建触觉引擎失败: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    private func startEngine() {
        guard let engine = engine, !isEngineStarted else { return }
        try? engine.start()
        isEngineStarted = true
    }
    
    // MARK: - Play Methods
    
    func playClick(velocity: Double = 1.0) {
        guard isEnabled else { return }
        let floatVelocity = Float(velocity)
        
        if isEngineStarted {
            switch customHapticMode {
            case .default: playDefaultHaptic(velocity: floatVelocity)
            case .lightClick: playCustomPattern(.lightClick, velocity: floatVelocity)
            case .mediumClick: playCustomPattern(.mediumClick, velocity: floatVelocity)
            case .heavyClick: playCustomPattern(.heavyClick, velocity: floatVelocity)
            case .doubleClick: playCustomPattern(.doubleClick, velocity: floatVelocity)
            case .tripleClick: playCustomPattern(.tripleClick, velocity: floatVelocity)
            case .shortVibration: playCustomPattern(.shortVibration, velocity: floatVelocity)
            case .longVibration: playCustomPattern(.longVibration, velocity: floatVelocity)
            case .risingPulse: playCustomPattern(.risingPulse, velocity: floatVelocity)
            case .fallingPulse: playCustomPattern(.fallingPulse, velocity: floatVelocity)
            case .wobble: playCustomPattern(.wobble, velocity: floatVelocity)
            }
        }
        playSoundForCurrentSelection()
    }
    
    private func playDefaultHaptic(velocity: Float) {
        guard let engine = engine else { return }
        let sharpness: Float = currentMode == .ratchet ? 0.9 : 0.3
        let baseIntensity: Float = currentMode == .ratchet ? 0.7 : 0.4
        let intensity = Float(min(1.0, Double(baseIntensity * hapticIntensity) * Double(velocity)))
        
        do {
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            ], relativeTime: 0)
            let player = try engine.makePlayer(with: try CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch { }
    }
    
    public func playCustomPattern(_ pattern: HapticPattern, velocity: Float = 1.0) {
        guard let engine = engine, isEngineStarted else { return }
        let intensity = hapticIntensity * velocity
        
        var events: [CHHapticEvent] = []
        switch pattern {
        case .lightClick: events = createClickPattern(intensity: 0.3 * intensity, sharpness: 0.5, count: 1)
        case .mediumClick: events = createClickPattern(intensity: 0.5 * intensity, sharpness: 0.7, count: 1)
        case .heavyClick: events = createClickPattern(intensity: 0.8 * intensity, sharpness: 0.9, count: 1)
        case .doubleClick: events = createClickPattern(intensity: 0.5 * intensity, sharpness: 0.6, count: 2, interval: 0.1)
        case .tripleClick: events = createClickPattern(intensity: 0.4 * intensity, sharpness: 0.5, count: 3, interval: 0.08)
        case .shortVibration:
            events = [CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6 * intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0, duration: 0.1)]
        case .longVibration:
            events = [CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7 * intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0, duration: 0.3)]
        case .risingPulse: events = createRisingPulsePattern(intensity: intensity)
        case .fallingPulse: events = createFallingPulsePattern(intensity: intensity)
        case .wobble: events = createWobblePattern(intensity: intensity)
        }
        
        do {
            let player = try engine.makePlayer(with: try CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch { }
    }
    
    // Generators
    private func createClickPattern(intensity: Float, sharpness: Float, count: Int, interval: TimeInterval = 0.0) -> [CHHapticEvent] {
        (0..<count).map {
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ], relativeTime: TimeInterval($0) * interval)
        }
    }
    
    private func createRisingPulsePattern(intensity: Float) -> [CHHapticEvent] {
        (0..<5).map {
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * (0.3 + Float($0) * 0.15)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: TimeInterval($0) * 0.05)
        }
    }
    
    private func createFallingPulsePattern(intensity: Float) -> [CHHapticEvent] {
        (0..<5).map {
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * (0.8 - Float($0) * 0.12)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: TimeInterval($0) * 0.05)
        }
    }
    
    private func createWobblePattern(intensity: Float) -> [CHHapticEvent] {
        [(0.5, 0.0), (0.7, 0.05), (0.4, 0.1), (0.6, 0.15), (0.3, 0.2)].map { val, time in
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * Float(val)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: time)
        }
    }
    
    // MARK: - Sound
    private func playSoundForCurrentSelection() {
        if let selectedSound = unifiedSoundManager.selectedSound {
            unifiedSoundManager.playSound(selectedSound)
        } else {
            playFallbackSound()
        }
    }
    
    private func playFallbackSound() {
        let soundID = currentMode == .ratchet ? ratchetSoundID : apertureSoundID
        AudioServicesPlaySystemSound(soundID)
    }
    
    // MARK: - Continuous Haptic Support
    
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
    
    // MARK: - Getters & Setters
    func getCurrentSoundName() -> String { unifiedSoundManager.getCurrentSoundName() }
    func isSoundEnabled() -> Bool { unifiedSoundManager.isSoundEnabled() }
    func setCustomHapticMode(_ mode: CustomHapticMode) { customHapticMode = mode; defaults.set(mode.rawValue, forKey: hapticModeKey) }
    func setVolume(_ value: Float) { volume = value; defaults.set(value, forKey: volumeKey) }
    func setHapticIntensity(_ value: Float) { hapticIntensity = value; defaults.set(value, forKey: intensityKey) }
    func testHaptic() { playClick() }
    func testHapticMode(_ mode: CustomHapticMode) { let old = customHapticMode; customHapticMode = mode; playClick(); customHapticMode = old }
    func getAvailableHapticModes() -> [String] { CustomHapticMode.allCases.map { $0.rawValue } }
    func playSoftClick() { let g = UIImpactFeedbackGenerator(style: .soft); g.prepare(); g.impactOccurred(intensity: 0.5) }
    
    func cleanup() {
        engine?.stop(completionHandler: nil)
        engine = nil
        isEngineStarted = false
        print("🧹 HapticManager 清理完成")
    }
    
    deinit { cleanup() }
}
