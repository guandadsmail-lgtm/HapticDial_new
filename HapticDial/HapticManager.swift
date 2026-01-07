// Core/HapticManager.swift - 完整修复版
import CoreHaptics
import AVFoundation
import Combine
import AudioToolbox
import CoreGraphics

class HapticManager: NSObject, ObservableObject {
    static let shared = HapticManager()
    
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticPatternPlayer?
    private var isEngineStarted = false
    
    // 音频播放器
    private var customSoundPlayers: [String: AVAudioPlayer] = [:]
    
    // 基本设置
    @Published var currentMode: DialMode = .ratchet
    @Published var isEnabled = true
    @Published var volume: Float = 0.5  // 默认音量50%
    @Published var hapticIntensity: Float = 0.7  // 默认触感强度70%
    
    // 自定义模式
    @Published var customHapticMode: CustomHapticMode = .default
    @Published var customSoundMode: CustomSoundMode = .default
    
    // 系统声音 ID
    private let ratchetSoundID: SystemSoundID = 1104  // 轻微点击声
    private let apertureSoundID: SystemSoundID = 1103  // 更柔和的点击声
    private let popSoundID: SystemSoundID = 1105      // 轻微破裂声
    private let tickSoundID: SystemSoundID = 1100     // 滴答声
    
    // UserDefaults
    private let defaults = UserDefaults.standard
    private let volumeKey = "haptic_volume"
    private let intensityKey = "haptic_intensity"
    private let hapticModeKey = "custom_haptic_mode"
    private let soundModeKey = "custom_sound_mode"
    private let currentSoundPackKey = "current_sound_pack"
    
    // MARK: - 声音包管理器
    private let soundPackManager = SoundPackManager.shared
    @Published var customSoundPacks: [SoundPack] = []
    @Published var currentCustomSoundPack: String?
    
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
    
    // 声音模式枚举
    public enum CustomSoundMode: String, CaseIterable {
        case `default` = "Default"
        case mechanical = "Mechanical"
        case digital = "Digital"
        case natural = "Natural"
        case futuristic = "Futuristic"
        case silent = "Silent"
        
        var description: String {
            switch self {
            case .default: return "System default sounds"
            case .mechanical: return "Mechanical clicks and gears"
            case .digital: return "Digital beeps and tones"
            case .natural: return "Natural water and wood"
            case .futuristic: return "Futuristic sci-fi sounds"
            case .silent: return "No sounds, only haptics"
            }
        }
    }
    
    // 触感模式枚举 - 修复为public
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
        
        // 从UserDefaults加载设置
        loadSettings()
        
        prepareHaptics()
        setupAudioSession()
        
        // 加载自定义声音包
        loadCustomSoundPacks()
        
