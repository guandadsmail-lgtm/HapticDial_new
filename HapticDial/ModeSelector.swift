// Views/ModeSelector.swift
import SwiftUI
import CoreGraphics
import Combine

struct ModeSelector: View {
    @Binding var selectedMode: DialMode
    @Namespace private var animation
    
    // 颜色定义
    private let gearColor = Color(red: 1.0, green: 0.4, blue: 0.2)    // 齿轮红色
    private let bubbleColor = Color(red: 0.2, green: 0.8, blue: 1.0)  // 气泡蓝色
    private let selectedBgColor = Color.white.opacity(0.15)           // 选中背景
    private let unselectedBgColor = Color.white.opacity(0.08)         // 未选中背景
    private let outerBgColor = Color.white.opacity(0.05)              // 外层背景
    
    // 可配置的尺寸参数
    let width: CGFloat  // 总宽度
    let height: CGFloat = 76     // 总高度增加
    let cornerRadius: CGFloat = 20 // 更大的圆角
    let innerCornerRadius: CGFloat = 16 // 内层圆角
    let buttonPadding: CGFloat = 4      // 减少内边距
    let outerPadding: CGFloat = 8       // 减少外层边距
    let selectionPadding: CGFloat = 3   // 选中状态的额外内边距
    
    var body: some View {
        ZStack {
            // 外层背景 - 使用更精致的iOS风格
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(outerBgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        .blendMode(.overlay)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
            
            HStack(spacing: buttonPadding) {
                ForEach(DialMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMode = mode
                        }
                        HapticManager.shared.playClick()
                    }) {
                        ZStack {
                            // 选中状态背景
                            if selectedMode == mode {
                                RoundedRectangle(cornerRadius: innerCornerRadius)
                                    .fill(selectedBgColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: innerCornerRadius)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        (mode == .ratchet ? gearColor : bubbleColor).opacity(0.5),
                                                        (mode == .ratchet ? gearColor : bubbleColor).opacity(0.2)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .matchedGeometryEffect(id: "background", in: animation)
                                    .shadow(color: (mode == .ratchet ? gearColor : bubbleColor).opacity(0.15), radius: 2, x: 0, y: 1)
                            }
                            
                            // 未选中状态背景
                            else {
                                RoundedRectangle(cornerRadius: innerCornerRadius)
                                    .fill(unselectedBgColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: innerCornerRadius)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                    )
                            }
                            
                            VStack(spacing: 6) {
                                // 图标
                                ZStack {
                                    if mode == .ratchet {
                                        // 齿轮图标
                                        Circle()
                                            .stroke(lineWidth: 2)
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(gearColor)
                                        
                                        // 齿轮齿
                                        ForEach(0..<8) { index in
                                            Rectangle()
                                                .frame(width: 4, height: 8)
                                                .foregroundColor(gearColor)
                                                .offset(y: -11)
                                                .rotationEffect(.degrees(Double(index) * 45))
                                        }
                                    } else {
                                        // 光圈图标
                                        Circle()
                                            .stroke(lineWidth: 1.5)
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(bubbleColor)
                                        
                                        // 光圈叶片
                                        ForEach(0..<6) { index in
                                            Capsule()
                                                .frame(width: 3, height: 8)
                                                .foregroundColor(bubbleColor)
                                                .offset(y: -10)
                                                .rotationEffect(.degrees(Double(index) * 60))
                                        }
                                    }
                                }
                                .frame(width: 24, height: 24)
                                
                                // 文字 - 使用更合适的字体和颜色
                                Text(mode.displayName)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(selectedMode == mode ? .white.opacity(0.95) : .white.opacity(0.7))
                                    .tracking(0.5)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(outerPadding) // 外层内边距减少，使按钮更靠近边缘
        }
        .frame(width: width, height: height)
    }
}
