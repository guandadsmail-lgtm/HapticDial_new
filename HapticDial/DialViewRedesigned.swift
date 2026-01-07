// Views/DialViewRedesigned.swift
import SwiftUI
import Combine

struct DialViewRedesigned: View {
    @ObservedObject var viewModel: DialViewModel
    @State private var isDragging = false
    @State private var particleOpacity: Double = 0.0
    @State private var particleRotation: Double = 0.0
    
    // 红色轨迹相关状态
    @State private var trailStartAngle: Double = 90.0  // 起始角度（12点方向）
    @State private var trailEndAngle: Double = 90.0    // 当前结束角度
    @State private var previousAngle: Double = 0.0     // 用于检测旋转方向
    @State private var trailOpacity: Double = 1.0      // 轨迹透明度
    @State private var shouldAnimateTrail: Bool = false // 是否需要动画
    
    let dialSize: CGFloat = 320
    let innerRadius: CGFloat = 105     // 中心圆的半径（从100调整到105）
    let outerRadius: CGFloat = 145     // 灰色刻度环的中心半径
    let grayRingWidth: CGFloat = 22    // 灰色圆环宽度
    let dotRadius: CGFloat = 180       // 荧光圆点的半径
    
    // 荧光颜色
    private let fluorescentColor = Color(red: 0.8, green: 1.0, blue: 0.6)
    private let fluorescentHighlight = Color(red: 0.9, green: 1.0, blue: 0.7)
    
    // 指示器颜色
    private let bubbleBlue = Color(red: 0.2, green: 0.8, blue: 1.0)      // 气泡蓝色
    private let gearRed = Color(red: 1.0, green: 0.4, blue: 0.2)         // 齿轮红色
    