        print("🎛️ HapticManager 初始化完成")
    }
    
    private func loadSettings() {
        volume = defaults.float(forKey: volumeKey) == 0 ? 0.5 : defaults.float(forKey: volumeKey)
        hapticIntensity = defaults.float(forKey: intensityKey) == 0 ? 0.7 : defaults.float(forKey: intensityKey)
        
        if let savedHapticMode = defaults.string(forKey: hapticModeKey),
           let mode = CustomHapticMode(rawValue: savedHapticMode) {
            customHapticMode = mode
        }
        
        if let savedSoundMode = defaults.string(forKey: soundModeKey),
           let mode = CustomSoundMode(rawValue: savedSoundMode) {
            customSoundMode = mode
        }
        
        if let savedSoundPack = defaults.string(forKey: currentSoundPackKey) {
            currentCustomSoundPack = savedSoundPack
        }
    }
    
    private func loadCustomSoundPacks() {
        customSoundPacks = soundPackManager.installedSoundPacks
        print("📦 加载了 \(customSoundPacks.count) 个自定义声音包")
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
        } catch {
            print("音频设置失败: \(error)")
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
        guard isEnabled, let _ = engine, isEngineStarted else { return }
        
        // 根据自定义模式选择触感
        let floatVelocity = Float(velocity)
        
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
        
        // 播放对应的声音
        playSoundForCurrentMode()
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
    
    public func playSoundForCurrentMode() {
        guard customSoundMode != .silent else { return }
        
        // 如果有自定义声音包，优先使用自定义声音包
        if let packId = currentCustomSoundPack {
            playCustomSound(fromPack: packId, forMode: customSoundMode)
            return
        }
        
        // 否则按照原来的模式播放
        switch customSoundMode {
        case .default:
            playSystemSound()
        case .mechanical:
            playMechanicalSound()
        case .digital:
            playDigitalSound()
        case .natural:
            playNaturalSound()
        case .futuristic:
            playFuturisticSound()
        case .silent:
            break
        }
    }
    
    // 新增方法：从自定义声音包播放声音
    private func playCustomSound(fromPack packId: String, forMode mode: CustomSoundMode) {
        guard volume > 0 else { return }
        
        // 根据模式选择声音文件名
        let soundName = getSoundNameForMode(mode)
        
        // 尝试从声音包中获取声音文件
        if let soundURL = soundPackManager.getSoundFileURL(forSoundPack: packId, soundName: soundName) {
            playAudioFromURL(soundURL)
        } else {
            // 如果找不到，尝试播放默认的click声音
            if let defaultURL = soundPackManager.getSoundFileURL(forSoundPack: packId, soundName: "click") {
                playAudioFromURL(defaultURL)
            } else if let firstSound = soundPackManager.installedSoundPacks.first(where: { $0.id == packId })?.sounds.first {
                // 播放音效包中的第一个声音
                if let firstSoundURL = soundPackManager.getSoundFileURL(forSoundPack: packId, soundName: firstSound.name) {
                    playAudioFromURL(firstSoundURL)
                } else {
                    // 最后回退到系统声音
                    playSystemSoundForMode(mode)
                }
            } else {
                playSystemSoundForMode(mode)
            }
        }
    }
    
    // 根据声音模式获取对应的声音文件名
    private func getSoundNameForMode(_ mode: CustomSoundMode) -> String {
        switch mode {
        case .default:
            return currentMode == .ratchet ? "ratchet_click" : "aperture_click"
        case .mechanical:
            return "mechanical_click"
        case .digital:
            return "digital_click"
        case .natural:
            return "natural_click"
        case .futuristic:
            return "futuristic_click"
        case .silent:
            return ""
        }
    }
    
    // 为系统声音模式选择对应的声音
    private func playSystemSoundForMode(_ mode: CustomSoundMode) {
        switch mode {
        case .default:
            playSystemSound()
        case .mechanical:
            playMechanicalSound()
        case .digital:
            playDigitalSound()
        case .natural:
            playNaturalSound()
        case .futuristic:
            playFuturisticSound()
        case .silent:
            break
        }
    }
    
    private func playSystemSound() {
        guard volume > 0 else { return }
        
        let soundID = currentMode == .ratchet ? ratchetSoundID : apertureSoundID
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func playMechanicalSound() {
        guard volume > 0 else { return }
        
        let soundID: SystemSoundID
        switch currentMode {
        case .ratchet:
            soundID = 1104  // 机械点击声
        case .aperture:
            soundID = 1103  // 机械滴答声
        }
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func playDigitalSound() {
        guard volume > 0 else { return }
        
        let soundID: SystemSoundID
        switch currentMode {
        case .ratchet:
            soundID = 1057  // 数字点击声
        case .aperture:
            soundID = 1053  // 数字滴答声
        }
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func playNaturalSound() {
        guard volume > 0 else { return }
        
        let soundID: SystemSoundID = 1105  // 水滴声/自然声
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func playFuturisticSound() {
        guard volume > 0 else { return }
        
        let soundID: SystemSoundID = 4095  // 科幻声
        AudioServicesPlaySystemSound(soundID)
    }
    
    // MARK: - 自定义声音播放
    
    private func playCustomSound(named soundName: String, fromPack packId: String? = nil) {
        guard volume > 0 else { return }
        
        // 如果没有指定包ID，使用当前自定义包
        let effectivePackId = packId ?? currentCustomSoundPack
        
        if let packId = effectivePackId,
           let soundURL = soundPackManager.getSoundFileURL(forSoundPack: packId, soundName: soundName) {
            playAudioFromURL(soundURL)
        } else {
            // 尝试加载内置或系统声音
            if let url = getBuiltInSoundURL(soundName) {
                playAudioFromURL(url)
            } else {
                print("⚠️ 未找到内置声音文件: \(soundName)，使用系统默认声音")
                playSystemSound()
            }
        }
    }
    
    // 修改后的内置声音查找方法
    private func getBuiltInSoundURL(_ soundName: String) -> URL? {
        // 首先尝试加载项目中已有的声音文件
        let possibleExtensions = ["caf", "wav", "mp3", "m4a"]
        
        for ext in possibleExtensions {
            if let path = Bundle.main.path(forResource: soundName, ofType: ext) {
                return URL(fileURLWithPath: path)
            }
        }
        
        // 如果找不到，尝试加载我们生成的示例声音
        if let url = AudioResources.shared.getAudioURL(for: soundName) {
            return url
        }
        
        // 尝试常见的内置声音映射
        let soundMapping: [String: SystemSoundID] = [
            "click": 1104,
            "tick": 1103,
            "pop": 1105,
            "beep": 1057,
            "tone": 1053,
            "blip": 1055,
            "laser": 4095,
            "synth": 4094,
            "energy": 4097,
            "water_drop": 1005,
            "wood_tap": 1100
        ]
        
        if let soundID = soundMapping[soundName] {
            print("🎵 使用系统声音ID: \(soundID) 作为 \(soundName)")
            // 返回一个虚拟URL，表示使用了系统声音
            return URL(string: "system://\(soundID)")
        }
        
        return nil
    }
    
    private func playAudioFromURL(_ url: URL) {
        // 如果是系统声音URL，直接播放系统声音
        if url.scheme == "system", let soundIDString = url.host, let soundIDValue = UInt32(soundIDString) {
            let soundID = SystemSoundID(soundIDValue)
            AudioServicesPlaySystemSound(soundID)
            return
        }
        
        do {
            // 重用或创建播放器
            let player: AVAudioPlayer
            if let existingPlayer = customSoundPlayers[url.absoluteString] {
                player = existingPlayer
            } else {
                player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                customSoundPlayers[url.absoluteString] = player
            }
            
            player.volume = volume
            player.currentTime = 0
            player.play()
            
        } catch {
            print("❌ 播放音频失败: \(error)")
            playSystemSound() // 失败时回退到系统声音
        }
    }
    
    // MARK: - 自定义触感模式
    
    // 修复访问级别为public，并修复参数类型
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
    
    // MARK: - 声音包管理方法
    
    func getSoundPackSounds(_ packId: String) -> [String] {
        guard let pack = customSoundPacks.first(where: { $0.id == packId }) else {
            return []
        }
        return pack.soundFiles ?? []
    }
    
    func testSoundPack(_ packId: String) {
        print("🎵 测试声音包: \(packId)")
        
        // 首先尝试从已安装的声音包中获取声音
        guard let pack = customSoundPacks.first(where: { $0.id == packId }) else {
            print("❌ 未找到声音包: \(packId)")
            playDefaultTestSequence()
            return
        }
        
        let sounds = pack.sounds
        
        if sounds.isEmpty {
            print("⚠️ 声音包为空，使用默认测试序列")
            playDefaultTestSequence()
            return
        }
        
        print("🎵 播放声音包预览，包含 \(sounds.count) 个声音")
        
        // 播放前3个声音作为预览
        let previewSounds = Array(sounds.prefix(3))
        
        for (index, sound) in previewSounds.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                print("▶️ 播放: \(sound.name) (文件: \(sound.fileName))")
                self.playCustomSound(named: sound.name, fromPack: packId)
            }
        }
    }
    
    // 修复默认测试序列
    private func playDefaultTestSequence() {
        print("🔊 播放默认测试序列")
        
        // 使用系统声音进行测试，确保总是有声音
        let testSounds = [
            (name: "系统点击1", soundID: SystemSoundID(1104)),
            (name: "系统点击2", soundID: SystemSoundID(1103)),
            (name: "系统弹出", soundID: SystemSoundID(1105))
        ]
        
        for (index, sound) in testSounds.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                print("🔊 测试 \(sound.name) (ID: \(sound.soundID))")
                AudioServicesPlaySystemSound(sound.soundID)
            }
        }
    }
    
    // 批量播放声音包中的声音
    func playSoundPackPreview(_ packId: String, interval: TimeInterval = 0.5) {
        let sounds = getSoundPackSounds(packId)
        
        if sounds.isEmpty {
            print("❌ 声音包为空")
            return
        }
        
        print("🎵 预览声音包: \(packId)")
        
        // 只播放前3个声音作为预览
        let previewSounds = Array(sounds.prefix(3))
        
        for (index, soundFile) in previewSounds.enumerated() {
            let soundName = soundFile.replacingOccurrences(of: ".caf", with: "")
                .replacingOccurrences(of: ".wav", with: "")
                .replacingOccurrences(of: ".mp3", with: "")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * interval) {
                self.playCustomSound(named: soundName, fromPack: packId)
            }
        }
    }
    
    func refreshSoundPacks() {
        customSoundPacks = soundPackManager.installedSoundPacks
        print("🔄 刷新声音包列表，当前有 \(customSoundPacks.count) 个声音包")
    }
    
    func setCurrentSoundPack(_ packId: String?) {
        currentCustomSoundPack = packId
        defaults.set(packId, forKey: currentSoundPackKey)
        defaults.synchronize()
        print("📦 设置当前声音包: \(packId ?? "None")")
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
    
    func testSoundMode(_ mode: CustomSoundMode) {
        switch mode {
        case .default:
            playSystemSound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                AudioServicesPlaySystemSound(SystemSoundID(1103)) // 另一个机械声
            }
        case .mechanical:
            playMechanicalSound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                AudioServicesPlaySystemSound(SystemSoundID(1103)) // 另一个机械声
            }
        case .digital:
            playDigitalSound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                AudioServicesPlaySystemSound(SystemSoundID(1053)) // 另一个数字声
            }
        case .natural:
            playNaturalSound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                AudioServicesPlaySystemSound(SystemSoundID(1105)) // 另一个自然声
            }
        case .futuristic:
            playFuturisticSound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                AudioServicesPlaySystemSound(SystemSoundID(4095)) // 另一个科幻声
            }
        case .silent:
            print("🔇 静音模式")
        }
    }
    
    // MARK: - 设置管理
    
    func setCustomHapticMode(_ mode: CustomHapticMode) {
        customHapticMode = mode
        defaults.set(mode.rawValue, forKey: hapticModeKey)
        defaults.synchronize()
    }
    
    func setCustomSoundMode(_ mode: CustomSoundMode) {
        customSoundMode = mode
        defaults.set(mode.rawValue, forKey: soundModeKey)
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
        if let player = continuousPlayer {
            do {
                try player.stop(atTime: CHHapticTimeImmediate)
            } catch {
                print("停止持续触觉失败: \(error)")
            }
        }
    }
    
    func testHaptic() {
        playClick()
    }
    
    func getAvailableHapticModes() -> [String] {
        return CustomHapticMode.allCases.map { $0.rawValue }
    }
    
    func getAvailableSoundModes() -> [String] {
        return CustomSoundMode.allCases.map { $0.rawValue }
    }
}
