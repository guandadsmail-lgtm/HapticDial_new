// Manager/CustomSoundManager.swift
import Foundation
import AVFoundation
import Combine

class CustomSoundManager: ObservableObject {
    static let shared = CustomSoundManager()
    
    @Published var customSounds: [CustomSound] = []
    @Published var isLoading = false
    
    struct CustomSound: Identifiable, Codable {
        // 修复：移除默认值，使用自定义编码键
        var id: UUID
        let name: String
        let fileName: String
        let fileExtension: String
        let category: String
        let duration: TimeInterval?
        
        var displayName: String {
            name.replacingOccurrences(of: "_", with: " ").capitalized
        }
        
        // 自定义编码键
        enum CodingKeys: String, CodingKey {
            case id, name, fileName, fileExtension, category, duration
        }
        
        init(id: UUID = UUID(), name: String, fileName: String, fileExtension: String, category: String, duration: TimeInterval?) {
            self.id = id
            self.name = name
            self.fileName = fileName
            self.fileExtension = fileExtension
            self.category = category
            self.duration = duration
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            name = try container.decode(String.self, forKey: .name)
            fileName = try container.decode(String.self, forKey: .fileName)
            fileExtension = try container.decode(String.self, forKey: .fileExtension)
            category = try container.decode(String.self, forKey: .category)
            duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        }
    }
    
    private let fileManager = FileManager.default
    private let customSoundsDirectory: URL
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    
    private init() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        customSoundsDirectory = documentsURL.appendingPathComponent("CustomSounds")
        
        createCustomSoundsDirectory()
        loadCustomSounds()
    }
    
    private func createCustomSoundsDirectory() {
        if !fileManager.fileExists(atPath: customSoundsDirectory.path) {
            try? fileManager.createDirectory(at: customSoundsDirectory, withIntermediateDirectories: true)
        }
    }
    
    func loadCustomSounds() {
        isLoading = true
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: customSoundsDirectory,
                includingPropertiesForKeys: [.contentTypeKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            var sounds: [CustomSound] = []
            let audioExtensions = ["caf", "wav", "mp3", "m4a", "aac"]
            
            for fileURL in contents {
                let fileExtension = fileURL.pathExtension.lowercased()
                
                if audioExtensions.contains(fileExtension) {
                    let fileName = fileURL.deletingPathExtension().lastPathComponent
                    let duration = getAudioDuration(fileURL)
                    
                    let sound = CustomSound(
                        name: fileName,
                        fileName: fileURL.lastPathComponent,
                        fileExtension: fileExtension,
                        category: "Custom",
                        duration: duration
                    )
                    
                    sounds.append(sound)
                }
            }
            
            customSounds = sounds.sorted { $0.name < $1.name }
            print("📁 加载了 \(customSounds.count) 个自定义声音文件")
            
        } catch {
            print("❌ 加载自定义声音失败: \(error)")
            customSounds = []
        }
        
        isLoading = false
    }
    
    private func getAudioDuration(_ url: URL) -> TimeInterval? {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            return audioPlayer.duration
        } catch {
            return nil
        }
    }
    
    // MARK: - 添加声音文件
    
    func importSoundFile(_ sourceURL: URL) throws -> CustomSound {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = customSoundsDirectory.appendingPathComponent(fileName)
        
        // 检查文件是否已存在
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // 复制文件
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // 重新加载声音列表
        loadCustomSounds()
        
        let soundName = sourceURL.deletingPathExtension().lastPathComponent
        let duration = getAudioDuration(destinationURL)
        
        return CustomSound(
            name: soundName,
            fileName: fileName,
            fileExtension: sourceURL.pathExtension.lowercased(),
            category: "Custom",
            duration: duration
        )
    }
    
    // MARK: - 播放声音
    
    func playSound(_ sound: CustomSound) {
        let soundURL = customSoundsDirectory.appendingPathComponent(sound.fileName)
        
        guard fileManager.fileExists(atPath: soundURL.path) else {
            print("❌ 声音文件不存在: \(sound.fileName)")
            return
        }
        
        do {
            let player: AVAudioPlayer
            
            if let existingPlayer = audioPlayers[sound.fileName] {
                player = existingPlayer
            } else {
                player = try AVAudioPlayer(contentsOf: soundURL)
                player.prepareToPlay()
                audioPlayers[sound.fileName] = player
            }
            
            player.currentTime = 0
            player.play()
            
            print("▶️ 播放自定义声音: \(sound.displayName)")
            
        } catch {
            print("❌ 播放自定义声音失败: \(error)")
        }
    }
    
    func playSound(named soundName: String) {
        if let sound = customSounds.first(where: {
            $0.name.lowercased() == soundName.lowercased() ||
            $0.displayName.lowercased() == soundName.lowercased()
        }) {
            playSound(sound)
        } else {
            print("❌ 未找到自定义声音: \(soundName)")
        }
    }
    
    // MARK: - 删除声音
    
    func deleteSound(_ sound: CustomSound) throws {
        let fileURL = customSoundsDirectory.appendingPathComponent(sound.fileName)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        // 移除播放器缓存
        audioPlayers.removeValue(forKey: sound.fileName)
        
        // 重新加载列表
        loadCustomSounds()
        
        print("🗑️ 删除自定义声音: \(sound.displayName)")
    }
    
    func getSoundURL(for soundName: String) -> URL? {
        if let sound = customSounds.first(where: {
            $0.name.lowercased() == soundName.lowercased() ||
            $0.displayName.lowercased() == soundName.lowercased()
        }) {
            let url = customSoundsDirectory.appendingPathComponent(sound.fileName)
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }
        return nil
    }
    
    // MARK: - 批量操作
    
    func importMultipleSoundFiles(_ urls: [URL]) -> [CustomSound] {
        var importedSounds: [CustomSound] = []
        
        for url in urls {
            do {
                let sound = try importSoundFile(url)
                importedSounds.append(sound)
            } catch {
                print("❌ 导入声音文件失败 \(url.lastPathComponent): \(error)")
            }
        }
        
        return importedSounds
    }
    
    func deleteAllSounds() throws {
        let contents = try fileManager.contentsOfDirectory(
            at: customSoundsDirectory,
            includingPropertiesForKeys: nil,
            options: []
        )
        
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
        
        audioPlayers.removeAll()
        customSounds = []
        
        print("🗑️ 删除所有自定义声音")
    }
    
    // MARK: - 工具方法
    
    func testAllSounds() {
        print("🔊 测试所有自定义声音 (\(customSounds.count) 个)")
        
        for (index, sound) in customSounds.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                print("   \(index + 1). \(sound.displayName)")
                self.playSound(sound)
            }
        }
    }
    
    func getTotalDuration() -> TimeInterval {
        return customSounds.compactMap { $0.duration }.reduce(0, +)
    }
    
    func getTotalFileSize() -> Int64 {
        var totalSize: Int64 = 0
        
        for sound in customSounds {
            let fileURL = customSoundsDirectory.appendingPathComponent(sound.fileName)
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? NSNumber {
                totalSize += fileSize.int64Value
            }
        }
        
        return totalSize
    }
    
    func formattedTotalFileSize() -> String {
        let bytes = Double(getTotalFileSize())
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
