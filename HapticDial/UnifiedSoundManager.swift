import Foundation
import AudioToolbox
import Combine

class UnifiedSoundManager: ObservableObject {
    static let shared = UnifiedSoundManager()
    
    // 音效类型
    enum SoundType: String, Codable {
        case system
        case custom
    }
    
    // 音效选项 - 需要遵循 Codable
    struct SoundOption: Identifiable, Equatable, Codable {
        let id: String
        let name: String
        let type: SoundType
        let soundFile: String?
        let systemSoundID: UInt32?
        var isUserCustom: Bool = false
        
        // 🔴 新增：标识是否是内置的自定义音效
        var isBuiltInCustom: Bool = false
        
        // 计算属性，用于 UI 显示
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
        
        // 获取首字母
        var firstLetter: String {
            if name.isEmpty { return "?" }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(1)).uppercased()
        }
        
        static func == (lhs: SoundOption, rhs: SoundOption) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    // 系统默认音效选项 - 改为英文名称
    private let systemSoundOptions: [SoundOption] = [
        SoundOption(id: "system_default", name: "Default", type: .system, soundFile: nil, systemSoundID: 1104),
        SoundOption(id: "system_tick", name: "Tick", type: .system, soundFile: nil, systemSoundID: 1103),
        SoundOption(id: "system_click", name: "Click", type: .system, soundFile: nil, systemSoundID: 1100),
        SoundOption(id: "system_beep", name: "Beep", type: .system, soundFile: nil, systemSoundID: 1110),
        SoundOption(id: "system_bell", name: "Bell", type: .system, soundFile: nil, systemSoundID: 1005),
        SoundOption(id: "none", name: "Mute", type: .system, soundFile: nil, systemSoundID: nil)
    ]
    
