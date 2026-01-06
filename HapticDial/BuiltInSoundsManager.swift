// Utils/BuiltInSoundsManager.swift
import Foundation
import AVFoundation
import Combine  // 添加这行

// 修复：添加 ObservableObject 协议
class BuiltInSoundsManager: ObservableObject {
    static let shared = BuiltInSoundsManager()
    
    // 修复：添加 @Published 包装器
    @Published var availableSounds: [BuiltInSound] = []
    
    // 修改结构体，添加 fileSize 属性
    struct BuiltInSound: Identifiable {
        let id = UUID()
        let name: String
        let fileName: String
        let fileExtension: String
        let category: String
        let duration: TimeInterval
        let fileSize: Int  // 添加这个属性
        
        // 添加计算属性来显示格式化的文件大小
        var formattedFileSize: String {
            let bytes = Double(fileSize)
            if bytes < 1024 {
                return "\(Int(bytes))B"
            } else if bytes < 1024 * 1024 {
                return "\(String(format: "%.1f", bytes / 1024))KB"
            } else {
                return "\(String(format: "%.1f", bytes / (1024 * 1024)))MB"
            }
        }
    }
    
    private init() {
        loadBuiltInSounds()
    }
    
    private func loadBuiltInSounds() {
        // 定义你的内置声音文件 - 添加文件大小信息
        let soundFiles = [
            // 格式: (文件名, 扩展名, 类别, 时长, 文件大小字节数)
            ("mechanical_click", "caf", "Mechanical", 0.1, 2048),
            ("mechanical_tick", "caf", "Mechanical", 0.08, 1536),
            ("mechanical_pop", "caf", "Mechanical", 0.12, 2560),
            
            ("digital_click", "caf", "Digital", 0.06, 1280),
            ("digital_tick", "caf", "Digital", 0.04, 1024),
            ("digital_pop", "caf", "Digital", 0.1, 2048),
            
            ("water_drop", "caf", "Natural", 0.15, 3072),
            ("wood_tap", "caf", "Natural", 0.12, 2560),
            ("bubble_pop", "caf", "Natural", 0.1, 2048),
            
            ("laser_click", "caf", "Futuristic", 0.07, 1792),
            ("synth_tick", "caf", "Futuristic", 0.05, 1280),
            ("energy_pop", "caf", "Futuristic", 0.09, 2304)
        ]
        
        availableSounds = soundFiles.map { fileName, ext, category, duration, fileSize in
            BuiltInSound(
                name: formatSoundName(fileName),
                fileName: fileName,
                fileExtension: ext,
                category: category,
                duration: duration,
                fileSize: fileSize  // 传递文件大小
            )
        }
        
        print("🔊 加载了 \(availableSounds.count) 个内置声音文件")
    }
    
    private func formatSoundName(_ fileName: String) -> String {
        return fileName
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    func getSoundURL(for sound: BuiltInSound) -> URL? {
        // 首先尝试从 Sounds 文件夹查找
        if let path = Bundle.main.path(forResource: sound.fileName, ofType: sound.fileExtension, inDirectory: "Sounds") {
            return URL(fileURLWithPath: path)
        }
        
        // 然后尝试从 Sounds 的子文件夹查找
        let subfolders = ["Mechanical", "Digital", "Natural", "Futuristic"]
        for folder in subfolders {
            if let path = Bundle.main.path(forResource: sound.fileName, ofType: sound.fileExtension, inDirectory: "Sounds/\(folder)") {
                return URL(fileURLWithPath: path)
            }
        }
        
        // 最后尝试从根目录查找
        if let path = Bundle.main.path(forResource: sound.fileName, ofType: sound.fileExtension) {
            return URL(fileURLWithPath: path)
        }
        
        print("❌ 未找到声音文件: \(sound.fileName).\(sound.fileExtension)")
        return nil
    }
    
    func playSound(_ sound: BuiltInSound) {
        guard let url = getSoundURL(for: sound) else {
            print("❌ 无法播放声音: 文件未找到")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            print("▶️ 播放内置声音: \(sound.name)")
        } catch {
            print("❌ 播放声音失败: \(error)")
        }
    }
    
    // 添加缺少的方法
    func getSoundCategories() -> [String] {
        // 获取所有不重复的类别
        let categories = Set(availableSounds.map { $0.category })
        return ["All"] + categories.sorted()
    }
    
    func getSounds(in category: String) -> [BuiltInSound] {
        if category == "All" {
            return availableSounds
        }
        return availableSounds.filter { $0.category == category }
    }
    
    func searchSounds(query: String) -> [BuiltInSound] {
        if query.isEmpty {
            return availableSounds
        }
        let lowercasedQuery = query.lowercased()
        return availableSounds.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.fileName.lowercased().contains(lowercasedQuery) ||
            $0.category.lowercased().contains(lowercasedQuery)
        }
    }
    
    // 这些方法可以保持原样或重命名以保持一致性
    func getSoundsByCategory() -> [String: [BuiltInSound]] {
        Dictionary(grouping: availableSounds, by: { $0.category })
    }
    
    func validateSoundFile(_ sound: BuiltInSound) -> Bool {
        return getSoundURL(for: sound) != nil
    }
    
    func getCategories() -> [String] {
        getSoundCategories()
    }
}
