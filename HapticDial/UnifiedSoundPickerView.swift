// Views/UnifiedSoundPickerView.swift
import SwiftUI
import AVFoundation

struct UnifiedSoundPickerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var soundManager = UnifiedSoundManager.shared
    
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    @State private var playingSound: UnifiedSoundManager.SoundOption?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("SEARCH_SOUNDS_PLACEHOLDER".localized, text: $searchText)
                        .autocapitalization(.none)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // 类别选择器
                let categories = soundManager.categories
                if categories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category,
                                    count: soundManager.getSounds(in: category).count
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6).opacity(0.5))
                }
                
                // 音效列表
                List {
                    let sounds = filteredSounds
                    
                    if sounds.isEmpty {
                        EmptySoundView(searchText: searchText)
                    } else {
                        ForEach(sounds) { sound in
                            UnifiedSoundOptionRow(
                                sound: sound,
                                isSelected: soundManager.selectedSound?.id == sound.id,
                                isPlaying: playingSound?.id == sound.id,
                                onPlay: { playSound(sound) },
                                onSelect: { selectSound(sound) }
                            )
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("SOUND_SELECTION_TITLE".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CANCEL_BUTTON".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if soundManager.selectedSound != nil {
                        Button("APPLY_BUTTON".localized) {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private var filteredSounds: [UnifiedSoundManager.SoundOption] {
        var sounds = soundManager.availableSounds
        
        // 按类别过滤
        if selectedCategory != "All" {
            sounds = soundManager.getSounds(in: selectedCategory)
        }
        
        // 按搜索词过滤
        if !searchText.isEmpty {
            sounds = soundManager.searchSounds(query: searchText)
        }
        
        return sounds
    }
    
    private func playSound(_ sound: UnifiedSoundManager.SoundOption) {
        // 停止当前播放
        playingSound = nil
        
        // 播放新声音
        playingSound = sound
        soundManager.playSound(sound)
        
        // 2秒后重置播放状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if playingSound?.id == sound.id {
                playingSound = nil
            }
        }
    }
    
    private func selectSound(_ sound: UnifiedSoundManager.SoundOption) {
        soundManager.selectSound(sound)
        HapticManager.shared.playClick()
    }
}

// 类别标签组件
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            .foregroundColor(isSelected ? .white : .blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(Color.blue, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 空状态视图
struct EmptySoundView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            if searchText.isEmpty {
                Text("NO_SOUNDS_AVAILABLE".localized)
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 8) {
                    Text("NO_SOUNDS_FOUND".localized)
                        .foregroundColor(.gray)
                    
                    Text("TRY_DIFFERENT_SEARCH_TERM".localized)
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// 音效选项行组件（重命名以避免冲突）
struct UnifiedSoundOptionRow: View {
    let sound: UnifiedSoundManager.SoundOption
    let isSelected: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 播放按钮
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "waveform" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isPlaying ? .blue : .gray)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sound.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .primary)
                
                Text(sound.description)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text(sound.category)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(sound.type == .system ? "SOUND_TYPE_SYSTEM".localized : "SOUND_TYPE_CUSTOM".localized)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            sound.type == .system ?
                                Color.orange.opacity(0.2) :
                                Color.green.opacity(0.2)
                        )
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // 选中状态指示器
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}
