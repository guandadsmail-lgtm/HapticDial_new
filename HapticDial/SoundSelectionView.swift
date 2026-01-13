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
            Section(header: Text("SYSTEM_SOUNDS_SECTION".localized)) {
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
                Section(header: Text("BUILTIN_SOUNDS_SECTION".localized)) {
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
            Section(header: Text("CUSTOM_SOUNDS_SECTION".localized)) {
                if customSounds.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("NO_CUSTOM_SOUNDS_TITLE".localized)
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("NO_CUSTOM_SOUNDS_DESCRIPTION".localized)
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
                            Text("UPLOAD_CUSTOM_SOUND_BUTTON".localized)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("UPLOAD_CUSTOM_SOUND_DESCRIPTION".localized)
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
        .navigationTitle("SELECT_SOUND_TITLE".localized)
        .sheet(isPresented: $showingFileImporter) {
            FileImporter { url in
                importCustomSound(from: url)
            }
        }
        .alert("IMPORT_FAILED_ALERT_TITLE".localized, isPresented: $showingError) {
            Button("OK_BUTTON".localized, role: .cancel) { }
        } message: {
            Text(importError ?? "UNKNOWN_ERROR".localized)
        }
        .alert("DELETE_SOUND_ALERT_TITLE".localized, isPresented: $showingDeleteAlert) {
            Button("CANCEL_BUTTON".localized, role: .cancel) { }
            Button("DELETE_BUTTON".localized, role: .destructive) {
                if let sound = soundToDelete {
                    soundManager.deleteCustomSound(sound)
                }
            }
        } message: {
            Text("DELETE_SOUND_ALERT_MESSAGE".localized)
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
                                    Text("SOUND_TYPE_MUTE".localized)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                } else {
                                    Text("SOUND_TYPE_SYSTEM".localized)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            case .builtIn:
                                Text("SOUND_TYPE_BUILTIN".localized)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            case .custom:
                                Text("SOUND_TYPE_CUSTOM".localized)
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
                                    Text("SOUND_TYPE_MUTE_DESCRIPTION".localized)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("SOUND_TYPE_SYSTEM_DESCRIPTION".localized)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            case .builtIn:
                                Text("SOUND_TYPE_BUILTIN_DESCRIPTION".localized)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            case .custom:
                                Text("SOUND_TYPE_CUSTOM_DESCRIPTION".localized)
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
                    .alert("CONFIRM_DELETE_ALERT_TITLE".localized, isPresented: $showingDeleteConfirm) {
                        Button("CANCEL_BUTTON".localized, role: .cancel) { }
                        Button("DELETE_BUTTON".localized, role: .destructive) {
                            onDelete()
                        }
                    } message: {
                        Text("CONFIRM_DELETE_ALERT_MESSAGE".localized)
                    }
                }
            }
        }
    }