    // 红色轨迹圆环参数
    private let trailColor = Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.7)
    private let trailWidth: CGFloat = 22
    
    // 计算灰色圆环的内外半径
    private var grayRingInnerRadius: CGFloat {
        return outerRadius - grayRingWidth / 2
    }
    
    private var grayRingOuterRadius: CGFloat {
        return outerRadius + grayRingWidth / 2
    }
    
    // 计算旋转圈数
    private var rotationCount: Int {
        return Int(viewModel.totalRotation / 360)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // 背景暗色圆环
                Circle()
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                    .frame(width: dialSize, height: dialSize)
                
                // 动态粒子衬底 - 内环区域
                ParticleBackground(center: center, innerRadius: innerRadius, outerRadius: outerRadius,
                                   particleOpacity: particleOpacity, particleRotation: particleRotation)
                
                // 外圈灰色圆盘（实心盘）
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.15),
                                Color.gray.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: (grayRingOuterRadius + 5) * 2, height: (grayRingOuterRadius + 5) * 2)
                    .blur(radius: 0.5)
                
                // 红色轨迹圆环（跟随指针动态绘制）
                DynamicTrailRing(center: center, outerRadius: outerRadius, trailWidth: trailWidth,
                                 trailColor: trailColor, trailOpacity: trailOpacity,
                                 startAngle: trailStartAngle, endAngle: trailEndAngle,
                                 shouldAnimate: shouldAnimateTrail)
                
                // 荧光刻度线 - 调整到灰色圆盘位置
                FluorescentTicks(center: center, innerRadius: innerRadius, grayRingInnerRadius: grayRingInnerRadius,
                                 grayRingOuterRadius: grayRingOuterRadius, dotRadius: dotRadius,
                                 fluorescentColor: fluorescentColor, fluorescentHighlight: fluorescentHighlight)
                
                // 荧光圆点 - 放置在灰色圆盘外侧
                FluorescentDots(center: center, dotRadius: dotRadius,
                                fluorescentColor: fluorescentColor, fluorescentHighlight: fluorescentHighlight)
                
                // 内圈数字：1-12（时钟数字）- 调整位置以适应新的中心圆半径
                InnerNumbers(center: center, innerRadius: innerRadius, grayRingInnerRadius: grayRingInnerRadius)
                
                // 中心液态玻璃区域 + 中心刻度线
                CenterWithTicks(center: center, innerRadius: innerRadius, currentAngle: viewModel.currentAngle,
                                fluorescentColor: fluorescentColor)
                
                // 中心数字显示
                VStack(spacing: 5) {
                    Text("\(Int(viewModel.currentAngle.rounded()))°")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("ANGLE")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    
                    // 旋转圈数显示
                    VStack(spacing: 2) {
                        Text("\(rotationCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("TURNS")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                    }
                    .padding(.top, 8)
                }
                .zIndex(10)
                
                // 指示器（光标）- 使用气泡蓝到齿轮红的渐变
                Indicator(outerRadius: outerRadius, currentAngle: viewModel.currentAngle,
                          bubbleBlue: bubbleBlue, gearRed: gearRed)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // 启动粒子动画
                withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    particleOpacity = 0.3
                }
                
                withAnimation(Animation.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                    particleRotation = 360
                }
                
                // 初始化角度
                previousAngle = viewModel.currentAngle
            }
            .onChange(of: viewModel.currentAngle) { oldAngle, newAngle in
                updateTrailAngle(newAngle: newAngle, oldAngle: oldAngle)
            }
            .onChange(of: rotationCount) { oldValue, newValue in
                // 每旋转一圈，重置红色轨迹
                if newValue > oldValue {
                    resetTrail()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let distance = hypot(
                            value.location.x - center.x,
                            value.location.y - center.y
                        )
                        
                        // 检查触摸点是否在有效区域内
                        let isInValidZone = distance >= (innerRadius - 10) && distance <= (outerRadius + 20)
                        
                        if isInValidZone {
                            if !isDragging {
                                viewModel.handleDragStart(location: value.location, center: center)
                                isDragging = true
                                shouldAnimateTrail = false // 开始拖动时禁用动画
                            }
                            viewModel.handleDragChange(location: value.location, center: center)
                        } else {
                            // 触摸点在无效区域，忽略输入
                            if isDragging {
                                viewModel.handleDragEnd()
                                isDragging = false
                                shouldAnimateTrail = true // 结束拖动时启用动画
                            }
                        }
                    }
                    .onEnded { _ in
                        if isDragging {
                            viewModel.handleDragEnd()
                            isDragging = false
                            shouldAnimateTrail = true // 结束拖动时启用动画
                        }
                    }
            )
        }
        .frame(width: dialSize, height: dialSize)
    }
    
    /// 更新红色轨迹角度
    private func updateTrailAngle(newAngle: Double, oldAngle: Double) {
        // 计算角度变化量
        let angleDelta = newAngle - oldAngle
        
        // 调整轨迹结束角度
        trailEndAngle += angleDelta
        
        // 确保角度在0-360范围内
        trailEndAngle = normalizeAngle(trailEndAngle)
        
        // 如果反向旋转（角度减小），调整轨迹
        if angleDelta < 0 && trailEndAngle < trailStartAngle {
            // 当反向旋转越过起始点时，重置轨迹
            if trailEndAngle < trailStartAngle - 180 {
                trailEndAngle = trailStartAngle
            }
        }
        
        // 更新前一个角度
        previousAngle = newAngle
    }
    
    /// 重置红色轨迹（每转一圈时调用）
    private func resetTrail() {
        // 先淡出
        withAnimation(.easeIn(duration: 0.2)) {
            trailOpacity = 0.0
        }
        
        // 重置角度并淡入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            trailEndAngle = trailStartAngle
            withAnimation(.easeOut(duration: 0.2)) {
                trailOpacity = 1.0
            }
        }
    }
    
    /// 将角度标准化到0-360范围
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized < 0 {
            normalized += 360
        }
        while normalized >= 360 {
            normalized -= 360
        }
        return normalized
    }
}

// MARK: - 动态轨迹圆环组件

struct DynamicTrailRing: View {
    let center: CGPoint
    let outerRadius: CGFloat
    let trailWidth: CGFloat
    let trailColor: Color
    let trailOpacity: Double
    let startAngle: Double
    let endAngle: Double
    let shouldAnimate: Bool
    
    var body: some View {
        // 确保结束角度大于起始角度（顺时针方向）
        let adjustedEndAngle = endAngle >= startAngle ? endAngle : endAngle + 360
        
        Path { path in
            path.addArc(center: center,
                       radius: outerRadius,
                       startAngle: .degrees(startAngle),
                       endAngle: .degrees(adjustedEndAngle),
                       clockwise: false)
        }
        .trim(from: 0, to: 1)
        .stroke(trailColor, style: StrokeStyle(lineWidth: trailWidth, lineCap: .round, lineJoin: .round))
        .opacity(trailOpacity)
        .animation(shouldAnimate ? .easeInOut(duration: 0.1) : .none, value: endAngle)
        .animation(.easeInOut(duration: 0.2), value: trailOpacity)
        .shadow(color: trailColor.opacity(0.5), radius: 5, x: 0, y: 0)
    }
}

// MARK: - 子组件

