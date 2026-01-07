// Managers/SoundPackManager.swift - 完整修复版 + 上传功能
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
        let builtInPacks = [
            SoundPack(
                id: "mechanical-pack",
                name: "机械音效包",
                description: "经典机械声音效果",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "机械点击", fileName: "mechanical_click.caf"),
                    Sound(id: UUID(), name: "机械滴答", fileName: "mechanical_tick.caf"),
                    Sound(id: UUID(), name: "机械弹出", fileName: "mechanical_pop.caf")
                ],
                soundFiles: ["mechanical_click.caf", "mechanical_tick.caf", "mechanical_pop.caf"]
            ),
            SoundPack(
                id: "digital-pack",
                name: "数字音效包",
                description: "清晰的数字提示音",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "数字蜂鸣", fileName: "digital_beep.caf"),
                    Sound(id: UUID(), name: "数字音调", fileName: "digital_tone.caf"),
                    Sound(id: UUID(), name: "数字短音", fileName: "digital_blip.caf")
                ],
                soundFiles: ["digital_beep.caf", "digital_tone.caf", "digital_blip.caf"]
            ),
            SoundPack(
                id: "natural-pack",
                name: "自然音效包",
                description: "自然水滴和木材声音",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "水滴声", fileName: "water_drop.caf"),
                    Sound(id: UUID(), name: "木块敲击", fileName: "wood_tap.caf"),
                    Sound(id: UUID(), name: "气泡破裂", fileName: "bubble_pop.caf")
                ],
                soundFiles: ["water_drop.caf", "wood_tap.caf", "bubble_pop.caf"]
            ),
            SoundPack(
                id: "futuristic-pack",
                name: "未来音效包",
                description: "科幻激光和能量声音",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "激光点击", fileName: "laser_click.caf"),
                    Sound(id: UUID(), name: "合成滴答", fileName: "synth_tick.caf"),
                    Sound(id: UUID(), name: "能量弹出", fileName: "energy_pop.caf")
                ],
                soundFiles: ["laser_click.caf", "synth_tick.caf", "energy_pop.caf"]
            )
        ]
        
        // 检查哪些音效包已经安装
        var enhancedPacks = builtInPacks
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
        
        DispatchQueue.main.async { [weak self] in
            self?.availablePacks = enhancedPacks
            self?.isLoading = false
            print("📦 加载了 \(enhancedPacks.count) 个可用音效包")
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
    
    func loadSoundPack(from directoryURL: URL) throws -> SoundPack {
        let manifestURL = directoryURL.appendingPathComponent("manifest.json")
        
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw NSError(domain: "SoundPackManager", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "找不到 manifest.json 文件"])
        }
        
        do {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            
            var pack = try decoder.decode(SoundPack.self, from: data)
            pack.directoryURL = directoryURL
            
            // 加载实际的声音文件
            var actualSounds: [Sound] = []
            let soundFiles = try fileManager.contentsOfDirectory(at: directoryURL,
                                                               includingPropertiesForKeys: nil,
                                                               options: [.skipsHiddenFiles])
            
            for fileURL in soundFiles {
                let fileExtension = fileURL.pathExtension.lowercased()
                if SoundPack.supportedAudioExtensions.contains(fileExtension) {
                    let fileName = fileURL.lastPathComponent
                    let soundName = fileURL.deletingPathExtension().lastPathComponent
                    let sound = Sound(id: UUID(), name: soundName, fileName: fileName)
                    actualSounds.append(sound)
                }
            }
            
            pack.sounds = actualSounds
            
            return pack
        } catch {
            throw NSError(domain: "SoundPackManager", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "解析 manifest.json 失败: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - 音效上传功能
    
    func createCustomSoundPackWithSounds(name: String, description: String = "", soundURLs: [URL]) async throws -> SoundPack {
        print("📦 创建自定义音效包: \(name)")
        
        // 创建音效包
        let pack = try createSoundPack(name: name, description: description, author: "用户")
        
        // 添加音效文件
        for soundURL in soundURLs {
            do {
                let sound = try addSound(to: pack, soundURL: soundURL)
                print("✅ 添加音效: \(sound.name)")
            } catch {
                print("⚠️ 添加音效失败: \(error)")
                // 继续添加其他文件
            }
        }
        
        // 刷新列表
        refreshAll()
        
        return pack
    }
    
    func uploadSoundToExistingPack(_ packId: String, soundURL: URL) async throws -> Sound {
        guard let pack = installedSoundPacks.first(where: { $0.id == packId }) else {
            throw NSError(domain: "SoundPackManager", code: 102, userInfo: [NSLocalizedDescriptionKey: "未找到音效包"])
        }
        
        let sound = try addSound(to: pack, soundURL: soundURL)
        refreshAll()
        
        return sound
    }
    
    // 添加这个方法用于获取支持的文件类型
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
    
    // MARK: - 安装功能（修复安装无响应问题）
    
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
        
        // 查找音效包
        guard let pack = availablePacks.first(where: { $0.id == packId }) else {
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
        
        // 获取所有需要的音频文件URL
        var soundFilesToCopy: [(sourceURL: URL, destinationName: String)] = []
        
        if let soundFiles = pack.soundFiles {
            for soundFile in soundFiles {
                let soundName = soundFile.replacingOccurrences(of: ".caf", with: "")
                    .replacingOccurrences(of: ".wav", with: "")
                    .replacingOccurrences(of: ".mp3", with: "")
                    .replacingOccurrences(of: ".m4a", with: "")
                
                // 1. 首先尝试从AudioResources获取
                if let audioResourcesURL = AudioResources.shared.getAudioURL(for: soundName) {
                    let destURL = packDirectory.appendingPathComponent(soundFile)
                    soundFilesToCopy.append((audioResourcesURL, soundFile))
                } else {
                    print("⚠️ 在AudioResources中未找到声音文件: \(soundName)")
                }
            }
        }
        
        // 复制所有文件
        for (sourceURL, fileName) in soundFilesToCopy {
            let destURL = packDirectory.appendingPathComponent(fileName)
            do {
                try fileManager.copyItem(at: sourceURL, to: destURL)
                print("✅ 复制文件: \(fileName)")
            } catch {
                print("⚠️ 复制文件失败 \(fileName): \(error)")
                // 继续复制其他文件
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
            // 即使manifest保存失败，也不视为完全失败
        }
        
        // 更新已安装列表
        DispatchQueue.main.async { [weak self] in
            self?.loadInstalledSoundPacks()
            self?.loadAvailablePacks() // 刷新可用列表状态
        }
        
        // 通知HapticManager刷新
        DispatchQueue.main.async {
            HapticManager.shared.refreshSoundPacks()
        }
        
        print("🎉 音效包安装成功: \(pack.name)")
        
        return installedPack
    }
    
    // 一键安装所有内置音效包
    func installAllBuiltInPacks() async -> [SoundPack] {
        var installedPacks: [SoundPack] = []
        
        for pack in availablePacks {
            if !isSoundPackInstalled(pack.id) {
                do {
                    let installedPack = try await installSoundPack(pack.id)
                    installedPacks.append(installedPack)
                    // 稍微延迟，避免过快
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                } catch {
                    print("⚠️ 安装音效包失败 \(pack.name): \(error)")
                }
            }
        }
        
        return installedPacks
    }
    
    func isSoundPackInstalled(_ packId: String) -> Bool {
        let packDirectory = getInstalledPackDirectory(packId)
        let manifestURL = packDirectory.appendingPathComponent("manifest.json")
        return fileManager.fileExists(atPath: manifestURL.path)
    }
    
    private func getInstalledPackDirectory(_ packId: String) -> URL {
        return getInstalledPacksDirectory().appendingPathComponent(packId)
    }
    
    // MARK: - Zip 相关功能
    
    func importSoundPack(from zipURL: URL) async throws -> SoundPack {
        print("📦 导入音效包: \(zipURL.lastPathComponent)")
        
        let packsDirectory = getInstalledPacksDirectory()
        let unzipDirectory = packsDirectory.appendingPathComponent(UUID().uuidString)
        
        // 解压 ZIP 文件
        do {
            try Zip.unzipFile(zipURL, destination: unzipDirectory, overwrite: true, password: nil, progress: nil)
            print("✅ 解压成功: \(unzipDirectory.path)")
        } catch {
            throw NSError(domain: "SoundPackManager", code: 7,
                         userInfo: [NSLocalizedDescriptionKey: "解压失败: \(error.localizedDescription)"])
        }
        
        // 加载音效包
        let pack = try loadSoundPack(from: unzipDirectory)
        
        // 更新已安装列表
        loadInstalledSoundPacks()
        loadAvailablePacks()
        
        return pack
    }
    
    func exportSoundPack(_ pack: SoundPack) throws -> URL {
        guard let packDirectory = pack.directoryURL else {
            throw NSError(domain: "SoundPackManager", code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "音效包目录不存在"])
        }
        
        let tempDirectory = try fileManager.url(for: .itemReplacementDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: packDirectory,
                                               create: true)
        
        let zipFileName = "\(pack.name.replacingOccurrences(of: " ", with: "_")).hapticpack"
        let zipFileURL = tempDirectory.appendingPathComponent(zipFileName)
        
        // 使用 Zip 库压缩文件
        do {
            try Zip.zipFiles(paths: [packDirectory], zipFilePath: zipFileURL, password: nil, progress: nil)
            print("✅ 压缩成功: \(zipFileURL.path)")
            return zipFileURL
        } catch {
            throw NSError(domain: "SoundPackManager", code: 8,
                         userInfo: [NSLocalizedDescriptionKey: "压缩失败: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - 文件管理
    
    func deleteSoundPack(_ pack: SoundPack) throws {
        guard let directoryURL = pack.directoryURL else {
            throw NSError(domain: "SoundPackManager", code: 4,
                         userInfo: [NSLocalizedDescriptionKey: "音效包目录不存在"])
        }
        
        do {
            try fileManager.removeItem(at: directoryURL)
            
            // 从列表中移除
            if let index = installedSoundPacks.firstIndex(where: { $0.id == pack.id }) {
                installedSoundPacks.remove(at: index)
            }
            
            // 刷新可用列表
            loadAvailablePacks()
            
            print("🗑️ 删除音效包: \(pack.name)")
        } catch {
            throw NSError(domain: "SoundPackManager", code: 9,
                         userInfo: [NSLocalizedDescriptionKey: "删除失败: \(error.localizedDescription)"])
        }
    }
    
    func createSoundPack(name: String, description: String = "", author: String = "") throws -> SoundPack {
        let packsDirectory = getInstalledPacksDirectory()
        let packDirectory = packsDirectory.appendingPathComponent(UUID().uuidString)
        
        try fileManager.createDirectory(at: packDirectory, withIntermediateDirectories: true)
        
        let pack = SoundPack(
            id: UUID().uuidString,
            name: name,
            description: description,
            author: author,
            version: "1.0.0",
            sounds: []
        )
        
        // 保存 manifest.json
        let manifestURL = packDirectory.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(pack)
            try data.write(to: manifestURL)
        } catch {
            throw NSError(domain: "SoundPackManager", code: 10,
                         userInfo: [NSLocalizedDescriptionKey: "创建manifest失败: \(error.localizedDescription)"])
        }
        
        let mutablePack = SoundPack(
            id: pack.id,
            name: pack.name,
            description: pack.description,
            author: pack.author,
            version: pack.version,
            sounds: pack.sounds,
            directoryURL: packDirectory,
            soundFiles: pack.soundFiles
        )
        
        // 添加到列表
        installedSoundPacks.append(mutablePack)
        installedSoundPacks.sort { $0.name < $1.name }
        
        print("📁 创建新音效包: \(name)")
        
        return mutablePack
    }
    
    func addSound(to pack: SoundPack, soundURL: URL) throws -> Sound {
        guard let packDirectory = pack.directoryURL else {
            throw NSError(domain: "SoundPackManager", code: 5,
                         userInfo: [NSLocalizedDescriptionKey: "音效包目录不存在"])
        }
        
        let fileName = soundURL.lastPathComponent
        let destinationURL = packDirectory.appendingPathComponent(fileName)
        
        do {
            // 复制文件到音效包目录
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: soundURL, to: destinationURL)
            
            let sound = Sound(
                id: UUID(),
                name: soundURL.deletingPathExtension().lastPathComponent,
                fileName: fileName
            )
            
            // 更新音效包
            if let index = installedSoundPacks.firstIndex(where: { $0.id == pack.id }) {
                var updatedPack = installedSoundPacks[index]
                updatedPack.sounds.append(sound)
                installedSoundPacks[index] = updatedPack
                
                // 保存更新的 manifest
                let manifestURL = packDirectory.appendingPathComponent("manifest.json")
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(updatedPack)
                try data.write(to: manifestURL)
            }
            
            print("🔊 添加音效: \(sound.name) 到 \(pack.name)")
            
            return sound
        } catch {
            throw NSError(domain: "SoundPackManager", code: 11,
                         userInfo: [NSLocalizedDescriptionKey: "添加音效失败: \(error.localizedDescription)"])
        }
    }
    
    func removeSound(from pack: SoundPack, sound: Sound) throws {
        guard let packDirectory = pack.directoryURL else {
            throw NSError(domain: "SoundPackManager", code: 6,
                         userInfo: [NSLocalizedDescriptionKey: "音效包目录不存在"])
        }
        
        let soundFileURL = packDirectory.appendingPathComponent(sound.fileName)
        
        do {
            // 删除文件
            if fileManager.fileExists(atPath: soundFileURL.path) {
                try fileManager.removeItem(at: soundFileURL)
            }
            
            // 更新音效包
            if let index = installedSoundPacks.firstIndex(where: { $0.id == pack.id }) {
                var updatedPack = installedSoundPacks[index]
                updatedPack.sounds.removeAll { $0.id == sound.id }
                installedSoundPacks[index] = updatedPack
                
                // 保存更新的 manifest
                let manifestURL = packDirectory.appendingPathComponent("manifest.json")
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(updatedPack)
                try data.write(to: manifestURL)
            }
            
            print("🗑️ 从 \(pack.name) 中移除音效: \(sound.name)")
        } catch {
            throw NSError(domain: "SoundPackManager", code: 12,
                         userInfo: [NSLocalizedDescriptionKey: "移除音效失败: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - 目录管理
    
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
    
    // MARK: - 辅助方法
    
    func getSoundFileURL(forSoundPack packId: String, soundName: String) -> URL? {
        // 如果是内置音效包，从Bundle中获取
        if packId.hasPrefix("builtin_") {
            return getBuiltInSoundURL(soundName)
        }
        
        // 否则从自定义音效包中获取
        guard let pack = installedSoundPacks.first(where: { $0.id == packId }),
              let directoryURL = pack.directoryURL else {
            print("❌ 未找到声音包或目录: \(packId)")
            return nil
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
            let soundNameWithoutExt = soundName.replacingOccurrences(of: ".caf", with: "")
                .replacingOccurrences(of: ".wav", with: "")
                .replacingOccurrences(of: ".mp3", with: "")
                .replacingOccurrences(of: ".m4a", with: "")
            
            if sound.name.lowercased() == soundNameWithoutExt.lowercased() ||
               sound.name.lowercased().contains(soundNameWithoutExt.lowercased()) ||
               soundNameWithoutExt.lowercased().contains(sound.name.lowercased()) {
                let fileURL = directoryURL.appendingPathComponent(sound.fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }
        
        print("❌ 在声音包 \(packId) 中未找到声音: \(soundName)")
        
        // 回退到内置声音
        return getBuiltInSoundURL(soundName)
    }
    
    // 新增方法：获取内置声音URL
    private func getBuiltInSoundURL(_ soundName: String) -> URL? {
        let possibleExtensions = ["caf", "wav", "mp3", "m4a"]
        
        for ext in possibleExtensions {
            if let path = Bundle.main.path(forResource: soundName, ofType: ext) {
                return URL(fileURLWithPath: path)
            }
        }
        
        // 尝试通过AudioResources获取
        if let url = AudioResources.shared.getAudioURL(for: soundName) {
            return url
        }
        
        print("⚠️ 未找到内置声音文件: \(soundName)")
        return nil
    }
    
    // 验证音效包是否有效
    func validateSoundPack(_ packId: String) -> Bool {
        // 内置音效包总是有效
        if packId.hasPrefix("builtin_") {
            return true
        }
        
        // 检查自定义音效包
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
    
    func observeSoundPackChanges() {
        // 在实际应用中，这里应该设置文件系统观察器来监视目录变化
        // 这里简化为定期刷新
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.loadInstalledSoundPacks()
            self?.loadAvailablePacks()
        }
    }
    
    // MARK: - 批量操作
    
    func uninstallAllSoundPacks() {
        let packsDirectory = getInstalledPacksDirectory()
        
        do {
            if fileManager.fileExists(atPath: packsDirectory.path) {
                let contents = try fileManager.contentsOfDirectory(
                    at: packsDirectory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                
                for url in contents {
                    try? fileManager.removeItem(at: url)
                    print("🗑️ 删除: \(url.lastPathComponent)")
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.installedSoundPacks = []
                    self?.loadAvailablePacks()
                    print("🧹 已卸载所有音效包")
                }
            }
        } catch {
            print("❌ 卸载所有音效包失败: \(error)")
        }
    }
    
    func refreshAll() {
        DispatchQueue.main.async { [weak self] in
            self?.loadAvailablePacks()
            self?.loadInstalledSoundPacks()
            HapticManager.shared.refreshSoundPacks()
            print("🔄 刷新所有音效包数据")
        }
    }
}
