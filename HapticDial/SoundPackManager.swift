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
            name: "Default Mode",
            description: "System default sounds",
            author: "System",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "Ratchet Click", fileName: "ratchet_click.caf"),
                Sound(id: UUID(), name: "Aperture Click", fileName: "aperture_click.caf")
            ],
            soundFiles: ["ratchet_click.caf", "aperture_click.caf"]
        ),
        SoundPack(
            id: "builtin_mechanical",
            name: "Mechanical Mode",
            description: "Classic mechanical sound effects",
            author: "System",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "Mechanical Click", fileName: "mechanical_click.caf"),
                Sound(id: UUID(), name: "Mechanical Tick", fileName: "mechanical_tick.caf")
            ],
            soundFiles: ["mechanical_click.caf", "mechanical_tick.caf"]
        ),
        SoundPack(
            id: "builtin_digital",
            name: "Digital Mode",
            description: "Clear digital beep sounds",
            author: "System",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "Digital Beep", fileName: "digital_beep.caf"),
                Sound(id: UUID(), name: "Digital Tone", fileName: "digital_tone.caf")
            ],
            soundFiles: ["digital_beep.caf", "digital_tone.caf"]
        ),
        SoundPack(
            id: "builtin_natural",
            name: "Natural Mode",
            description: "Natural water and wood sounds",
            author: "System",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "Water Drop", fileName: "water_drop.caf"),
                Sound(id: UUID(), name: "Wood Tap", fileName: "wood_tap.caf")
            ],
            soundFiles: ["water_drop.caf", "wood_tap.caf"]
        ),
        SoundPack(
            id: "builtin_futuristic",
            name: "Futuristic Mode",
            description: "Sci-fi laser and energy sounds",
            author: "System",
            version: "1.0",
            sounds: [
                Sound(id: UUID(), name: "Laser Click", fileName: "laser_click.caf"),
                Sound(id: UUID(), name: "Synth Tick", fileName: "synth_tick.caf")
            ],
            soundFiles: ["laser_click.caf", "synth_tick.caf"]
        ),
        SoundPack(
            id: "builtin_silent",
            name: "Silent Mode",
            description: "Haptic feedback only, no sound",
            author: "System",
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
        
        // Load predefined sound packs from built-in resources
        let customBuiltInPacks = [
            SoundPack(
                id: "mechanical-pack",
                name: "Mechanical Sound Pack",
                description: "Complete collection of mechanical sound effects",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "Mechanical Click", fileName: "mechanical_click.caf"),
                    Sound(id: UUID(), name: "Mechanical Tick", fileName: "mechanical_tick.caf"),
                    Sound(id: UUID(), name: "Mechanical Pop", fileName: "mechanical_pop.caf"),
                    Sound(id: UUID(), name: "Click", fileName: "mechanical_click.caf")
                ],
                soundFiles: ["mechanical_click.caf", "mechanical_tick.caf", "mechanical_pop.caf"]
            ),
            SoundPack(
                id: "digital-pack",
                name: "Digital Sound Pack",
                description: "Complete collection of digital beep sounds",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "Digital Beep", fileName: "digital_beep.caf"),
                    Sound(id: UUID(), name: "Digital Tone", fileName: "digital_tone.caf"),
                    Sound(id: UUID(), name: "Digital Blip", fileName: "digital_blip.caf"),
                    Sound(id: UUID(), name: "Click", fileName: "digital_beep.caf")
                ],
                soundFiles: ["digital_beep.caf", "digital_tone.caf", "digital_blip.caf"]
            ),
            SoundPack(
                id: "natural-pack",
                name: "Natural Sound Pack",
                description: "Complete collection of natural sounds",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "Water Drop", fileName: "water_drop.caf"),
                    Sound(id: UUID(), name: "Wood Tap", fileName: "wood_tap.caf"),
                    Sound(id: UUID(), name: "Bubble Pop", fileName: "bubble_pop.caf"),
                    Sound(id: UUID(), name: "Click", fileName: "water_drop.caf")
                ],
                soundFiles: ["water_drop.caf", "wood_tap.caf", "bubble_pop.caf"]
            ),
            SoundPack(
                id: "futuristic-pack",
                name: "Futuristic Sound Pack",
                description: "Complete collection of sci-fi sounds",
                author: "HapticDial",
                version: "1.0",
                sounds: [
                    Sound(id: UUID(), name: "Laser Click", fileName: "laser_click.caf"),
                    Sound(id: UUID(), name: "Synth Tick", fileName: "synth_tick.caf"),
                    Sound(id: UUID(), name: "Energy Pop", fileName: "energy_pop.caf"),
                    Sound(id: UUID(), name: "Click", fileName: "laser_click.caf")
                ],
                soundFiles: ["laser_click.caf", "synth_tick.caf", "energy_pop.caf"]
            )
        ]
        
        // Check which sound packs are already installed
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
        
        // Combine built-in modes and sound packs
        let allPacks = builtInSoundModes + enhancedPacks
        
        DispatchQueue.main.async { [weak self] in
            self?.availablePacks = allPacks
            self?.isLoading = false
            print("📦 Loaded \(allPacks.count) available sound packs (including \(self?.builtInSoundModes.count ?? 0) built-in modes)")
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
                    print("✅ Loaded \(packs.count) installed sound packs")
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.installedSoundPacks = []
                }
            }
        } catch {
            print("❌ Failed to load installed sound packs: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.installedSoundPacks = []
                self?.errorMessage = "Failed to load sound packs: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 声音播放支持
    
    // Get appropriate sound name for current mode
    func getSoundNameForCurrentMode(currentMode: DialMode, packId: String?) -> String {
        // For built-in modes, use specific names
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
                return "" // Silent mode
            default:
                return "click"
            }
        }
        
        // For custom sound packs, always use click or the first sound
        return "click"
    }
    
    // Generic method to get sound file URL
    func getSoundFileURL(forSoundPack packId: String, soundName: String, currentMode: DialMode? = nil) -> URL? {
        // For built-in modes, get from Bundle
        if packId.hasPrefix("builtin_") {
            // Get appropriate sound name for current mode
            let effectiveSoundName: String
            if let currentMode = currentMode {
                effectiveSoundName = getSoundNameForCurrentMode(currentMode: currentMode, packId: packId)
            } else {
                effectiveSoundName = soundName
            }
            
            // Silent mode returns nil
            if packId == "builtin_silent" || effectiveSoundName.isEmpty {
                return nil
            }
            
            // Try various possible extensions
            let possibleExtensions = ["caf", "wav", "mp3", "m4a"]
            
            for ext in possibleExtensions {
                if let path = Bundle.main.path(forResource: effectiveSoundName, ofType: ext) {
                    return URL(fileURLWithPath: path)
                }
            }
            
            // Try to get via AudioResources
            if let url = AudioResources.shared.getAudioURL(for: effectiveSoundName) {
                return url
            }
            
            print("⚠️ Built-in sound file not found: \(effectiveSoundName)")
            return nil
        }
        
        // For custom sound packs
        guard let pack = installedSoundPacks.first(where: { $0.id == packId }),
              let directoryURL = pack.directoryURL else {
            print("❌ Sound pack or directory not found: \(packId)")
            return nil
        }
        
        // First try direct filename match
        let directURL = directoryURL.appendingPathComponent(soundName)
        if fileManager.fileExists(atPath: directURL.path) {
            return directURL
        }
        
        // Try various possible extensions
        let possibleExtensions = ["caf", "wav", "mp3", "m4a", "aac"]
        
        for ext in possibleExtensions {
            let fileURL = directoryURL.appendingPathComponent("\(soundName).\(ext)")
            if fileManager.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        
        // Try to find in sound list
        for sound in pack.sounds {
            if sound.name.lowercased() == soundName.lowercased() {
                let fileURL = directoryURL.appendingPathComponent(sound.fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }
        
        // Try partial match
        for sound in pack.sounds {
            if sound.name.lowercased().contains(soundName.lowercased()) {
                let fileURL = directoryURL.appendingPathComponent(sound.fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }
        
        // If no specific sound found, try using the first sound
        if let firstSound = pack.sounds.first {
            let fileURL = directoryURL.appendingPathComponent(firstSound.fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                print("🔄 Using first sound as alternative: \(firstSound.name)")
                return fileURL
            }
        }
        
        print("❌ Sound not found in pack \(packId): \(soundName)")
        return nil
    }
    
    // Validate sound pack
    func validateSoundPack(_ packId: String) -> Bool {
        // Built-in modes are always valid
        if packId.hasPrefix("builtin_") {
            return true
        }
        
        guard let pack = installedSoundPacks.first(where: { $0.id == packId }) else {
            print("⚠️ Sound pack does not exist: \(packId)")
            return false
        }
        
        // Check if at least one sound file exists
        if pack.sounds.isEmpty {
            print("⚠️ No sound files in sound pack \(pack.name)")
            return false
        }
        
        // Check if directory exists
        guard let directoryURL = pack.directoryURL else {
            print("⚠️ Directory for sound pack \(pack.name) does not exist")
            return false
        }
        
        // Check if at least one sound file exists
        for sound in pack.sounds {
            let fileURL = directoryURL.appendingPathComponent(sound.fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                return true
            }
        }
        
        print("⚠️ No valid sound files in sound pack \(pack.name)")
        return false
    }
    
    // Get all options (built-in modes + custom sound packs)
    func getAllOptions() -> [SoundPack] {
        return availablePacks
    }
    
    // Check if it's a built-in mode
    func isBuiltInMode(_ packId: String) -> Bool {
        return packId.hasPrefix("builtin_")
    }
    
    // Get built-in mode name
    func getBuiltInModeName(_ packId: String) -> String {
        return builtInSoundModes.first(where: { $0.id == packId })?.name ?? packId
    }
    
    // Get human-readable name for current selection
    func getCurrentSelectionName(_ packId: String?) -> String {
        guard let packId = packId else {
            return "Not Selected"
        }
        
        if let pack = availablePacks.first(where: { $0.id == packId }) {
            return pack.name
        }
        
        return packId
    }
    
    // Check if sound pack is installed
    func isSoundPackInstalled(_ packId: String) -> Bool {
        return installedSoundPacks.contains { $0.id == packId }
    }
    
    // MARK: - Installation
    
    func installSoundPack(_ packId: String) async throws -> SoundPack {
        print("📥 Starting installation of sound pack: \(packId)")
        
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
        
        // Find sound pack (excluding built-in modes)
        guard let pack = availablePacks.first(where: { $0.id == packId && !isBuiltInMode(packId) }) else {
            throw NSError(domain: "SoundPackManager", code: 100,
                         userInfo: [NSLocalizedDescriptionKey: "Sound pack not found: \(packId)"])
        }
        
        // If already installed, return directly
        if isSoundPackInstalled(packId) {
            print("📦 Sound pack already installed: \(pack.name)")
            return pack
        }
        
        let packsDirectory = getInstalledPacksDirectory()
        let packDirectory = packsDirectory.appendingPathComponent(packId)
        
        // Create directory
        do {
            if fileManager.fileExists(atPath: packDirectory.path) {
                try fileManager.removeItem(at: packDirectory)
            }
            try fileManager.createDirectory(at: packDirectory, withIntermediateDirectories: true)
        } catch {
            throw NSError(domain: "SoundPackManager", code: 101,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create directory: \(error.localizedDescription)"])
        }
        
        // Copy sound files
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
                        print("✅ Copied file: \(soundFile)")
                    } catch {
                        print("⚠️ Failed to copy file \(soundFile): \(error)")
                    }
                }
            }
        }
        
        // Save manifest.json
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
            print("✅ Saved manifest.json")
        } catch {
            print("⚠️ Failed to save manifest.json: \(error)")
        }
        
        // Update installed list
        DispatchQueue.main.async { [weak self] in
            self?.loadInstalledSoundPacks()
            self?.loadAvailablePacks()
        }
        
        // Notify managers to refresh sound cache
        notifyManagersOfSoundPackUpdate()
        
        print("🎉 Sound pack installed successfully: \(pack.name)")
        
        return installedPack
    }
    
    // MARK: - Load Sound Pack
    func loadSoundPack(from directory: URL) throws -> SoundPack {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw NSError(domain: "SoundPackManager", code: 200,
                         userInfo: [NSLocalizedDescriptionKey: "manifest.json file does not exist"])
        }
        
        do {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            var pack = try decoder.decode(SoundPack.self, from: data)
            pack.directoryURL = directory
            return pack
        } catch {
            throw NSError(domain: "SoundPackManager", code: 201,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to parse manifest.json: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - File Management
    
    private func getInstalledPackDirectory(_ packId: String) -> URL {
        return getInstalledPacksDirectory().appendingPathComponent(packId)
    }
    
    private func getInstalledPacksDirectory() -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let packsDirectory = documentsDirectory.appendingPathComponent("SoundPacks")
        
        if !fileManager.fileExists(atPath: packsDirectory.path) {
            do {
                try fileManager.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
                print("📁 Created sound packs directory: \(packsDirectory.path)")
            } catch {
                print("❌ Failed to create sound packs directory: \(error)")
            }
        }
        
        return packsDirectory
    }
    
    // Notify related managers of sound pack update
    private func notifyManagersOfSoundPackUpdate() {
        // Clean up audio player cache in HapticManager
        HapticManager.shared.cleanup()
        
        print("🔊 Notified all managers that sound packs have been updated")
        
        // Post a notification for other observers
        NotificationCenter.default.post(name: NSNotification.Name("SoundPacksUpdated"), object: nil)
    }
    
    // Supported file types
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
