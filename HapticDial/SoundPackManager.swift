import Foundation
import Combine
import Zip
import UniformTypeIdentifiers

class SoundPackManager: ObservableObject {
    static let shared = SoundPackManager()
    
    @Published var availablePacks: [SoundPack] = []
    @Published var installedSoundPacks: [SoundPack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fileManager = FileManager.default
    
    init() {
        loadAvailablePacks()
        loadInstalledSoundPacks()
    }
    
    // MARK: - 音效包管理
    
    func loadAvailablePacks() {
        isLoading = true
        errorMessage = nil
        
        // 模拟加载过程 - 实际应用中这里会从服务器获取
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            self.availablePacks = [
                SoundPack(
                    id: "mechanical-pack",
                    name: "Mechanical Pack",
                    description: "Classic mechanical sounds",
                    author: "System",
                    version: "1.0",
                    sounds: [
                        Sound(id: UUID(), name: "Click", fileName: "mechanical_click.caf"),
                        Sound(id: UUID(), name: "Tick", fileName: "mechanical_tick.caf"),
                        Sound(id: UUID(), name: "Pop", fileName: "mechanical_pop.caf")
                    ],
                    soundFiles: ["mechanical_click.caf", "mechanical_tick.caf", "mechanical_pop.caf"]
                ),
                SoundPack(
                    id: "digital-pack",
                    name: "Digital Pack",
                    description: "Clean digital beeps and tones",
                    author: "System",
                    version: "1.0",
                    sounds: [
                        Sound(id: UUID(), name: "Beep", fileName: "digital_beep.caf"),
                        Sound(id: UUID(), name: "Tone", fileName: "digital_tone.caf"),
                        Sound(id: UUID(), name: "Blip", fileName: "digital_blip.caf")
                    ],
                    soundFiles: ["digital_beep.caf", "digital_tone.caf", "digital_blip.caf"]
                ),
                SoundPack(
                    id: "natural-pack",
                    name: "Natural Pack",
                    description: "Natural water and wood sounds",
                    author: "System",
                    version: "1.0",
                    sounds: [
                        Sound(id: UUID(), name: "Water Drop", fileName: "water_drop.caf"),
                        Sound(id: UUID(), name: "Wood Tap", fileName: "wood_tap.caf"),
                        Sound(id: UUID(), name: "Bubble Pop", fileName: "bubble_pop.caf")
                    ],
                    soundFiles: ["water_drop.caf", "wood_tap.caf", "bubble_pop.caf"]
                ),
                SoundPack(
                    id: "futuristic-pack",
                    name: "Futuristic Pack",
                    description: "Sci-fi laser and energy sounds",
                    author: "System",
                    version: "1.0",
                    sounds: [
                        Sound(id: UUID(), name: "Laser", fileName: "laser_click.caf"),
                        Sound(id: UUID(), name: "Synth", fileName: "synth_tick.caf"),
                        Sound(id: UUID(), name: "Energy", fileName: "energy_pop.caf")
                    ],
                    soundFiles: ["laser_click.caf", "synth_tick.caf", "energy_pop.caf"]
                )
            ]
            
            self.isLoading = false
        }
    }
    
