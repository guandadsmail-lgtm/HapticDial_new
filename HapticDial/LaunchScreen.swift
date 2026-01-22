// Views/LaunchScreen.swift
import SwiftUI
import Combine

struct LaunchScreen: View {
    @State private var ringProgress: CGFloat = 0.0
    @State private var trailLength: CGFloat = 0.0
    @State private var trailOpacity: Double = 0.0
    @State private var particleScale: CGFloat = 1.0
    @State private var particleOpacity: Double = 1.0
    @State private var glowIntensity: Double = 0.0
    @State private var isAnimating = false
    
    // 颜色定义
    private let gearColor = Color(red: 1.0, green: 0.4, blue: 0.2)    // 齿轮红色
    private let bubbleColor = Color(red: 0.2, green: 0.8, blue: 1.0)  // 气泡蓝色
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            ZStack {
                // 星空背景
                Color(red: 0.03, green: 0.03, blue: 0.08)
                    .ignoresSafeArea()
                
                // 星空粒子 - 使用 GeometryReader 的尺寸
                if screenWidth > 0 && screenHeight > 0 {
                    ForEach(0..<30) { index in
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: CGFloat.random(in: 1...3))
                            .position(
                                x: CGFloat.random(in: 0...screenWidth),
                                y: CGFloat.random(in: 0...screenHeight)
                            )
                            .blur(radius: 0.5)
                    }
                }
                
                VStack(spacing: 30) {
                    // 主光环容器
                    ZStack {
                        // 背景辉光
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        gearColor.opacity(0.1),
                                        bubbleColor.opacity(0.05),
                                        .clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 20
                            )
                            .frame(width: 180, height: 180)
                            .blur(radius: 10)
                            .scaleEffect(glowIntensity * 2 + 1)
                            .opacity(glowIntensity * 0.8)
                        
                        // 外部光环（静态）
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        gearColor.opacity(0.3),
                                        bubbleColor.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 1)
                        
                        // 主绘制光环
                        Circle()
                            .trim(from: 0.0, to: ringProgress)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        gearColor,
                                        Color(red: 1.0, green: 0.6, blue: 0.4), // 橙色
                                        Color(red: 0.8, green: 0.7, blue: 0.8), // 紫色过渡
                                        bubbleColor
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(
                                    lineWidth: 8,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: gearColor.opacity(0.5), radius: 10, x: 0, y: 0)
                            .shadow(color: bubbleColor.opacity(0.5), radius: 10, x: 0, y: 0)
                            .overlay(
                                // 头部亮点
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                .white,
                                                gearColor,
                                                .clear
                                            ]),
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 10
                                        )
                                    )
                                    .frame(width: 16, height: 16)
                                    .offset(x: 0, y: -60)
                                    .rotationEffect(.degrees(Double(ringProgress * 360)))
                                    .blur(radius: 2)
                                    .opacity(ringProgress > 0.95 ? 1 : 0)
                            )
                        
                        // 彗星尾巴 - 修复潜在的范围错误
                        if trailLength > 0 && trailOpacity > 0 {
                            Path { path in
                                let angle = Double(ringProgress * 360) - 90
                                let radian = angle * Double.pi / 180
                                let startX = 60 * cos(radian)
                                let startY = 60 * sin(radian)
                                
                                path.move(to: CGPoint(x: startX, y: startY))
                                
                                // 确保步骤数为正数
                                let steps = Int(trailLength * 50)
                                if steps > 0 {
                                    for i in 1...steps {
                                        let pointLength = CGFloat(i) * 3
                                        let pointAngle = angle + Double(i) * 5
                                        let pointRadian = pointAngle * Double.pi / 180
                                        let pointX = (60 + pointLength) * cos(pointRadian)
                                        let pointY = (60 + pointLength) * sin(pointRadian)
                                        
                                        path.addLine(to: CGPoint(x: pointX, y: pointY))
                                    }
                                }
                            }
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .white,
                                        bubbleColor.opacity(0.8),
                                        gearColor.opacity(0.6),
                                        .clear
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(
                                    lineWidth: 4,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .frame(width: 120, height: 120)
                            .opacity(trailOpacity)
                            .blur(radius: 2)
                        }
                        
                        // 粒子效果
                        ForEach(0..<10) { index in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            .white,
                                            index % 2 == 0 ? gearColor : bubbleColor,
                                            .clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 4
                                    )
                                )
                                .frame(width: CGFloat.random(in: 2...6), height: CGFloat.random(in: 2...6))
                                .offset(x: CGFloat.random(in: -70...70), y: CGFloat.random(in: -70...70))
                                .scaleEffect(particleScale)
                                .opacity(particleOpacity * Double.random(in: 0.3...0.7))
                                .blur(radius: 1)
                        }
                    }
                    
                    // 文字 "ARC"
                    VStack(spacing: 8) {
                        Text("Knob Spinner")
                            .font(.system(size: 42, weight: .thin, design: .rounded))
                            .foregroundColor(.white)
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        gearColor.opacity(0.8),
                                        bubbleColor.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .mask(
                                    Text("ARC")
                                        .font(.system(size: 42, weight: .thin, design: .rounded))
                                )
                            )
                            .shadow(color: bubbleColor.opacity(0.5), radius: 10, x: 0, y: 0)
                        
                        Text("HAPTIC DIAL")
                            .font(.system(size: 14, weight: .light, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(3)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.easeInOut(duration: 0.5).delay(1.8), value: isAnimating)
                    }
                }
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // 第一阶段：光环绘制
        withAnimation(.easeOut(duration: 1.5)) {
            ringProgress = 1.0
        }
        
        // 第二阶段：光环脉冲和辉光
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
        
        // 第三阶段：彗星尾巴
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                trailLength = 1.0
                trailOpacity = 1.0
            }
            
            // 粒子爆发
            withAnimation(.easeOut(duration: 0.5)) {
                particleScale = 3.0
            }
            withAnimation(.easeIn(duration: 0.7)) {
                particleOpacity = 0.0
            }
            
            // 文字显示
            isAnimating = true
        }
        
        // 第四阶段：光环淡出和尾巴收回
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                trailOpacity = 0.0
                trailLength = 0.0
                glowIntensity = 0.0
            }
        }
    }
}
