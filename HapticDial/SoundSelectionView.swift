import SwiftUI

struct SoundSelectionView: View {
    @StateObject private var soundManager = UnifiedSoundManager.shared
    @State private var showingFileImporter = false
    @State private var importError: String?
    @State private var showingError = false
    @State private var showingDeleteAlert = false
    @State private var soundToDelete: UnifiedSoundManager.SoundOption?
    
    // System sounds
    private var systemSounds: [UnifiedSoundManager.SoundOption] {
        soundManager.publicSystemSoundOptions
    }
    
    // User custom sounds
    private var customSounds: [UnifiedSoundManager.SoundOption] {
        soundManager.userCustomSounds
    }
    
    // Other sounds
    private var otherSounds: [UnifiedSoundManager.SoundOption] {
        let allSounds = soundManager.getAllSounds()
        let systemIDs = Set(systemSounds.map { $0.id })
        let customIDs = Set(customSounds.map { $0.id })
        
        var results: [UnifiedSoundManager.SoundOption] = []
        for sound in allSounds {
            if !systemIDs.contains(sound.id) && !customIDs.contains(sound.id) {
                results.append(sound)
            }
        }
        return results
    }
    
    var body: some View {
        List {
            // System Sounds Section
            Section(header: Text("System Sounds")) {
                ForEach(systemSounds, id: \.id) { sound in
                    let isSoundSelected = soundManager.selectedSound?.id == sound.id
                    
                    SoundOptionRow(
                        sound: sound,
                        isSelected: isSoundSelected,
                        onSelect: { soundManager.selectSound(sound) },
                        soundType: .system
                    )
                }
            }
            
            // Built-in Sounds Section
            if !otherSounds.isEmpty {
                Section(header: Text("Built-in Sounds")) {
                    ForEach(otherSounds, id: \.id) { sound in
                        let isSoundSelected = soundManager.selectedSound?.id == sound.id
                        
                        SoundOptionRow(
                            sound: sound,
                            isSelected: isSoundSelected,
                            onSelect: { soundManager.selectSound(sound) },
                            soundType: .builtIn
                        )
                    }
                }
            }
            
            // Custom Sounds Section
            Section(header: Text("Custom Sounds")) {
                if customSounds.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No Custom Sounds")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("Tap the button below to upload your sound files")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 30)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(customSounds, id: \.id) { sound in
                        let isSoundSelected = soundManager.selectedSound?.id == sound.id
                        
                        SoundOptionRow(
                            sound: sound,
                            isSelected: isSoundSelected,
                            onSelect: { soundManager.selectSound(sound) },
                            soundType: .custom,
                            onDelete: {
                                soundToDelete = sound
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
            }
            
            // Upload Button Section
            Section {
                Button(action: {
                    showingFileImporter = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upload Custom Sound")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Supports .caf, .wav, .mp3, .m4a, .aiff files, up to 5MB")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Select Sound")
        .sheet(isPresented: $showingFileImporter) {
            FileImporter { url in
                importCustomSound(from: url)
            }
        }
        .alert("Import Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError ?? "Unknown error")
        }
        .alert("Delete Sound", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let sound = soundToDelete {
                    soundManager.deleteCustomSound(sound)
                }
            }
        } message: {
            Text("Are you sure you want to delete this custom sound?")
        }
        .onAppear {
            // Ensure all sounds are loaded
            soundManager.refreshSoundOptions()
        }
    }
    
    private func importCustomSound(from url: URL) {
        do {
            try soundManager.importCustomSound(from: url)
        } catch {
            importError = error.localizedDescription
            showingError = true
        }
    }
}

// Sound Type
enum SoundType {
    case system
    case builtIn
    case custom
}

struct SoundOptionRow: View {
    let sound: UnifiedSoundManager.SoundOption
    let isSelected: Bool
    let onSelect: () -> Void
    let soundType: SoundType
    let onDelete: (() -> Void)?
    
    @State private var showingDeleteConfirm = false
    
    init(sound: UnifiedSoundManager.SoundOption,
         isSelected: Bool,
         onSelect: @escaping () -> Void,
         soundType: SoundType,
         onDelete: (() -> Void)? = nil) {
        self.sound = sound
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.soundType = soundType
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(sound.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            // Show different badges
                            switch soundType {
                            case .system:
                                if sound.systemSoundID == nil {
                                    Text("Mute")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                } else {
                                    Text("System")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            case .builtIn:
                                Text("Built-in")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            case .custom:
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        
                        // Description text
                        switch soundType {
                        case .system:
                            if sound.systemSoundID == nil {
                                Text("Mute")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("System Sound")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        case .builtIn:
                            Text("Built-in Sound")
                                .font(.caption)
                                .foregroundColor(.gray)
                        case .custom:
                            Text("Custom Sound")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Only show delete button for custom sounds
            if soundType == .custom, let onDelete = onDelete {
                Button(action: {
                    showingDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                        .padding(.leading, 12)
                }
                .buttonStyle(BorderlessButtonStyle())
                .alert("Confirm Delete", isPresented: $showingDeleteConfirm) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } message: {
                    Text("Are you sure you want to delete this custom sound?")
                }
            }
        }
    }
}
