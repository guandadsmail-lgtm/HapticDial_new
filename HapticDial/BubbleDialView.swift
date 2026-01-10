// Views/BubbleDialView.swift
import SwiftUI
import Combine

struct BubbleDialView: View {
    @ObservedObject var viewModel: BubbleDialViewModel
    @State private var particlePositions: [CGPoint] = []
    @State private var particleSizes: [CGFloat] = []
    @State private var particleColors: [Color] = []
    @State private var lastUpdateTime: Date = Date()
    
    let size: CGFloat = 160
    
    // 颜色定义
    private let bubbleColor = Color(red: 0.2, green: 0.8, blue: 1.0)      // 数字颜色
    private let darkBubbleColor = Color(red: 0.1, green: 0.4, blue: 0.5) // 微粒颜色（更暗）
    private let highlightColor = Color(red: 0.4, green: 0.95, blue: 1.0)
    private let grayRingColor = Color.gray.opacity(0.15)  // 灰色环颜色
    private let tickColor = Color.white.opacity(0.7)      // 刻度线颜色
    private let majorTickColor = Color.white              // 主刻度线颜色
    private let blueBorderColor = Color(red: 0.2, green: 0.8, blue: 1.0).opacity(0.6) // 蓝色边框
    
    // 安全区域（避免中心数字区域）
    private var safeMinRadius: CGFloat { size * 0.25 }  // 中心保留25%半径给数字
    private var safeMaxRadius: CGFloat { size * 0.45 } // 避免边界
    
    // 灰色环尺寸（与齿轮转盘保持一致）
    private var grayRingSize: CGFloat { size - 40 }  // 宽度为20的环（(size - (size-40))/2 = 20）
    
    // 刻度线参数 - 调整到最外沿
    private var tickInnerRadius: CGFloat { size / 2 - 8 }  // 刻度线内径
    private var tickOuterRadius: CGFloat { size / 2 - 2 }  // 刻度线外径
    
    init(viewModel: BubbleDialViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // 背景 - 修改为与主背景不同的深蓝色渐变
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.35, green: 0.85, blue: 0.95, opacity: 0.4),  // 60%透明
                            Color(red: 0.2, green: 0.6, blue: 0.8, opacity: 0.3)      // 60%透明
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: size/2
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    bubbleColor.opacity(0.5),
                                    highlightColor.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .clipShape(Circle())
            
            // 灰色环带 - 与齿轮转盘保持一致
            Circle()
                .fill(grayRingColor)
                .frame(width: grayRingSize, height: grayRingSize)
            
            // 主刻度线（每30度一个）- 白色，沿最外沿
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * 30
                let radian = angle * Double.pi / 180
                let center = CGPoint(x: size / 2, y: size / 2)
                
                // 计算内圈和外圈的位置
                let innerX = center.x + CGFloat(tickInnerRadius * cos(radian))
                let innerY = center.y + CGFloat(tickInnerRadius * sin(radian))
                let outerX = center.x + CGFloat(tickOuterRadius * cos(radian))
                let outerY = center.y + CGFloat(tickOuterRadius * sin(radian))
                
