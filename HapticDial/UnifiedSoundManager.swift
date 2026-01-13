import Foundation
import AudioToolbox
import Combine
import AVFoundation

class UnifiedSoundManager: ObservableObject {
    static let shared = UnifiedSoundManager()
    
    enum SoundType: String, Codable {
        case system
        case custom
    }
    
    struct SoundOption: Identifiable, Equatable, Codable {
        let id: String
        let name: String
        let type: SoundType
        let soundFile: String?
        let systemSoundID: UInt32?
        var isUserCustom: Bool = false
        var isBuiltInCustom: Bool = false
        
        var displayName: String { name }
        var description: String {
            if isBuiltInCustom {
                return "Built-in sound effect"
            }
            return type == .system ? "System sound effect" : "Custom sound effect"
        }
        var category: String {
            if isBuiltInCustom {
                return "Built-in"
            }
            return type == .system ? "System" : "Custom"
        }
        
        var firstLetter: String {
            if name.isEmpty { return "?" }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(1)).uppercased()
        }
        
        static func == (lhs: SoundOption, rhs: SoundOption) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    private let systemSoundOptions: [SoundOption] = [
        SoundOption(id: "system_default", name: "Default", type: .system, soundFile: nil, systemSoundID: 1104),
        SoundOption(id: "system_tick", name: "Tick", type: .system, soundFile: nil, systemSoundID: 1103),
        SoundOption(id: "system_click", name: "Click", type: .system, soundFile: nil, systemSoundID: 1100),
        SoundOption(id: "system_beep", name: "Beep", type: .system, soundFile: nil, systemSoundID: 1110),
        SoundOption(id: "system_bell", name: "Bell", type: .system, soundFile: nil, systemSoundID: 1005),
        SoundOption(id: "none", name: "Mute", type: .system, soundFile: nil, systemSoundID: nil)
    ]
    
