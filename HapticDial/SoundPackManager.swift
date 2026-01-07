// Managers/SoundPackManager.swift - 完整整合版
import Foundation
import Combine
import Zip
import UniformTypeIdentifiers
import SwiftUI
import MobileCoreServices

class SoundPackManager: ObservableObject {
    static let shared = SoundPackManager()
    
    @Published var availablePacks: [SoundPack] = []
    @Published var installedSoundPacks: [SoundPack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isInstalling = false
    @Published var currentInstallation: String?
    
    // 内置音效模式（现在作为特殊的音效包）
    let builtInSoundModes: [SoundPack] = [
        SoundPack(
            id: "builtin_default",
            name: "默认模式",
            description: "系统默认声音",
            author: "系统",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "棘轮点击", fileName: "ratchet_click.caf"),
                Sound(id: UUID(), name: "光圈点击", fileName: "aperture_click.caf")
            ],
            soundFiles: ["ratchet_click.caf", "aperture_click.caf"]
        ),
        SoundPack(
            id: "builtin_mechanical",
            name: "机械模式",
            description: "经典机械声音效果",
            author: "系统",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "机械点击", fileName: "mechanical_click.caf"),
                Sound(id: UUID(), name: "机械滴答", fileName: "mechanical_tick.caf")
            ],
            soundFiles: ["mechanical_click.caf", "mechanical_tick.caf"]
        ),
        SoundPack(
            id: "builtin_digital",
            name: "数字模式",
            description: "清晰的数字提示音",
            author: "系统",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "数字蜂鸣", fileName: "digital_beep.caf"),
                Sound(id: UUID(), name: "数字音调", fileName: "digital_tone.caf")
            ],
            soundFiles: ["digital_beep.caf", "digital_tone.caf"]
        ),
        SoundPack(
            id: "builtin_natural",
            name: "自然模式",
            description: "自然水滴和木材声音",
            author: "系统",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "水滴声", fileName: "water_drop.caf"),
                Sound(id: UUID(), name: "木块敲击", fileName: "wood_tap.caf")
            ],
            soundFiles: ["water_drop.caf", "wood_tap.caf"]
        ),
        SoundPack(
            id: "builtin_futuristic",
            name: "未来模式",
            description: "科幻激光和能量声音",
            author: "系统",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "激光点击", fileName: "laser_click.caf"),
                Sound(id: UUID(), name: "合成滴答", fileName: "synth_tick.caf")
            ],
            soundFiles: ["laser_click.caf", "synth_tick.caf"]
        ),
        SoundPack(
            id: "builtin_silent",
            name: "静音模式",
            description: "仅触觉反馈，无声音",
            author: "系统",
            version: "1.0",
            sounds: [],
            soundFiles: []
        )
    ]
    
    private let fileManager = FileManager.default
    
    init() {
        loadAvailablePacks()
        loadInstalledSoundPacks()
    }
    
    // MARK: - 音效包管理
    
    func loadAvailablePacks() {
        isLoading = true
        errorMessage = nil
        
        // 从内置资源加载预置音效包
        let customBuiltInPacks = [
            SoundPack(
                id: "mechanical-pack",
                name: "机械音效包",
                description: "完整机械声音效果集",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "机械点击", fileName: "mechanical_click.caf"),
                    Sound(id: UUID(), name: "机械滴答", fileName: "mechanical_tick.caf"),
                    Sound(id: UUID(), name: "机械弹出", fileName: "mechanical_pop.caf"),
                    Sound(id: UUID(), name: "click", fileName: "mechanical_click.caf")
                ],
                soundFiles: ["mechanical_click.caf", "mechanical_tick.caf", "mechanical_pop.caf"]
            ),
            SoundPack(
                id: "digital-pack",
                name: "数字音效包",
                description: "完整数字提示音集",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "数字蜂鸣", fileName: "digital_beep.caf"),
                    Sound(id: UUID(), name: "数字音调", fileName: "digital_tone.caf"),
                    Sound(id: UUID(), name: "数字短音", fileName: "digital_blip.caf"),
                    Sound(id: UUID(), name: "click", fileName: "digital_beep.caf")
                ],
                soundFiles: ["digital_beep.caf", "digital_tone.caf", "digital_blip.caf"]
            ),
            SoundPack(
                id: "natural-pack",
                name: "自然音效包",
                description: "完整自然声音集",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "水滴声", fileName: "water_drop.caf"),
                    Sound(id: UUID(), name: "木块敲击", fileName: "wood_tap.caf"),
                    Sound(id: UUID(), name: "气泡破裂", fileName: "bubble_pop.caf"),
                    Sound(id: UUID(), name: "click", fileName: "water_drop.caf")
                ],
                soundFiles: ["water_drop.caf", "wood_tap.caf", "bubble_pop.caf"]
            ),
            SoundPack(
                id: "futuristic-pack",
                name: "未来音效包",
                description: "完整科幻声音集",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "激光点击", fileName: "laser_click.caf"),
                    Sound(id: UUID(), name: "合成滴答", fileName: "synth_tick.caf"),
                    Sound(id: UUID(), name: "能量弹出", fileName: "energy_pop.caf"),
                    Sound(id: UUID(), name: "click", fileName: "laser_click.caf")
                ],
                soundFiles: ["laser_click.caf", "synth_tick.caf", "energy_pop.caf"]
            )
        ]
        
        // 检查哪些音效包已经安装
        var enhancedPacks = customBuiltInPacks
        for i in 0..<enhancedPacks.count {
            if isSoundPackInstalled(enhancedPacks[i].id) {
                let updatedPack = SoundPack(
                    id: enhancedPacks[i].id,
                    name: enhancedPacks[i].name,
                    description: enhancedPacks[i].description,
                    author: enhancedPacks[i].author,
                    version: enhancedPacks[i].version,
                    sounds: enhancedPacks[i].sounds,
                    directoryURL: getInstalledPackDirectory(enhancedPacks[i].id),
                    soundFiles: enhancedPacks[i].soundFiles
                )
                enhancedPacks[i] = updatedPack
            }
        }
        
        // 整合内置模式和音效包
        let allPacks = builtInSoundModes + enhancedPacks
        
        DispatchQueue.main.async { [weak self] in
            self?.availablePacks = allPacks
            self?.isLoading = false
            print("📦 加载了 \(allPacks.count) 个可用音效包（包含 \(self?.builtInSoundModes.count ?? 0) 个内置模式）")
        }
    }
    
    func loadInstalledSoundPacks() {
        let installedPacksDirectory = getInstalledPacksDirectory()
        
        do {
            if fileManager.fileExists(atPath: installedPacksDirectory.path) {
                let contents = try fileManager.contentsOfDirectory(
                    at: installedPacksDirectory,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                
                var packs: [SoundPack] = []
                
                for url in contents {
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                    if resourceValues.isDirectory == true {
                        if let pack = try? loadSoundPack(from: url) {
                            packs.append(pack)
                        }
                    }
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.installedSoundPacks = packs
                    print("✅ 加载了 \(packs.count) 个已安装音效包")
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.installedSoundPacks = []
                }
            }
        } catch {
            print("❌ 加载已安装音效包失败: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.installedSoundPacks = []
                self?.errorMessage = "加载音效包失败: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 声音播放支持
    
    // 获取适合当前模式的声音名称
    func getSoundNameForCurrentMode(currentMode: DialMode, packId: String?) -> String {
        // 如果是内置模式，使用特定名称
        if let packId = packId, packId.hasPrefix("builtin_") {
            switch packId {
            case "builtin_default":
                return currentMode == .ratchet ? "ratchet_click" : "aperture_click"
            case "builtin_mechanical":
                return currentMode == .ratchet ? "mechanical_click" : "mechanical_tick"
            case "builtin_digital":
                return currentMode == .ratchet ? "digital_beep" : "digital_tone"
            case "builtin_natural":
                return "water_drop"
            case "builtin_futuristic":
                return "laser_click"
            case "builtin_silent":
                return "" // 静音模式
            default:
                return "click"
            }
        }
        
        // 对于自定义音效包，总是使用 click 或第一个声音
        return "click"
    }
    
    // 获取声音文件的通用方法
    func getSoundFileURL(forSoundPack packId: String, soundName: String, currentMode: DialMode? = nil) -> URL? {
        // 如果是内置模式，从 Bundle 获取
        if packId.hasPrefix("builtin_") {
            // 获取适合当前模式的声音名称
            let effectiveSoundName: String
            if let currentMode = currentMode {
                effectiveSoundName = getSoundNameForCurrentMode(currentMode: currentMode, packId: packId)
            } else {
                effectiveSoundName = soundName
            }
            
            // 静音模式返回 nil
            if packId == "builtin_silent" || effectiveSoundName.isEmpty {
                return nil
            }
            
            // 尝试各种可能的扩展名
            let possibleExtensions = ["caf", "wav", "mp3", "m4a"]
            
            for ext in possibleExtensions {
                if let path = Bundle.main.path(forResource: effectiveSoundName, ofType: ext) {
                    return URL(fileURLWithPath: path)
                }
            }
            
            // 尝试通过 AudioResources 获取
            if let url = AudioResources.shared.getAudioURL(for: effectiveSoundName) {
                return url
            }
            
            print("⚠️ 未找到内置声音文件: \(effectiveSoundName)")
            return nil
        }
        
        // 对于自定义音效包
        guard let pack = installedSoundPacks.first(where: { $0.id == packId }),
              let directoryURL = pack.directoryURL else {
            print("❌ 未找到声音包或目录: \(packId)")
            return nil
        }
        
        // 首先尝试直接匹配文件名
        let directURL = directoryURL.appendingPathComponent(soundName)
        if fileManager.fileExists(atPath: directURL.path) {
            return directURL
        }
        
        // 尝试各种可能的扩展名
        let possibleExtensions = ["caf", "wav", "mp3", "m4a", "aac"]
        
        for ext in possibleExtensions {
            let fileURL = directoryURL.appendingPathComponent("\(soundName).\(ext)")
            if fileManager.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        
        // 尝试在声音列表中查找
        for sound in pack.sounds {
            if sound.name.lowercased() == soundName.lowercased() {
                let fileURL = directoryURL.appendingPathComponent(sound.fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }
        
        // 尝试部分匹配
        for sound in pack.sounds {
            if sound.name.lowercased().contains(soundName.lowercased()) {
                let fileURL = directoryURL.appendingPathComponent(sound.fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }
        
        // 如果没有找到特定声音，尝试使用第一个声音
        if let firstSound = pack.sounds.first {
            let fileURL = directoryURL.appendingPathComponent(firstSound.fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                print("🔄 使用第一个声音作为替代: \(firstSound.name)")
                return fileURL
            }
        }
        
        print("❌ 在声音包 \(packId) 中未找到声音: \(soundName)")
        return nil
    }
    
    // 验证音效包
    func validateSoundPack(_ packId: String) -> Bool {
        // 内置模式总是有效
        if packId.hasPrefix("builtin_") {
            return true
        }
        
        guard let pack = installedSoundPacks.first(where: { $0.id == packId }) else {
            print("⚠️ 音效包不存在: \(packId)")
            return false
        }
        
        // 检查是否至少有一个声音文件
        if pack.sounds.isEmpty {
            print("⚠️ 音效包 \(pack.name) 中没有声音文件")
            return false
        }
        
        // 检查目录是否存在
        guard let directoryURL = pack.directoryURL else {
            print("⚠️ 音效包 \(pack.name) 目录不存在")
            return false
        }
        
        // 检查至少一个声音文件是否存在
        for sound in pack.sounds {
            let fileURL = directoryURL.appendingPathComponent(sound.fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                return true
            }
        }
        
        print("⚠️ 音效包 \(pack.name) 中没有有效的声音文件")
        return false
    }
    
    // 获取所有选项（内置模式 + 自定义音效包）
    func getAllOptions() -> [SoundPack] {
        return availablePacks
    }
    
    // 判断是否是内置模式
    func isBuiltInMode(_ packId: String) -> Bool {
        return packId.hasPrefix("builtin_")
    }
    
    // 获取内置模式名称
    func getBuiltInModeName(_ packId: String) -> String {
        return builtInSoundModes.first(where: { $0.id == packId })?.name ?? packId
    }
    
    // 获取当前选择的人类可读名称
    func getCurrentSelectionName(_ packId: String?) -> String {
        guard let packId = packId else {
            return "未选择"
        }
        
        if let pack = availablePacks.first(where: { $0.id == packId }) {
            return pack.name
        }
        
        return packId
    }
    
    // 检查音效包是否已安装
    func isSoundPackInstalled(_ packId: String) -> Bool {
        return installedSoundPacks.contains { $0.id == packId }
    }
    
    // MARK: - 安装功能
    
    func installSoundPack(_ packId: String) async throws -> SoundPack {
        print("📥 开始安装音效包: \(packId)")
        
        DispatchQueue.main.async {
            self.isInstalling = true
            self.currentInstallation = packId
        }
        
        defer {
            DispatchQueue.main.async {
                self.isInstalling = false
                self.currentInstallation = nil
            }
        }
        
        // 查找音效包（排除内置模式）
        guard let pack = availablePacks.first(where: { $0.id == packId && !isBuiltInMode(packId) }) else {
            throw NSError(domain: "SoundPackManager", code: 100,
                         userInfo: [NSLocalizedDescriptionKey: "未找到音效包: \(packId)"])
        }
        
        // 如果已经安装，直接返回
        if isSoundPackInstalled(packId) {
            print("📦 音效包已经安装: \(pack.name)")
            return pack
        }
        
        let packsDirectory = getInstalledPacksDirectory()
        let packDirectory = packsDirectory.appendingPathComponent(packId)
        
        // 创建目录
        do {
            if fileManager.fileExists(atPath: packDirectory.path) {
                try fileManager.removeItem(at: packDirectory)
            }
            try fileManager.createDirectory(at: packDirectory, withIntermediateDirectories: true)
        } catch {
            throw NSError(domain: "SoundPackManager", code: 101,
                         userInfo: [NSLocalizedDescriptionKey: "创建目录失败: \(error.localizedDescription)"])
        }
        
        // 复制声音文件
        if let soundFiles = pack.soundFiles {
            for soundFile in soundFiles {
                let soundName = soundFile.replacingOccurrences(of: ".caf", with: "")
                    .replacingOccurrences(of: ".wav", with: "")
                    .replacingOccurrences(of: ".mp3", with: "")
                    .replacingOccurrences(of: ".m4a", with: "")
                
                if let audioResourcesURL = AudioResources.shared.getAudioURL(for: soundName) {
                    let destURL = packDirectory.appendingPathComponent(soundFile)
                    do {
                        try fileManager.copyItem(at: audioResourcesURL, to: destURL)
                        print("✅ 复制文件: \(soundFile)")
                    } catch {
                        print("⚠️ 复制文件失败 \(soundFile): \(error)")
                    }
                }
            }
        }
        
        // 保存manifest.json
        let manifestURL = packDirectory.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let installedPack = SoundPack(
            id: pack.id,
            name: pack.name,
            description: pack.description,
            author: pack.author,
            version: pack.version,
            sounds: pack.sounds,
            directoryURL: packDirectory,
            soundFiles: pack.soundFiles
        )
        
        do {
            let data = try encoder.encode(installedPack)
            try data.write(to: manifestURL)
            print("✅ 保存manifest.json")
        } catch {
            print("⚠️ 保存manifest.json失败: \(error)")
        }
        
        // 更新已安装列表
        DispatchQueue.main.async { [weak self] in
            self?.loadInstalledSoundPacks()
            self?.loadAvailablePacks()
        }
        
        // 通知相关管理器刷新声音缓存
        notifyManagersOfSoundPackUpdate()
        
        print("🎉 音效包安装成功: \(pack.name)")
        
        return installedPack
    }
    
    // MARK: - 加载音效包
    func loadSoundPack(from directory: URL) throws -> SoundPack {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw NSError(domain: "SoundPackManager", code: 200,
                         userInfo: [NSLocalizedDescriptionKey: "manifest.json 文件不存在"])
        }
        
        do {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            var pack = try decoder.decode(SoundPack.self, from: data)
            pack.directoryURL = directory
            return pack
        } catch {
            throw NSError(domain: "SoundPackManager", code: 201,
                         userInfo: [NSLocalizedDescriptionKey: "解析manifest.json失败: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - 文件管理
    
    private func getInstalledPackDirectory(_ packId: String) -> URL {
        return getInstalledPacksDirectory().appendingPathComponent(packId)
    }
    
    private func getInstalledPacksDirectory() -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let packsDirectory = documentsDirectory.appendingPathComponent("SoundPacks")
        
        if !fileManager.fileExists(atPath: packsDirectory.path) {
            do {
                try fileManager.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
                print("📁 创建音效包目录: \(packsDirectory.path)")
            } catch {
                print("❌ 创建音效包目录失败: \(error)")
            }
        }
        
        return packsDirectory
    }
    
    // 通知相关管理器音效包已更新
    private func notifyManagersOfSoundPackUpdate() {
        // 清理 HapticManager 中的音频播放器缓存
        HapticManager.shared.cleanup()
        
        // 通知 UnifiedSoundManager 重新加载用户自定义音效
        // 注意：由于 UnifiedSoundManager 没有 refreshSoundOptions 方法，
        // 我们改为调用 loadUserCustomSounds（如果它是公开的）或重新触发加载
        // 如果无法直接调用，我们可以通过 UserDefaults 通知或其他方式
        // 这里我们暂时注释掉，因为 UnifiedSoundManager 会自动重新加载
        print("🔊 通知所有管理器音效包已更新")
        
        // 我们可以发送一个通知，让其他观察者知道音效包已更新
        NotificationCenter.default.post(name: NSNotification.Name("SoundPacksUpdated"), object: nil)
    }
    
    // 支持的文件类型
    static var supportedAudioUTIs: [UTType] {
        return [
            UTType(filenameExtension: "mp3")!,
            UTType(filenameExtension: "wav")!,
            UTType(filenameExtension: "m4a")!,
            UTType(filenameExtension: "caf")!,
            UTType(filenameExtension: "aac")!,
            UTType.audio
        ]
    }
}
