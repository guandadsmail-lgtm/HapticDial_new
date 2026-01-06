// Views/BuiltInSoundPickerView.swift - 扁平结构适配版
import SwiftUI
import AVFoundation
import Combine

struct BuiltInSoundPickerView: View {
    @Environment(\.dismiss) var dismiss
    
    // 修复：使用 StateObject 而不是 ObservedObject，因为这是视图自己的数据
    @StateObject private var soundManager = BuiltInSoundsManager.shared
    
    @State private var selectedSound: BuiltInSoundsManager.BuiltInSound?
    @State private var playingSound: BuiltInSoundsManager.BuiltInSound?
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search sounds...", text: $searchText)
                        .autocapitalization(.none)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // 类别选择器（如果有很多声音）
                if soundManager.getSoundCategories().count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // 全部类别
                            CategoryChip(
                                title: "All",
                                isSelected: selectedCategory == "All",
                                count: soundManager.availableSounds.count
                            ) {
                                selectedCategory = "All"
                            }
                            
                            // 各个类别
                            ForEach(soundManager.getSoundCategories(), id: \.self) { category in
                                if category != "All" {  // 排除"All"，因为我们已经单独处理了
                                    CategoryChip(
                                        title: category,
                                        isSelected: selectedCategory == category,
                                        count: soundManager.getSounds(in: category).count
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6).opacity(0.5))
                }
                
                // 声音列表
                List {
                    let sounds = filteredSounds
                    
                    if sounds.isEmpty {
                        EmptySoundView(searchText: searchText)
                    } else {
                        ForEach(sounds) { sound in
                            SoundRow(
                                sound: sound,
                                isSelected: selectedSound?.id == sound.id,
                                isPlaying: playingSound?.id == sound.id,
                                onPlay: { playSound(sound) },
                                onSelect: { selectSound(sound) }
                            )
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Sound Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedSound != nil {
                        Button("Use Sound") {
                            applySelectedSound()
                            dismiss()
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private var filteredSounds: [BuiltInSoundsManager.BuiltInSound] {
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
    
    private func playSound(_ sound: BuiltInSoundsManager.BuiltInSound) {
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
    
    private func selectSound(_ sound: BuiltInSoundsManager.BuiltInSound) {
        selectedSound = sound
        // 可以添加触感反馈
        // HapticManager.shared.playClick()
    }
    
    private func applySelectedSound() {
        guard let sound = selectedSound else { return }
        
        // 应用选中的声音到你的应用逻辑
        print("✅ 应用声音: \(sound.name)")
        
        // 这里可以添加你的自定义逻辑，比如：
        // - 保存用户偏好
        // - 更新当前声音设置
        // - 创建声音组合等
        
        // 播放确认声音
        soundManager.playSound(sound)
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
                Text("No sounds available")
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 8) {
                    Text("No sounds found")
                        .foregroundColor(.gray)
                    
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// 声音行组件 - 修复 fileSize 使用方式
struct SoundRow: View {
    let sound: BuiltInSoundsManager.BuiltInSound
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(sound.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .primary)
                
                HStack(spacing: 8) {
                    Text(sound.fileName)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    if sound.duration > 0 {
                        Text("\(String(format: "%.1f", sound.duration))s")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    // 修复：使用 formattedFileSize 而不是直接计算
                    Text(sound.formattedFileSize)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
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
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}