struct ParticleBackground: View {
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let particleOpacity: Double
    let particleRotation: Double
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.01),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: innerRadius,
                        endRadius: outerRadius
                    )
                )
                .frame(width: outerRadius * 2, height: outerRadius * 2)
                .blur(radius: 2)
                .opacity(particleOpacity)
            
            // 粒子旋转动画
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * 45
                let radian = angle * Double.pi / 180
                let distance = outerRadius - 10
                let x = center.x + CGFloat(distance * cos(radian))
                let y = center.y + CGFloat(distance * sin(radian))
                
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 4
                        )
                    )
                    .frame(width: 8, height: 8)
                    .position(x: x, y: y)
                    .rotationEffect(.degrees(particleRotation))
                    .opacity(particleOpacity * 0.5)
            }
        }
    }
}

struct FluorescentTicks: View {
    let center: CGPoint
    let innerRadius: CGFloat
    let grayRingInnerRadius: CGFloat
    let grayRingOuterRadius: CGFloat
    let dotRadius: CGFloat
    let fluorescentColor: Color
    let fluorescentHighlight: Color
    
    var body: some View {
        ZStack {
            // 普通刻度线（12个）- 荧光色
            ForEach(0..<12, id: \.self) { index in
                // 逆时针旋转90度：原来的12在顶部(90°)，现在应该在原9点位置(0°)
                let adjustedIndex = (index + 9) % 12
                let angle = Double(adjustedIndex) * 30
                let radian = angle * Double.pi / 180
                
                // 检查是否是重点数字（3、6、9、12）
                let isMajor = adjustedIndex == 0 || adjustedIndex == 3 || adjustedIndex == 6 || adjustedIndex == 9
                
                // 根据是否有数字标注调整内侧起点
                // 现在数字在中间位置，所以刻度线可以从更内侧开始，避免与数字粘连
                let startRadius = grayRingInnerRadius - 0  // 从灰色圆环内侧稍微向中心延伸
                let endRadius = grayRingOuterRadius
                
                // 重点刻度线：从灰色圆盘内侧到荧光圆点
                let majorEndRadius = dotRadius - 0 // 稍微留点间距
                
                let x1 = center.x + CGFloat(startRadius * cos(radian))
                let y1 = center.y + CGFloat(startRadius * sin(radian))
                let x2 = center.x + CGFloat((isMajor ? majorEndRadius : endRadius) * cos(radian))
                let y2 = center.y + CGFloat((isMajor ? majorEndRadius : endRadius) * sin(radian))
                
                Path { path in
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                }
                .stroke(isMajor ? fluorescentHighlight : fluorescentColor, lineWidth: isMajor ? 3 : 2)
                .shadow(color: (isMajor ? fluorescentHighlight : fluorescentColor).opacity(0.8),
                       radius: isMajor ? 4 : 2, x: 0, y: 0)
            }
            
            // 次刻度线（每6度一个）- 白色，在灰色圆盘上
            ForEach(0..<60, id: \.self) { index in
                let angle = Double(index) * 6
                let radian = angle * Double.pi / 180
        
                
                // 跳过主刻度位置（每30度）
                if index % 5 != 0 {
                    let startRadius = grayRingInnerRadius + 2
                    let endRadius = grayRingOuterRadius - 2
                    
                    let x1 = center.x + CGFloat(startRadius * cos(radian))
                    let y1 = center.y + CGFloat(startRadius * sin(radian))
                    let x2 = center.x + CGFloat(endRadius * cos(radian))
                    let y2 = center.y + CGFloat(endRadius * sin(radian))
                    
                    Path { path in
                        path.move(to: CGPoint(x: x1, y: y1))
                        path.addLine(to: CGPoint(x: x2, y: y2))
                    }
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                }
            }
        }
    }
}

struct FluorescentDots: View {
    let center: CGPoint
    let dotRadius: CGFloat
    let fluorescentColor: Color
    let fluorescentHighlight: Color
    
    var body: some View {
        ForEach(0..<12, id: \.self) { index in
            // 逆时针旋转90度：原来的12在顶部(90°)，现在应该在原9点位置(0°)
            let adjustedIndex = (index + 9) % 12
            let angle = Double(adjustedIndex) * 30
            let radian = angle * Double.pi / 180
            let x = center.x + CGFloat(dotRadius * cos(radian))
            let y = center.y + CGFloat(dotRadius * sin(radian))
            
            // 3、6、9、12的圆点更大
            let isMajor = adjustedIndex == 0 || adjustedIndex == 3 || adjustedIndex == 6 || adjustedIndex == 9
            let dotSize: CGFloat = isMajor ? 14 : 10
            let glowRadius: CGFloat = isMajor ? 10 : 6
            let dotColor = isMajor ? fluorescentHighlight : fluorescentColor
            
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .position(x: x, y: y)
                .shadow(color: dotColor.opacity(0.8), radius: glowRadius, x: 0, y: 0)
                .shadow(color: dotColor.opacity(0.4), radius: glowRadius * 2, x: 0, y: 0)
        }
    }
}