    func loadInstalledSoundPacks() {
        let installedPacksDirectory = getInstalledPacksDirectory()
        
        do {
            if fileManager.fileExists(atPath: installedPacksDirectory.path) {
                let contents = try fileManager.contentsOfDirectory(
                    at: installedPacksDirectory,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: []
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
                
                installedSoundPacks = packs
            } else {
                installedSoundPacks = []
            }
        } catch {
            print("加载已安装音效包失败: \(error)")
            installedSoundPacks = []
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
            
            // 加载音效文件
            if fileManager.fileExists(atPath: directoryURL.path) {
                let soundFiles = try fileManager.contentsOfDirectory(at: directoryURL,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles])
                
                var sounds: [Sound] = []
                for fileURL in soundFiles {
                    let fileExtension = fileURL.pathExtension.lowercased()
                    if SoundPack.supportedAudioExtensions.contains(fileExtension) {
                        let fileName = fileURL.deletingPathExtension().lastPathComponent
                        let sound = Sound(id: UUID(), name: fileName, fileName: fileURL.lastPathComponent)
                        sounds.append(sound)
                    }
                }
                
                pack.sounds = sounds
            }
            
            return pack
        } catch {
            throw NSError(domain: "SoundPackManager", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "解析 manifest.json 失败: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - Zip 相关功能
    
    func importSoundPack(from zipURL: URL) throws -> SoundPack {
        let packsDirectory = try getInstalledPacksDirectory()
        
        // 解压 ZIP 文件
        let unzipDirectory = packsDirectory.appendingPathComponent(UUID().uuidString)
        
        // 使用 Zip 库解压文件
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
        } catch {
            throw NSError(domain: "SoundPackManager", code: 9,
                         userInfo: [NSLocalizedDescriptionKey: "删除失败: \(error.localizedDescription)"])
        }
    }
    
    func createSoundPack(name: String, description: String = "", author: String = "") throws -> SoundPack {
        let packsDirectory = try getInstalledPacksDirectory()
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
        
        var mutablePack = pack
        mutablePack.directoryURL = packDirectory
        
        // 添加到列表
        installedSoundPacks.append(mutablePack)
        installedSoundPacks.sort { $0.name < $1.name }
        
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
            try? fileManager.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
        }
        
        return packsDirectory
    }
    
    // MARK: - 辅助方法
    
    func getSoundFileURL(forSoundPack packId: String, soundName: String) -> URL? {
        guard let pack = installedSoundPacks.first(where: { $0.id == packId }),
              let directoryURL = pack.directoryURL else {
            print("❌ 未找到声音包或目录: \(packId)")
            return nil
        }
        
        // 首先尝试直接查找文件名
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
        
        // 尝试在soundFiles中查找
        if let soundFiles = pack.soundFiles {
            for fileName in soundFiles {
                let fileURL = directoryURL.appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }
        
        // 最后尝试在声音列表中查找
        for sound in pack.sounds {
            if sound.name.lowercased() == soundName.lowercased() {
                let fileURL = directoryURL.appendingPathComponent(sound.fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }
        
        print("❌ 在声音包 \(packId) 中未找到声音: \(soundName)")
        
        // 回退到内置声音
        if let builtInURL = AudioResources.shared.getAudioURL(for: soundName) {
            print("🔄 使用内置声音: \(soundName)")
            return builtInURL
        }
        
        return nil
    }
    
    func observeSoundPackChanges() {
        // 在实际应用中，这里应该设置文件系统观察器来监视目录变化
        // 这里简化为定期刷新
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.loadInstalledSoundPacks()
        }
    }
    
    // MARK: - Zip 功能测试
    
    func testZipFunctionality() {
        print("🔧 开始测试 Zip 库功能...")
        
        // 创建测试目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // 创建测试文件
            let testFile = tempDir.appendingPathComponent("test.txt")
            try "Hello, Zip!".write(to: testFile, atomically: true, encoding: .utf8)
            
            // 测试压缩
            let zipFile = tempDir.appendingPathComponent("test.zip")
            try? Zip.zipFiles(paths: [testFile], zipFilePath: zipFile, password: nil, progress: nil)
            print("✅ 压缩测试成功: \(zipFile.lastPathComponent)")
            
            // 测试解压
            let unzipDir = tempDir.appendingPathComponent("unzipped")
            try? Zip.unzipFile(zipFile, destination: unzipDir, overwrite: true, password: nil, progress: nil)
            print("✅ 解压测试成功")
            
            // 清理
            try? fileManager.removeItem(at: tempDir)
            print("🧹 测试完成，已清理临时文件")
            
        } catch {
            print("❌ Zip 测试失败: \(error)")
        }
    }
}