    // 修正：使用正确的文件名（根据你的文件列表）
    private let builtInCustomSounds: [SoundOption] = [
        SoundOption(id: "builtin_budda_large_bell", name: "Large Bell", type: .custom,
                   soundFile: "Budda_large_bell.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true),
        SoundOption(id: "builtin_budda_small_bell", name: "Small Bell", type: .custom,
                   soundFile: "Budda_small_bell.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true),
        SoundOption(id: "builtin_sword", name: "Sword", type: .custom,
                   soundFile: "sword.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true),
        SoundOption(id: "builtin_ikkyu_san", name: "Ikkyu San", type: .custom,
                   soundFile: "Ikkyu_san.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true),
        SoundOption(id: "builtin_knife", name: "Knife", type: .custom,
                   soundFile: "knife.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true)
    ]
    
    @Published var userCustomSounds: [SoundOption] = []
    @Published var selectedSound: SoundOption? {
        didSet {
            if let sound = selectedSound {
                saveSelectedSound(sound)
            }
        }
    }
    
    private var soundIDCache: [String: SystemSoundID] = [:]
    private var audioPlayerCache: [String: AVAudioPlayer] = [:]
    
    var availableSounds: [SoundOption] {
        var allSounds = systemSoundOptions
        allSounds.append(contentsOf: builtInCustomSounds)
        allSounds.append(contentsOf: userCustomSounds)
        return allSounds
    }
    
    var categories: [String] {
        var categories = ["All"]
        categories.append("System")
        if !builtInCustomSounds.isEmpty {
            categories.append("Built-in")
        }
        if !userCustomSounds.isEmpty {
            categories.append("Custom")
        }
        return categories
    }
    
    private var userCustomSoundsURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("CustomSounds")
    }
    
    private let selectedSoundKey = "unified_selected_sound"
    private let userCustomSoundsKey = "user_custom_sounds_list"
    
    private init() {
        setupAudioSession()
        loadSelectedSound()
        loadUserCustomSounds()
        ensureCustomSoundsDirectory()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("🎵 音频会话设置成功")
        } catch {
            print("❌ 音频设置失败: \(error)")
        }
    }
    
    func selectSound(_ sound: SoundOption) {
        selectedSound = sound
    }
    
    private func loadSelectedSound() {
        if let savedData = UserDefaults.standard.data(forKey: selectedSoundKey),
           let decoded = try? JSONDecoder().decode(SoundOption.self, from: savedData) {
            selectedSound = decoded
        } else {
            selectedSound = systemSoundOptions.first
        }
    }
    
    private func saveSelectedSound(_ sound: SoundOption) {
        if let encoded = try? JSONEncoder().encode(sound) {
            UserDefaults.standard.set(encoded, forKey: selectedSoundKey)
        }
    }
    
    // MARK: - 核心修复：音效播放方法
    
    func playSound(_ sound: SoundOption) {
        print("🎵 播放音效: \(sound.name), 类型: \(sound.type), ID: \(sound.id)")
        
        ensureAudioSessionActive()
        
        if let systemSoundID = sound.systemSoundID {
            print("🎵 播放系统音效 ID: \(systemSoundID)")
            AudioServicesPlaySystemSound(systemSoundID)
        } else if let soundFile = sound.soundFile {
            var soundURL: URL?
            
            if sound.isBuiltInCustom {
                // 修正：使用正确的资源名（移除.caf扩展名）
                let resourceName = soundFile.replacingOccurrences(of: ".caf", with: "")
                print("🎵 尝试加载内置音效: \(resourceName)")
                
                // 尝试多种方式加载内置音效
                if let url = Bundle.main.url(forResource: resourceName, withExtension: "caf") {
                    soundURL = url
                    print("✅ 从Bundle加载内置音效成功: \(resourceName)")
                } else {
                    print("❌ Bundle中未找到音效: \(resourceName).caf")
                    
                    // 尝试直接使用文件名加载（包含扩展名）
                    if let url = Bundle.main.url(forResource: soundFile, withExtension: nil) {
                        soundURL = url
                        print("✅ 使用完整文件名加载成功: \(soundFile)")
                    } else {
                        print("❌ 使用完整文件名也找不到: \(soundFile)")
                        
                        // 尝试其他可能的位置
                        let possiblePaths = [
                            Bundle.main.bundlePath + "/" + soundFile,
                            Bundle.main.resourcePath! + "/" + soundFile
                        ]
                        
                        for path in possiblePaths {
                            if FileManager.default.fileExists(atPath: path) {
                                soundURL = URL(fileURLWithPath: path)
                                print("✅ 从文件系统找到音效: \(path)")
                                break
                            }
                        }
                    }
                }
            } else if sound.isUserCustom {
                soundURL = userCustomSoundsURL.appendingPathComponent(soundFile)
                if FileManager.default.fileExists(atPath: soundURL?.path ?? "") {
                    print("🎵 从用户目录加载自定义音效: \(soundFile)")
                } else {
                    soundURL = nil
                }
            }
            
            guard let validURL = soundURL else {
                print("❌ 音效文件未找到: \(soundFile)")
                // 回退到默认系统音效
                AudioServicesPlaySystemSound(1104)
                return
            }
            
            guard FileManager.default.fileExists(atPath: validURL.path) else {
                print("❌ 音效文件不存在: \(validURL.path)")
                AudioServicesPlaySystemSound(1104)
                return
            }
            
            let cacheKey = sound.id
            
            if let cachedSoundID = soundIDCache[cacheKey] {
                print("✅ 使用缓存的音效ID播放: \(sound.name)")
                AudioServicesPlaySystemSound(cachedSoundID)
            } else {
                var soundID: SystemSoundID = 0
                let status = AudioServicesCreateSystemSoundID(validURL as CFURL, &soundID)
                
                if status == noErr {
                    soundIDCache[cacheKey] = soundID
                    print("✅ 创建并缓存音效ID: \(sound.name)")
                    AudioServicesPlaySystemSound(soundID)
                } else {
                    print("❌ 创建系统音效ID失败: \(sound.name), 错误: \(status)")
                    
                    // 尝试使用 AVAudioPlayer
                    playWithAVAudioPlayer(url: validURL, cacheKey: cacheKey)
                }
            }
        } else {
            print("🎵 静音模式（无音效）")
        }
    }
    
    private func ensureAudioSessionActive() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ 激活音频会话失败: \(error)")
        }
    }
    
    private func playWithAVAudioPlayer(url: URL, cacheKey: String) {
        do {
            if let cachedPlayer = audioPlayerCache[cacheKey] {
                print("🎵 使用缓存的 AVAudioPlayer 播放")
                cachedPlayer.currentTime = 0
                cachedPlayer.play()
                return
            }
            
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 1.0
            audioPlayer.play()
            
            audioPlayerCache[cacheKey] = audioPlayer
            print("✅ 创建并缓存 AVAudioPlayer: \(url.lastPathComponent)")
        } catch {
            print("❌ AVAudioPlayer 播放失败: \(error)")
            AudioServicesPlaySystemSound(1104) // 回退到默认音效
        }
    }
    
    func testSound(_ sound: SoundOption) {
        print("🔊 测试音效: \(sound.name)")
        ensureAudioSessionActive()
        playSound(sound)
    }
    
    func clearSoundCache() {
        for (_, soundID) in soundIDCache {
            AudioServicesDisposeSystemSoundID(soundID)
        }
        soundIDCache.removeAll()
        
        audioPlayerCache.removeAll()
        print("✅ 清理音效缓存")
    }
    
    deinit {
        clearSoundCache()
    }
    
    // MARK: - 用户自定义音效管理
    
    private func ensureCustomSoundsDirectory() {
        let fileManager = FileManager.default
        let customSoundsDir = userCustomSoundsURL
        
        if !fileManager.fileExists(atPath: customSoundsDir.path) {
            do {
                try fileManager.createDirectory(at: customSoundsDir, withIntermediateDirectories: true, attributes: nil)
                print("✅ 创建自定义音效目录")
            } catch {
                print("❌ 创建自定义音效目录失败: \(error)")
            }
        }
    }
    
    func importCustomSound(from url: URL) throws {
        let fileManager = FileManager.default
        
        let validExtensions = ["caf", "wav", "mp3", "m4a", "aiff", "aac"]
        guard validExtensions.contains(url.pathExtension.lowercased()) else {
            throw ImportError.invalidFileFormat
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        guard fileSize < 10 * 1024 * 1024 else {
            throw ImportError.fileTooLarge
        }
        
        let originalName = url.lastPathComponent
        let fileName = generateUniqueFileName(for: originalName)
        let destinationURL = userCustomSoundsURL.appendingPathComponent(fileName)
        
        try fileManager.copyItem(at: url, to: destinationURL)
        
        let soundName = originalName
            .replacingOccurrences(of: ".caf", with: "")
            .replacingOccurrences(of: ".wav", with: "")
            .replacingOccurrences(of: ".mp3", with: "")
            .replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: ".aiff", with: "")
            .replacingOccurrences(of: ".aac", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        
        let soundOption = SoundOption(
            id: "custom_\(UUID().uuidString)",
            name: soundName,
            type: .custom,
            soundFile: fileName,
            systemSoundID: nil,
            isUserCustom: true,
            isBuiltInCustom: false
        )
        
        userCustomSounds.append(soundOption)
        saveUserCustomSoundsList()
        
        print("✅ 成功导入自定义音效: \(soundName)")
        selectedSound = soundOption
        testSound(soundOption)
    }
    
    private func loadUserCustomSounds() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: userCustomSoundsURL.path) {
            return
        }
        
        if let savedData = UserDefaults.standard.array(forKey: userCustomSoundsKey) as? [[String: String]] {
            userCustomSounds = savedData.compactMap { dict in
                guard let id = dict["id"],
                      let name = dict["name"],
                      let soundFile = dict["soundFile"] else {
                    return nil
                }
                
                let fileURL = userCustomSoundsURL.appendingPathComponent(soundFile)
                if fileManager.fileExists(atPath: fileURL.path) {
                    return SoundOption(
                        id: id,
                        name: name,
                        type: .custom,
                        soundFile: soundFile,
                        systemSoundID: nil,
                        isUserCustom: true,
                        isBuiltInCustom: false
                    )
                }
                return nil
            }
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: userCustomSoundsURL, includingPropertiesForKeys: nil)
            let audioFiles = files.filter { ["caf", "wav", "mp3", "m4a", "aiff", "aac"].contains($0.pathExtension.lowercased()) }
            
            for fileURL in audioFiles {
                let fileName = fileURL.lastPathComponent
                
                if !userCustomSounds.contains(where: { $0.soundFile == fileName }) {
                    let soundName = fileName
                        .replacingOccurrences(of: ".caf", with: "")
                        .replacingOccurrences(of: ".wav", with: "")
                        .replacingOccurrences(of: ".mp3", with: "")
                        .replacingOccurrences(of: ".m4a", with: "")
                        .replacingOccurrences(of: ".aiff", with: "")
                        .replacingOccurrences(of: ".aac", with: "")
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                    
                    let soundOption = SoundOption(
                        id: "custom_\(UUID().uuidString)",
                        name: soundName,
                        type: .custom,
                        soundFile: fileName,
                        systemSoundID: nil,
                        isUserCustom: true,
                        isBuiltInCustom: false
                    )
                    userCustomSounds.append(soundOption)
                }
            }
            
            saveUserCustomSoundsList()
            
        } catch {
            print("❌ 扫描用户自定义音效失败: \(error)")
        }
    }
    
    private func saveUserCustomSoundsList() {
        let soundData = userCustomSounds.map { sound in
            [
                "id": sound.id,
                "name": sound.name,
                "soundFile": sound.soundFile ?? ""
            ]
        }
        UserDefaults.standard.set(soundData, forKey: userCustomSoundsKey)
    }
    
    private func generateUniqueFileName(for originalName: String) -> String {
        let fileManager = FileManager.default
        
        let destinationURL = userCustomSoundsURL.appendingPathComponent(originalName)
        if !fileManager.fileExists(atPath: destinationURL.path) {
            return originalName
        }
        
        let nameWithoutExtension = (originalName as NSString).deletingPathExtension
        let extensionName = (originalName as NSString).pathExtension
        let timestamp = Date().timeIntervalSince1970
        return "\(nameWithoutExtension)_\(Int(timestamp)).\(extensionName)"
    }
    
    func deleteCustomSound(_ sound: SoundOption) {
        guard sound.isUserCustom, let soundFile = sound.soundFile else { return }
        
        let fileManager = FileManager.default
        let soundURL = userCustomSoundsURL.appendingPathComponent(soundFile)
        
        do {
            try fileManager.removeItem(at: soundURL)
            userCustomSounds.removeAll { $0.id == sound.id }
            saveUserCustomSoundsList()
            
            if selectedSound?.id == sound.id {
                selectedSound = systemSoundOptions.first
            }
            
            print("✅ 删除自定义音效: \(sound.name)")
        } catch {
            print("❌ 删除自定义音效失败: \(error)")
        }
    }
    
    func getAllSounds() -> [SoundOption] {
        return availableSounds
    }
    
    func getSounds(in category: String) -> [SoundOption] {
        if category == "All" {
            return availableSounds
        } else if category == "System" {
            return systemSoundOptions
        } else if category == "Built-in" {
            return builtInCustomSounds
        } else if category == "Custom" {
            return userCustomSounds
        }
        return []
    }
    
    func searchSounds(query: String) -> [SoundOption] {
        let lowercasedQuery = query.lowercased()
        return availableSounds.filter { sound in
            sound.name.lowercased().contains(lowercasedQuery) ||
            sound.id.lowercased().contains(lowercasedQuery)
        }
    }
    
    func getCurrentSoundName() -> String {
        return selectedSound?.name ?? "Default"
    }
    
    func isSoundEnabled() -> Bool {
        return selectedSound?.systemSoundID != nil || selectedSound?.soundFile != nil
    }
    
    func refreshSoundOptions() {
        loadUserCustomSounds()
        print("🔄 UnifiedSoundManager 刷新音效选项")
    }
    
    func debugPrintSoundInfo() {
        print("=== 音效管理器调试信息 ===")
        print("选中的音效: \(selectedSound?.name ?? "无") (ID: \(selectedSound?.id ?? "无"))")
        print("选中的音效文件: \(selectedSound?.soundFile ?? "无")")
        print("用户自定义音效数量: \(userCustomSounds.count)")
        print("缓存音效ID数量: \(soundIDCache.count)")
        print("缓存AVAudioPlayer数量: \(audioPlayerCache.count)")
        
        // 检查内置音效文件是否存在
        for sound in builtInCustomSounds {
            if let fileName = sound.soundFile {
                let resourceName = fileName.replacingOccurrences(of: ".caf", with: "")
                if Bundle.main.url(forResource: resourceName, withExtension: "caf") != nil {
                    print("✅ 内置音效存在: \(fileName)")
                } else {
                    print("❌ 内置音效缺失: \(fileName)")
                }
            }
        }
    }
    
    var publicSystemSoundOptions: [SoundOption] {
        return systemSoundOptions
    }
    
    enum ImportError: LocalizedError {
        case invalidFileFormat
        case fileTooLarge
        
        var errorDescription: String? {
            switch self {
            case .invalidFileFormat:
                return "仅支持 .caf, .wav, .mp3, .m4a, .aiff, .aac 格式的音效文件"
            case .fileTooLarge:
                return "音效文件不能超过10MB"
            }
        }
    }
}