struct InnerNumbers: View {
    let center: CGPoint
    let innerRadius: CGFloat
    let grayRingInnerRadius: CGFloat  // 添加灰色圆环内半径参数
    
    var body: some View {
        ForEach(0..<12, id: \.self) { index in
            // 逆时针旋转90度：原来的12在顶部(90°)，现在应该在原9点位置(0°)
            let adjustedIndex = (index + 9) % 12
            let angle = Double(adjustedIndex) * 30
            let radian = angle * Double.pi / 180
            
            // 计算数字的居中位置：中心玻璃区外沿和灰色圆环中间的居中位置
            // 中心玻璃区外沿半径 = innerRadius
            // 灰色圆环内半径 = grayRingInnerRadius
            // 居中位置 = (innerRadius + grayRingInnerRadius) / 2
            let radius = (innerRadius + grayRingInnerRadius) / 2
            
            // 数字：12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
            let innerNumber = index == 0 ? 12 : index
            let x = center.x + CGFloat(radius * cos(radian))
            let y = center.y + CGFloat(radius * sin(radian))
            
            // 3、6、9、12的字号更大
            let isMajor = adjustedIndex == 0 || adjustedIndex == 3 || adjustedIndex == 6 || adjustedIndex == 9
            let fontSize: CGFloat = isMajor ? 22 : 18
            let fontWeight: Font.Weight = isMajor ? .bold : .medium
            
            Text("\(innerNumber)")
                .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
                .foregroundColor(.white)
                .position(x: x, y: y)
        }
    }
}

struct CenterWithTicks: View {
    let center: CGPoint
    let innerRadius: CGFloat
    let currentAngle: Double
    let fluorescentColor: Color
    
    var body: some View {
        ZStack {
            // 中心液态玻璃区域（半径为110）
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.26),
                            Color.white.opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: innerRadius
                    )
                )
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .background(
                    .ultraThinMaterial,
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            // 中心刻度线（量角器样式）
            // 每10度一条短线，长刻度使用荧光色
            ForEach(0..<36, id: \.self) { index in
                let angle = Double(index) * 10
                let radian = angle * Double.pi / 180
                let tickOuterRadius = innerRadius - 5
                let isLongTick = index % 3 == 0  // 每30度一条长刻度
                let tickLength: CGFloat = isLongTick ? 12 : 8
                let tickWidth: CGFloat = isLongTick ? 1.5 : 1
                
                let x1 = center.x + CGFloat(tickOuterRadius * cos(radian))
                let y1 = center.y + CGFloat(tickOuterRadius * sin(radian))
                let x2 = center.x + CGFloat((tickOuterRadius - tickLength) * cos(radian))
                let y2 = center.y + CGFloat((tickOuterRadius - tickLength) * sin(radian))
                
                Path { path in
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                }
                .stroke(isLongTick ? fluorescentColor : Color.white.opacity(0.4), lineWidth: tickWidth)
                .shadow(color: isLongTick ? fluorescentColor.opacity(0.3) : .clear, radius: isLongTick ? 1 : 0)
            }
            
            // 当前角度指示线（荧光色）
            let currentRadian = currentAngle * Double.pi / 180
            let indicatorLength = innerRadius - 15
            
            let ix1 = center.x + CGFloat(indicatorLength * cos(currentRadian))
            let iy1 = center.y + CGFloat(indicatorLength * sin(currentRadian))
            let ix2 = center.x + CGFloat((indicatorLength - 25) * cos(currentRadian))
            let iy2 = center.y + CGFloat((indicatorLength - 25) * sin(currentRadian))
            
            Path { path in
                path.move(to: CGPoint(x: ix1, y: iy1))
                path.addLine(to: CGPoint(x: ix2, y: iy2))
            }
            .stroke(fluorescentColor, lineWidth: 2.5)
            .shadow(color: fluorescentColor.opacity(0.5), radius: 3, x: 0, y: 0)
        }
    }
}

struct Indicator: View {
    let outerRadius: CGFloat
    let currentAngle: Double
    let bubbleBlue: Color
    let gearRed: Color
    let centerRadius: CGFloat = 40
    
