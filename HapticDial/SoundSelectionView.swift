import SwiftUI

struct SoundSelectionView: View {
    @StateObject private var soundManager = UnifiedSoundManager.shared
    @State private var showingFileImporter = false
    @State private var importError: String?
    @State private var showingError = false
    @State private var showingDeleteAlert = false
    @State private var soundToDelete: UnifiedSoundManager.SoundOption?
    
    var body: some View {
        List {
            // 系统音效部分
            Section(header: Text("系统音效")) {
                ForEach(soundManager.publicSystemSoundOptions, id: \.id) { sound in
                    // 先计算是否选中
                    let isSoundSelected = soundManager.selectedSound?.id == sound.id
                    
                    SoundOptionRow(
                        sound: sound,
                        isSelected: isSoundSelected,
                        onSelect: { soundManager.selectSound(sound) },
                        isCustom: false,
                        onDelete: nil
                    )
                }
            }
            
            // 自定义音效部分
            Section(header: Text("自定义音效")) {
                if soundManager.userCustomSounds.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("暂无自定义音效")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("点击下方按钮上传你的音效文件")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 30)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(soundManager.userCustomSounds, id: \.id) { sound in
                        // 先计算是否选中
                        let isSoundSelected = soundManager.selectedSound?.id == sound.id
                        
                        SoundOptionRow(
                            sound: sound,
                            isSelected: isSoundSelected,
                            onSelect: { soundManager.selectSound(sound) },
                            isCustom: true,
                            onDelete: {
                                soundToDelete = sound
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
            }
            
            // 上传按钮
            Section {
                Button(action: {
                    showingFileImporter = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("上传自定义音效")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("仅支持 .caf 格式文件")
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
        .navigationTitle("选择音效")
        .sheet(isPresented: $showingFileImporter) {
            FileImporter { url in
                importCustomSound(from: url)
            }
        }
        .alert("导入失败", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(importError ?? "未知错误")
        }
        .alert("删除音效", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let sound = soundToDelete {
                    soundManager.deleteCustomSound(sound)
                }
            }
        } message: {
            Text("确定要删除这个自定义音效吗？")
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

struct SoundOptionRow: View {
    let sound: UnifiedSoundManager.SoundOption
    let isSelected: Bool
    let onSelect: () -> Void
    let isCustom: Bool
    let onDelete: (() -> Void)?
    
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(sound.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if isCustom {
                                Text("自定义")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        
                        if sound.type == .system {
                            if sound.systemSoundID == nil {
                                Text("静音")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("系统音效")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
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
            
            if isCustom, let onDelete = onDelete {
                Button(action: {
                    showingDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                        .padding(.leading, 12)
                }
                .buttonStyle(BorderlessButtonStyle())
                .alert("确认删除", isPresented: $showingDeleteConfirm) {
                    Button("取消", role: .cancel) { }
                    Button("删除", role: .destructive) {
                        onDelete()
                    }
                } message: {
                    Text("确定要删除这个自定义音效吗？")
                }
            }
        }
    }
}