    // 🔴 新增：内置自定义音效
    private let builtInCustomSounds: [SoundOption] = [
        SoundOption(id: "builtin_large_bell", name: "Large Bell", type: .custom,
                   soundFile: "Budda_large_bell.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true),
        SoundOption(id: "builtin_small_bell", name: "Small Bell", type: .custom,
                   soundFile: "Budda_small_bell.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true),
        SoundOption(id: "builtin_sword", name: "Sword", type: .custom,
                   soundFile: "sword.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true),
        SoundOption(id: "builtin_ikkyu_san", name: "Ikkyu San", type: .custom,
                   soundFile: "Ikkyu_san.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true),
        SoundOption(id: "builtin_knife", name: "Knife", type: .custom,
                   soundFile: "knife.caf", systemSoundID: nil, isUserCustom: false, isBuiltInCustom: true)
    ]
    
    // 用户自定义音效
    @Published var userCustomSounds: [SoundOption] = []
    
    // 选中的音效
    @Published var selectedSound: SoundOption? {
        didSet {
            if let sound = selectedSound {
                saveSelectedSound(sound)
            }
        }
    }
    
    // 🔴 新增：声音ID缓存，解决播放不完整问题
    private var soundIDCache: [String: SystemSoundID] = [:]
    
    // MARK: - 公开的属性
    
    var availableSounds: [SoundOption] {
        var allSounds = systemSoundOptions
        // 🔴 将内置自定义音效添加到系统音效后面
        allSounds.append(contentsOf: builtInCustomSounds)
        // 🔴 用户自定义音效放在最后
        allSounds.append(contentsOf: userCustomSounds)
        return allSounds
    }
    
    var categories: [String] {
        var categories = ["All"]
        categories.append("System")
        if !builtInCustomSounds.isEmpty {
            categories.append("Built-in") // 🔴 新增内置音效分类
        }
        if !userCustomSounds.isEmpty {
            categories.append("Custom")
        }
        return categories
    }
    
    // MARK: - 用户自定义音效目录
    private var userCustomSoundsURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("CustomSounds")
    }
    
    // UserDefaults 键
    private let selectedSoundKey = "unified_selected_sound"
    private let userCustomSoundsKey = "user_custom_sounds_list"
    
    private init() {
        loadSelectedSound()
        loadUserCustomSounds()
        ensureCustomSoundsDirectory()
    }
    
    // MARK: - 音效选择
    
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
    
    // MARK: - 音效播放
    
    func playSound(_ sound: SoundOption) {
        if let systemSoundID = sound.systemSoundID {
            AudioServicesPlaySystemSound(systemSoundID)
        } else if let soundFile = sound.soundFile {
            var soundURL: URL
            
            // 🔴 区分内置自定义音效和用户自定义音效
            if sound.isBuiltInCustom {
                // 内置音效从app bundle中加载
                if let bundleURL = Bundle.main.url(forResource: soundFile, withExtension: nil) {
                    soundURL = bundleURL
                } else {
                    print("❌ Built-in sound file not found: \(soundFile)")
                    return
                }
            } else {
                // 用户自定义音效从文档目录加载
                soundURL = userCustomSoundsURL.appendingPathComponent(soundFile)
            }
            
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: soundURL.path) else {
                print("❌ Sound file not found at: \(soundURL.path)")
                return
            }
            
            let cacheKey = soundFile + (sound.isBuiltInCustom ? "_builtin" : "_custom")
            
            // 🔴 使用缓存的声音ID，避免播放不完整
            if let cachedSoundID = soundIDCache[cacheKey] {
                AudioServicesPlaySystemSound(cachedSoundID)
                print("✅ Using cached sound ID for: \(soundFile)")
            } else {
                var soundID: SystemSoundID = 0
                let status = AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
                
                if status == noErr {
                    // 🔴 缓存声音ID，不要立即释放
                    soundIDCache[cacheKey] = soundID
                    AudioServicesPlaySystemSound(soundID)
                    print("✅ Created and cached sound ID for: \(soundFile)")
                } else {
                    print("❌ Failed to create system sound ID for: \(soundFile), error: \(status)")
                }
            }
        }
    }
    
    // 🔴 添加清理缓存的方法
    func clearSoundCache() {
        for (_, soundID) in soundIDCache {
            AudioServicesDisposeSystemSoundID(soundID)
        }
        soundIDCache.removeAll()
        print("✅ Cleared sound cache")
    }
    
    // 🔴 在deinit中清理资源
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
                print("✅ Custom sounds directory created")
            } catch {
                print("❌ Failed to create custom sounds directory: \(error)")
            }
        }
    }
    
    func importCustomSound(from url: URL) throws {
        let fileManager = FileManager.default
        
        // 检查文件扩展名 - 放宽限制，支持常见音频格式
        let validExtensions = ["caf", "wav", "mp3", "m4a", "aiff"]
        guard validExtensions.contains(url.pathExtension.lowercased()) else {
            throw ImportError.invalidFileFormat
        }
        
        // 检查文件大小（限制为5MB）
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        guard fileSize < 5 * 1024 * 1024 else {
            throw ImportError.fileTooLarge
        }
        
        // 获取文件名
        let originalName = url.lastPathComponent
        let fileName = generateUniqueFileName(for: originalName)
        let destinationURL = userCustomSoundsURL.appendingPathComponent(fileName)
        
        // 复制文件到应用目录
        try fileManager.copyItem(at: url, to: destinationURL)
        
        // 获取音效名称（移除扩展名）
        let soundName = originalName.replacingOccurrences(of: ".caf", with: "")
            .replacingOccurrences(of: ".wav", with: "")
            .replacingOccurrences(of: ".mp3", with: "")
            .replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: ".aiff", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        
        // 创建音效选项
        let soundOption = SoundOption(
            id: "custom_\(UUID().uuidString)",
            name: soundName,
            type: .custom,
            soundFile: fileName,
            systemSoundID: nil,
            isUserCustom: true,
            isBuiltInCustom: false // 🔴 用户自定义音效不是内置的
        )
        
        // 添加到列表
        userCustomSounds.append(soundOption)
        saveUserCustomSoundsList()
        
        print("✅ Successfully imported custom sound: \(soundName)")
        
        // 自动选择新导入的音效
        selectedSound = soundOption
    }
    
    private func loadUserCustomSounds() {
        let fileManager = FileManager.default
        
        // 确保目录存在
        if !fileManager.fileExists(atPath: userCustomSoundsURL.path) {
            return
        }
        
        // 加载保存的列表
        if let savedData = UserDefaults.standard.array(forKey: userCustomSoundsKey) as? [[String: String]] {
            userCustomSounds = savedData.compactMap { dict in
                guard let id = dict["id"],
                      let name = dict["name"],
                      let soundFile = dict["soundFile"] else {
                    return nil
                }
                
                // 检查文件是否存在
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
        
        // 扫描目录中的文件（备用方法）
        do {
            let files = try fileManager.contentsOfDirectory(at: userCustomSoundsURL, includingPropertiesForKeys: nil)
            let audioFiles = files.filter { ["caf", "wav", "mp3", "m4a", "aiff"].contains($0.pathExtension.lowercased()) }
            
            for fileURL in audioFiles {
                let fileName = fileURL.lastPathComponent
                
                // 如果还没有在列表中，添加它
                if !userCustomSounds.contains(where: { $0.soundFile == fileName }) {
                    let soundName = fileName.replacingOccurrences(of: ".caf", with: "")
                        .replacingOccurrences(of: ".wav", with: "")
                        .replacingOccurrences(of: ".mp3", with: "")
                        .replacingOccurrences(of: ".m4a", with: "")
                        .replacingOccurrences(of: ".aiff", with: "")
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
            
            // 保存更新后的列表
            saveUserCustomSoundsList()
            
        } catch {
            print("❌ Failed to scan user custom sounds: \(error)")
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
        
        // 如果文件名不冲突，直接使用
        let destinationURL = userCustomSoundsURL.appendingPathComponent(originalName)
        if !fileManager.fileExists(atPath: destinationURL.path) {
            return originalName
        }
        
        // 如果冲突，添加时间戳
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
            // 删除文件
            try fileManager.removeItem(at: soundURL)
            
            // 从列表中移除
            userCustomSounds.removeAll { $0.id == sound.id }
            saveUserCustomSoundsList()
            
            // 如果删除的是当前选中的音效，切换到默认音效
            if selectedSound?.id == sound.id {
                selectedSound = systemSoundOptions.first
            }
            
            print("✅ Deleted custom sound: \(sound.name)")
        } catch {
            print("❌ Failed to delete custom sound: \(error)")
        }
    }
    
    // MARK: - 获取音效
    
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
        print("🔄 UnifiedSoundManager refreshed sound options")
    }
    
    // MARK: - 错误类型
    
    enum ImportError: LocalizedError {
        case invalidFileFormat
        case fileTooLarge
        
        var errorDescription: String? {
            switch self {
            case .invalidFileFormat:
                return "Only .caf, .wav, .mp3, .m4a, .aiff format sound files are supported"
            case .fileTooLarge:
                return "Sound file cannot exceed 5MB"
            }
        }
    }
    
    // MARK: - 为 HorizontalSoundPicker 提供的公共访问方法
    
    var publicSystemSoundOptions: [SoundOption] {
        return systemSoundOptions
    }
}