    var body: some View {
        ZStack {
            // 1. 中心红色圆盘底座
            RedDialBase(centerRadius: centerRadius, gearRed: gearRed)
            
            // 2. 延伸的指针（从粗到细）
            ExtendedPointer(
                outerRadius: outerRadius,
                currentAngle: currentAngle,
                bubbleBlue: bubbleBlue,
                gearRed: gearRed,
                centerRadius: centerRadius
            )
        }
    }
}

// 红色圆盘底座子视图
struct RedDialBase: View {
    let centerRadius: CGFloat
    let gearRed: Color
    
    var body: some View {
        ZStack {
            // 红色圆盘（没有白色边框）
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            gearRed.opacity(0.3),
                            gearRed.opacity(0.2),
                            gearRed.opacity(0.1)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: centerRadius
                    )
                )
                .frame(width: centerRadius * 2, height: centerRadius * 2)
                .shadow(color: gearRed.opacity(0.1), radius: 8, x: 0, y: 0)
            
            // 刻度线 - 修复为垂直圆盘
            DialBaseTicks(centerRadius: centerRadius)
        }
    }
}

// 刻度线子视图 - 修复为径向排列
struct DialBaseTicks: View {
    let centerRadius: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * 30
                let radian = angle * .pi / 180
                
                // 计算刻度线的起点和终点（径向）
                let innerX = center.x + CGFloat((centerRadius - 4) * cos(radian))
                let innerY = center.y + CGFloat((centerRadius - 4) * sin(radian))
                let outerX = center.x + CGFloat((centerRadius + 4) * cos(radian))
                let outerY = center.y + CGFloat((centerRadius + 4) * sin(radian))
                
                Path { path in
                    path.move(to: CGPoint(x: innerX, y: innerY))
                    path.addLine(to: CGPoint(x: outerX, y: outerY))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
            }
        }
        .frame(width: centerRadius * 2, height: centerRadius * 2)
    }
}

// 延伸指针子视图 - 修复指针方向
struct ExtendedPointer: View {
    let outerRadius: CGFloat
    let currentAngle: Double
    let bubbleBlue: Color
    let gearRed: Color
    let centerRadius: CGFloat
    
    // 计算指针的长度
    private var pointerLength: CGFloat {
        return outerRadius - centerRadius + 15
    }
    
    var body: some View {
        ZStack {
            // 指针阴影层
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 6, height: pointerLength)
                .offset(y: -centerRadius - (pointerLength / 2))
                .rotationEffect(.degrees(currentAngle))
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            
            // 主指针 - 粗端（红色）靠近中心，尖端（蓝色）远离中心
            ZStack {
                // 靠近中心的粗端（红色）- 内侧
                Capsule()
                    .fill(gearRed)
                    .frame(width: 8, height: pointerLength * 0.4)
                    .offset(y: -centerRadius - (pointerLength * 0.2))
                    .rotationEffect(.degrees(currentAngle))
                
                // 中间过渡部分 - 从红色过渡到蓝色
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [gearRed, bubbleBlue]),
                            startPoint: .bottom,  // 底部（靠近中心）是红色
                            endPoint: .top       // 顶部（远离中心）是蓝色
                        )
                    )
                    .frame(width: 4, height: pointerLength * 0.4)
                    .offset(y: -centerRadius - (pointerLength * 0.6))
                    .rotationEffect(.degrees(currentAngle))
                
                // 尖端较细部分（蓝色）- 外侧
                Capsule()
                    .fill(bubbleBlue)
                    .frame(width: 3, height: pointerLength * 0.4)
                    .offset(y: -centerRadius - (pointerLength * 1.0))
                    .rotationEffect(.degrees(currentAngle))
            }
            .shadow(color: bubbleBlue.opacity(0.4), radius: 4, x: 0, y: 0)
            
            // 指针顶端圆点（在最外侧）
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            bubbleBlue,
                            bubbleBlue.opacity(0.7),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 6
                    )
                )
                .frame(width: 14, height: 14)
                .offset(y: -centerRadius - pointerLength)
                .rotationEffect(.degrees(currentAngle))
                .shadow(color: bubbleBlue.opacity(0.8), radius: 4, x: 0, y: 0)
            
            // 指针底部连接点（在红色圆盘边缘）
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            gearRed,
                            gearRed.opacity(0.8)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 7
                    )
                )
                .frame(width: 16, height: 16)
                .offset(y: -centerRadius)
                .rotationEffect(.degrees(currentAngle))
                .shadow(color: gearRed.opacity(0.5), radius: 3, x: 0, y: 0)
        }
    }
}
