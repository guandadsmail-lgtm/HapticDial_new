// Core/UnifiedSoundManager.swift
import Foundation
import AVFoundation
import Combine

class UnifiedSoundManager: ObservableObject {
    static let shared = UnifiedSoundManager()
    
    @Published var availableSounds: [SoundOption] = []
    @Published var selectedSound: SoundOption?
    @Published var categories: [String] = []
    
    // 音效选项数据结构
    struct SoundOption: Identifiable, Hashable {
        let id: String
        let name: String
        let category: String
        let type: SoundType
        let soundFile: String?
        let systemSoundID: SystemSoundID?
        let description: String
        
        var displayName: String {
            if type == .system {
                return "🔊 \(name)"
            } else {
                return "📦 \(name)"
            }
        }
    }
    
    enum SoundType {
        case system
        case custom
    }
    
    private let soundPackManager = SoundPackManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadAvailableSounds()
        setupObservers()
    }
    
    // MARK: - 声音加载与刷新
    
    private func loadAvailableSounds() {
        // 清空现有音效
        availableSounds.removeAll()
        
        // 添加系统音效
        let systemSounds: [SoundOption] = [
            SoundOption(
                id: "system_default",
                name: "Default",
                category: "System",
                type: .system,
                soundFile: nil,
                systemSoundID: 1104,
                description: "Standard system click sound"
            ),
            SoundOption(
                id: "system_mechanical",
                name: "Mechanical",
                category: "System",
                type: .system,
                soundFile: nil,
                systemSoundID: 1103,
                description: "Mechanical gear sounds"
            ),
            SoundOption(
                id: "system_digital",
                name: "Digital",
                category: "System",
                type: .system,
                soundFile: nil,
                systemSoundID: 1057,
                description: "Digital beeps and tones"
            ),
            SoundOption(
                id: "system_natural",
                name: "Natural",
                category: "System",
                type: .system,
                soundFile: nil,
                systemSoundID: 1105,
                description: "Water drops and natural sounds"
            ),
            SoundOption(
                id: "system_futuristic",
                name: "Futuristic",
                category: "System",
                type: .system,
                soundFile: nil,
                systemSoundID: 4095,
                description: "Sci-fi futuristic sounds"
            ),
            SoundOption(
                id: "system_silent",
                name: "Silent",
                category: "System",
                type: .system,
                soundFile: nil,
                systemSoundID: nil,
                description: "No sound, haptics only"
            )
        ]
        
        availableSounds.append(contentsOf: systemSounds)
        
        // 添加自定义音效包
        for soundPack in soundPackManager.installedSoundPacks {
            if let soundFiles = soundPack.soundFiles {
                for soundFile in soundFiles.prefix(5) { // 每个包最多显示5个音效
                    let soundName = soundFile.replacingOccurrences(of: ".caf", with: "")
                        .replacingOccurrences(of: ".wav", with: "")
                        .replacingOccurrences(of: ".mp3", with: "")
                    
                    let soundOption = SoundOption(
                        id: "\(soundPack.id)_\(soundName)",
                        name: "\(soundPack.name) - \(soundName.capitalized)",
                        category: "Custom Packs",
                        type: .custom,
                        soundFile: soundFile,
                        systemSoundID: nil,
                        description: soundPack.description.isEmpty ? "Custom sound from \(soundPack.name)" : soundPack.description
                    )
                    
                    availableSounds.append(soundOption)
                }
            }
        }
        
        // 更新类别
        updateCategories()
        
        // 加载选中的音效
        loadSelectedSound()
        
        print("🎵 UnifiedSoundManager loaded \(availableSounds.count) sounds")
    }
    
    // 刷新声音选项（公开方法，供其他管理器调用）
    func refreshSoundOptions() {
        print("🔄 UnifiedSoundManager: 刷新声音选项")
        loadAvailableSounds()
    }
    
    private func setupObservers() {
        // 监听声音包变化
        soundPackManager.$installedSoundPacks
            .sink { [weak self] _ in
                print("🔄 UnifiedSoundManager: 检测到音效包变化，重新加载声音")
                self?.loadAvailableSounds()
            }
            .store(in: &cancellables)
    }
    
    private func updateCategories() {
        let allCategories = Set(availableSounds.map { $0.category })
        categories = ["All"] + allCategories.sorted()
    }
    
    func getSounds(in category: String) -> [SoundOption] {
        if category == "All" {
            return availableSounds
        }
        return availableSounds.filter { $0.category == category }
    }
    
    func searchSounds(query: String) -> [SoundOption] {
        if query.isEmpty {
            return availableSounds
        }
        let lowercasedQuery = query.lowercased()
        return availableSounds.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.description.lowercased().contains(lowercasedQuery) ||
            $0.category.lowercased().contains(lowercasedQuery)
        }
    }
    
    // MARK: - 声音播放
    
    func playSound(_ sound: SoundOption) {
        switch sound.type {
        case .system:
            if let soundID = sound.systemSoundID {
                AudioServicesPlaySystemSound(soundID)
            }
        case .custom:
            if let soundFile = sound.soundFile {
                playCustomSound(soundFile)
            }
        }
    }
    
    private func playCustomSound(_ soundFile: String) {
        // 从声音包中查找并播放音效
        for soundPack in soundPackManager.installedSoundPacks {
            if let soundFiles = soundPack.soundFiles,
               soundFiles.contains(soundFile),
               let soundURL = soundPackManager.getSoundFileURL(forSoundPack: soundPack.id, soundName: soundFile.replacingOccurrences(of: ".caf", with: "")) {
                
                do {
                    let player = try AVAudioPlayer(contentsOf: soundURL)
                    player.prepareToPlay()
                    player.play()
                    print("▶️ Playing custom sound: \(soundFile)")
                } catch {
                    print("❌ Failed to play custom sound: \(error)")
                }
                return
            }
        }
    }
    
    // MARK: - 声音选择管理
    
    func selectSound(_ sound: SoundOption) {
        selectedSound = sound
        saveSelectedSound()
        print("✅ Selected sound: \(sound.name)")
    }
    
    private func loadSelectedSound() {
        if let soundId = UserDefaults.standard.string(forKey: "selected_sound_id") {
            selectedSound = availableSounds.first { $0.id == soundId }
            if selectedSound != nil {
                print("📝 Loaded selected sound from UserDefaults: \(soundId)")
            } else {
                print("⚠️ Saved sound not found, using default")
                selectDefaultSound()
            }
        } else {
            selectDefaultSound()
        }
    }
    
    private func selectDefaultSound() {
        // 默认选择系统默认音效
        selectedSound = availableSounds.first { $0.id == "system_default" }
        if selectedSound != nil {
            print("📝 Selected default sound")
            saveSelectedSound()
        }
    }
    
    private func saveSelectedSound() {
        if let sound = selectedSound {
            UserDefaults.standard.set(sound.id, forKey: "selected_sound_id")
            UserDefaults.standard.synchronize()
            print("💾 Saved sound selection: \(sound.id)")
        } else {
            UserDefaults.standard.removeObject(forKey: "selected_sound_id")
            UserDefaults.standard.synchronize()
            print("🗑️ Cleared sound selection")
        }
    }
    
    // MARK: - 实用方法
    
    func getCurrentSoundName() -> String {
        return selectedSound?.name ?? "Default"
    }
    
    func isSoundEnabled() -> Bool {
        return selectedSound?.id != "system_silent"
    }
    
    // 检查音效是否有效
    func validateSound(_ sound: SoundOption) -> Bool {
        switch sound.type {
        case .system:
            return true
        case .custom:
            if let soundFile = sound.soundFile {
                return soundPackManager.installedSoundPacks.contains { pack in
                    pack.soundFiles?.contains(soundFile) == true
                }
            }
            return false
        }
    }
    
    // 获取当前音效的类别
    func getCurrentSoundCategory() -> String {
        return selectedSound?.category ?? "System"
    }
    
    // 重置为默认设置
    func resetToDefaults() {
        selectedSound = nil
        UserDefaults.standard.removeObject(forKey: "selected_sound_id")
        UserDefaults.standard.synchronize()
        loadSelectedSound()
        print("🔄 Reset sound settings to defaults")
    }
}
