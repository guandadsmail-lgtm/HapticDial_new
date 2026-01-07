// Views/HorizontalSoundPicker.swift
import SwiftUI
import Combine

struct HorizontalSoundPicker: View {
    @StateObject private var soundManager = UnifiedSoundManager.shared
    @StateObject private var hapticManager = HapticManager.shared
    @State private var selectedIndex = 0
    @State private var offset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var velocity: CGFloat = 0
    @State private var lastOffset: CGFloat = 0
    @State private var lastTime: Date = Date()
    
    // 获取所有音效
    private var allSounds: [UnifiedSoundManager.SoundOption] {
        return soundManager.availableSounds
    }
    
    // 计算每页显示的音效数量
    private let itemsPerPage = 5
    private let itemSpacing: CGFloat = 12
    private let itemSize: CGFloat = 36 // 统一调整为36
    
    // 加号按钮点击回调
    var onAddSound: (() -> Void)?
    
    // 缩放比例参数
    var scaleFactor: CGFloat = 1.0
    var isLandscape: Bool = false
    
    var body: some View {
        VStack(spacing: 8 * scaleFactor) {
            // 标题
            Text("SOUND SELECTION")
                .font(.system(size: 13 * scaleFactor, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .tracking(1)
                .padding(.top, 8 * scaleFactor)
            
            GeometryReader { geometry in
                let itemWidth = (itemSize + itemSpacing) * scaleFactor
                let screenWidth = geometry.size.width
                
                // 水平滚动音效选择器
                ZStack {
                    // 背景容器
                    RoundedRectangle(cornerRadius: 16 * scaleFactor)
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 60 * scaleFactor)
                    
                    // 横屏时添加居中线
                    if isLandscape {
                        VStack(spacing: 0) {
                            Spacer()
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 2, height: 40 * scaleFactor)
                            Spacer()
                        }
                    }
                    
                    HStack(spacing: itemSpacing * scaleFactor) {
                        // 音效项
                        ForEach(Array(allSounds.enumerated()), id: \.element.id) { index, sound in
                            SoundItemView(
                                sound: sound,
                                index: index,
                                isSelected: index == selectedIndex,
                                itemSize: itemSize * scaleFactor,
                                color: colorForIndex(index)
                            )
                            .onTapGesture {
                                selectSoundAtIndex(index)
                            }
                            .id(index)
                        }
                        
                        // 添加更多音效按钮 - 使用ZStack确保垂直居中
                        Button(action: {
                            hapticManager.playClick()
                            onAddSound?()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: itemSize * scaleFactor, height: itemSize * scaleFactor)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 16 * scaleFactor, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(width: itemSize * scaleFactor, height: itemSize * scaleFactor)
                        }
                        .id("addButton")
                    }
                    .padding(.horizontal, 16 * scaleFactor)
                    .offset(x: offset + dragOffset)
                }
                .frame(height: 60 * scaleFactor)
                .onAppear {
                    // 找到当前选中的音效索引
                    if let sound = soundManager.selectedSound,
                       let index = allSounds.firstIndex(where: { $0.id == sound.id }) {
                        selectedIndex = index
                        // 计算偏移量使选中的音效居中
                        updateOffset(for: index, screenWidth: screenWidth, itemWidth: itemWidth)
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation.width
                            
                            // 计算速度
                            let currentTime = Date()
                            let timeDelta = currentTime.timeIntervalSince(lastTime)
                            if timeDelta > 0 {
                                velocity = (value.translation.width - lastOffset) / CGFloat(timeDelta)
                            }
                            lastOffset = value.translation.width
                            lastTime = currentTime
                            
                            // 液态玻璃效果：轻微反弹
                            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                // 无状态更新，仅用于动画效果
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            // 计算最终位置
                            let threshold: CGFloat = itemWidth * 0.3
                            let finalVelocity = value.predictedEndTranslation.width - value.translation.width
                            
                            // 液态玻璃效果：弹性反弹
                            var targetIndex = selectedIndex
                            
                            if dragOffset < -threshold || (abs(dragOffset) > 20 && finalVelocity < -100) {
                                // 向左滑动
                                targetIndex = min(selectedIndex + 1, allSounds.count)
                            } else if dragOffset > threshold || (abs(dragOffset) > 20 && finalVelocity > 100) {
                                // 向右滑动
                                targetIndex = max(selectedIndex - 1, 0)
                            } else {
                                // 根据位置选择最近的音效
                                let currentCenter = -offset - dragOffset + screenWidth / 2
                                targetIndex = Int(round(currentCenter / itemWidth))
                                targetIndex = max(0, min(targetIndex, allSounds.count))
                            }
                            
                            // 应用弹性动画
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                                selectedIndex = targetIndex
                                updateOffset(for: targetIndex, screenWidth: screenWidth, itemWidth: itemWidth)
                                dragOffset = 0
                            }
                            
                            // 如果选择了音效（不是加号按钮）
                            if targetIndex < allSounds.count {
                                selectSoundAtIndex(targetIndex)
                            }
                            
                            // 重置速度
                            velocity = 0
                        }
                )
                .onChange(of: soundManager.selectedSound) { _, newSound in
                    // 当外部改变选中的音效时，更新位置
                    if let index = allSounds.firstIndex(where: { $0.id == newSound?.id }) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            selectedIndex = index
                            updateOffset(for: index, screenWidth: screenWidth, itemWidth: itemWidth)
                        }
                    }
                }
            }
            .frame(height: 60 * scaleFactor)
        }
        .frame(height: 85 * scaleFactor)
    }
    
    private func updateOffset(for index: Int, screenWidth: CGFloat, itemWidth: CGFloat) {
        let scaledItemSize = itemSize * scaleFactor
        let scaledPadding = 16 * scaleFactor
        let centerOffset = CGFloat(index) * itemWidth
        let targetOffset = -centerOffset + screenWidth / 2 - (scaledItemSize / 2) - scaledPadding
        offset = targetOffset
    }
    
    private func selectSoundAtIndex(_ index: Int) {
        guard index < allSounds.count else { return }
        
        let sound = allSounds[index]
        soundManager.selectSound(sound)
        hapticManager.playClick()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            selectedIndex = index
        }
    }
    
    // Google Material Design 颜色配置
    private func colorForIndex(_ index: Int) -> Color {
        let googleColors: [Color] = [
            Color(red: 0.26, green: 0.52, blue: 0.96), // Google Blue
            Color(red: 0.92, green: 0.26, blue: 0.21), // Google Red
            Color(red: 0.20, green: 0.66, blue: 0.33), // Google Green
            Color(red: 1.00, green: 0.76, blue: 0.03), // Google Yellow
            Color(red: 1.00, green: 0.44, blue: 0.20), // Google Orange
            Color(red: 0.61, green: 0.15, blue: 0.69), // Google Purple
            Color(red: 0.00, green: 0.74, blue: 0.83), // Google Cyan
            Color(red: 0.40, green: 0.23, blue: 0.72), // Google Deep Purple
            Color(red: 0.30, green: 0.69, blue: 0.31), // Google Light Green
            Color(red: 0.88, green: 0.22, blue: 0.42), // Google Pink
        ]
        
        // 确保相邻音效颜色不同
        let colorIndex = index % googleColors.count
        return googleColors[colorIndex]
    }
}

// 音效项视图
struct SoundItemView: View {
    let sound: UnifiedSoundManager.SoundOption
    let index: Int
    let isSelected: Bool
    let itemSize: CGFloat
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            // 音效图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.9))
                    .frame(width: isSelected ? itemSize + 4 : itemSize, 
                           height: isSelected ? itemSize + 4 : itemSize)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.white : Color.clear, 
                                   lineWidth: isSelected ? 2 : 0)
                    )
                    .shadow(color: color.opacity(isSelected ? 0.5 : 0.3), 
                           radius: isSelected ? 4 : 2, 
                           x: 0, y: isSelected ? 2 : 1)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                
                Text(sound.firstLetter)
                    .font(.system(size: isSelected ? 14 : 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
                
                // 自定义标记
                if sound.isUserCustom {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Text("C")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 10, y: -10)
                        .shadow(color: .blue.opacity(0.5), radius: 1, x: 0, y: 0.5)
                }
            }
            
            // 音效名称
            Text(sound.name)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? color : .white.opacity(0.8))
                .lineLimit(1)
                .frame(width: itemSize + 12)
        }
        .frame(width: itemSize, height: itemSize + 20)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}