                // 主刻度线 - 白色
                Path { path in
                    path.move(to: CGPoint(x: innerX, y: innerY))
                    path.addLine(to: CGPoint(x: outerX, y: outerY))
                }
                .stroke(majorTickColor, lineWidth: 2)
            }
            
            // 次要刻度线（每6度一个）- 白色稍暗
            ForEach(0..<60, id: \.self) { index in
                let angle = Double(index) * 6
                // 跳过主刻度位置
                if angle.truncatingRemainder(dividingBy: 30) != 0 {
                    let radian = angle * Double.pi / 180
                    let center = CGPoint(x: size / 2, y: size / 2)
                    
                    // 计算内圈和外圈的位置
                    let innerRadius = size / 2 - 6
                    let outerRadius = size / 2 - 2
                    
                    let innerX = center.x + CGFloat(innerRadius * cos(radian))
                    let innerY = center.y + CGFloat(innerRadius * sin(radian))
                    let outerX = center.x + CGFloat(outerRadius * cos(radian))
                    let outerY = center.y + CGFloat(outerRadius * sin(radian))
                    
                    // 次要刻度线 - 白色稍暗
                    Path { path in
                        path.move(to: CGPoint(x: innerX, y: innerY))
                        path.addLine(to: CGPoint(x: outerX, y: outerY))
                    }
                    .stroke(tickColor, lineWidth: 1)
                }
            }
            
            // 最外沿的蓝色细边框 - 紧贴刻度线
            Circle()
                .stroke(blueBorderColor, lineWidth: 1)
                .frame(width: size - 4, height: size - 4)
            
            // 气泡粒子 - 颜色比数字暗，放在刻度线之上
            ForEach(0..<viewModel.tapCount, id: \.self) { index in
                if index < particlePositions.count && index < particleSizes.count && index < particleColors.count {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    particleColors[index].opacity(0.9),
                                    particleColors[index].opacity(0.6)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: particleSizes[index] / 2
                            )
                        )
                        .frame(width: particleSizes[index], height: particleSizes[index])
                        .position(particlePositions[index])
                        .shadow(color: particleColors[index].opacity(0.5), radius: 4, x: 0, y: 0)
                        .zIndex(2) // 确保微粒在刻度线之上
                }
            }
            
            // 点击次数显示 - 在微粒之上，确保不被覆盖
            Text("\(viewModel.tapCount)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(bubbleColor)
                .shadow(color: bubbleColor.opacity(0.5), radius: 8, x: 0, y: 0)
                .zIndex(3) // 确保数字在微粒之上
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            bubbleColor.opacity(0.3),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onTapGesture {
            handleTap()
        }
        .onChange(of: viewModel.tapCount) {
            // 确保微粒数量与点击次数相同
            updateParticles(count: viewModel.tapCount)
        }
        .onAppear {
            // 初始化粒子
            updateParticles(count: viewModel.tapCount)
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            resetParticles()
            viewModel.resetCount()
            HapticManager.shared.playClick()
        }
        .overlay(
            // 🔴 添加 BUBBLE 标签 - 放在转盘外部下方，使用固定偏移
            Text("BUBBLE")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .offset(y: size / 2 + 20) // 🔴 放在转盘底部边缘下方20点
                .zIndex(4) // 确保在最上层
        )
        .opacity(viewModel.bubbleOpacity)
    }
    
    private func handleTap() {
        let now = Date()
        // 防止点击过快
        if now.timeIntervalSince(lastUpdateTime) > 0.1 {
            lastUpdateTime = now
            viewModel.incrementCount()
        }
    }
    
    // 生成安全区域内的随机位置，纯随机分布
    private func generateRandomPosition() -> CGPoint {
        let center = CGPoint(x: size / 2, y: size / 2)
        
        // 使用极坐标随机生成位置
        let radius = CGFloat.random(in: safeMinRadius...safeMaxRadius)
        let angle = Double.random(in: 0..<360) * Double.pi / 180
        
        let position = CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
        
        return position
    }
    
    // 生成随机颜色，比数字颜色暗
    private func generateRandomColor() -> Color {
        // 在暗色气泡颜色的基础上进行随机微调
        let hueVariation = Double.random(in: -0.05...0.05)  // 色调微调
        let saturationVariation = Double.random(in: -0.1...0.1)  // 饱和度微调
        let brightnessVariation = Double.random(in: -0.1...0)  // 亮度比基础颜色暗
        
        let baseHue: Double = 200.0 / 360.0  // 青蓝色基调
        let baseSaturation: Double = 0.7
        let baseBrightness: Double = 0.5
        
        return Color(
            hue: max(0, min(1, baseHue + hueVariation)),
            saturation: max(0.4, min(0.9, baseSaturation + saturationVariation)),
            brightness: max(0.3, min(0.6, baseBrightness + brightnessVariation))
        )
    }
    
    private func updateParticles(count: Int) {
        // 确保粒子数量等于点击次数
        if count > particlePositions.count {
            // 需要添加更多粒子
            let newParticleCount = count - particlePositions.count
            for _ in 0..<newParticleCount {
                // 纯随机位置
                let position = generateRandomPosition()
                
                // 随机大小（6-12像素）
                let size = CGFloat.random(in: 6...12)
                
                // 随机颜色（比数字颜色暗）
                let color = generateRandomColor()
                
                particlePositions.append(position)
                particleSizes.append(size)
                particleColors.append(color)
            }
        } else if count < particlePositions.count {
            // 需要移除粒子（重置时）
            particlePositions.removeLast(particlePositions.count - count)
            particleSizes.removeLast(particleSizes.count - count)
            particleColors.removeLast(particleColors.count - count)
        }
    }
    
    private func resetParticles() {
        withAnimation(.easeOut(duration: 0.3)) {
            particlePositions.removeAll()
            particleSizes.removeAll()
            particleColors.removeAll()
        }
    }
}
