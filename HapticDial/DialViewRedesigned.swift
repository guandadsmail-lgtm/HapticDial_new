// Views/DialViewRedesigned.swift
import SwiftUI
import Combine

struct DialViewRedesigned: View {
    @ObservedObject var viewModel: DialViewModel
    
    // MARK: - 状态变量
    @State private var isDragging = false
    @State private var particleOpacity: Double = 0.0
    @State private var particleRotation: Double = 0.0
    
    // 红色轨迹相关
    @State private var trailStartAngle: Double = 270.0  // 12点方向 (270度)
    @State private var trailEndAngle: Double = 0.0      // 结束角度
    @State private var trailOpacity: Double = 1.0
    @State private var shouldAnimateTrail: Bool = false
    
    // 物理交互相关
    @State private var previousAngle: Double = 0.0      // 上一帧的角度（用于计算触感）
    @State private var dragStartAngle: Double = 0.0     // 拖拽开始时的角度
    @State private var previousDragAngle: Double = 0.0  // 拖拽过程中的上一帧角度
    @State private var dragVelocity: Double = 0.0       // 拖拽速度（用于惯性）
    @State private var lastDragTime: Date = Date()      // 用于计算速度的时间戳
    @State private var inertiaTimer: Timer?             // 惯性动画计时器
    
    // MARK: - 配置参数
    let dialSize: CGFloat = 320
    let innerRadius: CGFloat = 105
    let outerRadius: CGFloat = 145
    let grayRingWidth: CGFloat = 22
    let dotRadius: CGFloat = 180
    
    // 红色轨迹参数
    private let redTrailInnerRadius: CGFloat = 35
    private let redTrailOuterRadius: CGFloat = 135
    private let redTrailColor = Color.red
    
    // 配色
    private let fluorescentColor = Color(red: 0.8, green: 1.0, blue: 0.6)
    private let fluorescentHighlight = Color(red: 0.9, green: 1.0, blue: 0.7)
    private let bubbleBlue = Color(red: 0.2, green: 0.8, blue: 1.0)
    private let gearRed = Color(red: 1.0, green: 0.4, blue: 0.2)
    
    // 交互手感参数
    // 1.0 = 1:1 绝对跟随，手感最直观。
    private let dragSensitivity: Double = 1.0
    // 触感反馈的密度（每多少度震动一次），越小越绵密
    private let hapticInterval: Double = 5.0
    private let majorHapticInterval: Double = 30.0
    
    // 灰色圆环尺寸计算
    private var grayRingInnerRadius: CGFloat { outerRadius - grayRingWidth / 2 }
    private var grayRingOuterRadius: CGFloat { outerRadius + grayRingWidth / 2 }
    
    // 有效拖拽区域 (稍微放宽判定，提升体验)
    private var validDragMinRadius: CGFloat { grayRingInnerRadius - 30 }
    private var validDragMaxRadius: CGFloat { grayRingOuterRadius + 40 }
    
    private var rotationCount: Int { Int(viewModel.totalRotation / 360) }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // 1. 背景暗色圆环
                Circle()
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                    .frame(width: dialSize, height: dialSize)
                
                // 2. 动态粒子衬底
                ParticleBackground(center: center, innerRadius: innerRadius, outerRadius: outerRadius,
                                   particleOpacity: particleOpacity, particleRotation: particleRotation)
                
                // 3. 外圈灰色圆盘（磨砂质感）
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
                
                // 4. 红色轨迹
                InnerRedTrailRing(center: center,
                                 innerRadius: redTrailInnerRadius,
                                 outerRadius: redTrailOuterRadius,
                                 trailColor: redTrailColor,
                                 trailOpacity: trailOpacity,
                                 startAngle: trailStartAngle,
                                 endAngle: trailEndAngle,
                                 shouldAnimate: shouldAnimateTrail)
                
                // 5. 荧光刻度线
                FluorescentTicks(center: center, innerRadius: innerRadius, grayRingInnerRadius: grayRingInnerRadius,
                                 grayRingOuterRadius: grayRingOuterRadius, dotRadius: dotRadius,
                                 fluorescentColor: fluorescentColor, fluorescentHighlight: fluorescentHighlight)
                
                // 6. 荧光圆点
                FluorescentDots(center: center, dotRadius: dotRadius,
                                fluorescentColor: fluorescentColor, fluorescentHighlight: fluorescentHighlight)
                
                // 7. 内圈数字
                InnerNumbers(center: center, innerRadius: innerRadius, grayRingInnerRadius: grayRingInnerRadius)
                
                // 8. 中心液态玻璃与刻度
                CenterWithTicks(center: center, innerRadius: innerRadius, currentAngle: viewModel.currentAngle,
                                fluorescentColor: fluorescentColor)
                
                // 9. 中心数字显示
                VStack(spacing: 5) {
                    Text("\(Int(viewModel.currentAngle.rounded()))°")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        // iOS 16+ 数字滚动动画
                        .contentTransition(.numericText(value: viewModel.currentAngle))
                        .animation(.linear(duration: 0.1), value: viewModel.currentAngle)
                    
                    Text("ANGLE")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    
                    VStack(spacing: 2) {
                        Text("\(rotationCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .contentTransition(.numericText(value: Double(rotationCount)))
                        
                        Text("TURNS")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                    }
                    .padding(.top, 8)
                }
                .zIndex(10)
                
                // 10. 指示器指针
                Indicator(outerRadius: outerRadius, currentAngle: viewModel.currentAngle,
                          bubbleBlue: bubbleBlue, gearRed: gearRed)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 生命周期与动画初始化
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    particleOpacity = 0.3
                }
                withAnimation(Animation.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                    particleRotation = 360
                }
                previousAngle = viewModel.currentAngle
                trailEndAngle = trailStartAngle
            }
            .onChange(of: viewModel.currentAngle) { oldAngle, newAngle in
                updateTrailAngle(newAngle: newAngle, oldAngle: oldAngle)
            }
            .onChange(of: rotationCount) { oldValue, newValue in
                if newValue > oldValue { resetTrail() }
            }
            // MARK: - 核心手势逻辑
            .gesture(
                DragGesture(minimumDistance: 0) // 0死区，立即响应
                    .onChanged { value in
                        let location = value.location
                        let distance = hypot(location.x - center.x, location.y - center.y)
                        
                        // 判定是否在有效区域
                        let isInZone = distance >= (validDragMinRadius - 20) && distance <= (validDragMaxRadius + 40)
                        
                        if isInZone {
                            if !isDragging {
                                handleDragStart(location: location, center: center)
                                isDragging = true
                                shouldAnimateTrail = false
                            } else {
                                handleDragChange(location: location, center: center)
                            }
                        } else if isDragging {
                            // 即使手指滑出范围，只要没松开，继续允许控制，提升容错率
                            handleDragChange(location: location, center: center)
                        }
                    }
                    .onEnded { _ in
                        if isDragging {
                            handleDragEnd()
                            isDragging = false
                            shouldAnimateTrail = true
                        }
                    }
            )
        }
        .frame(width: dialSize, height: dialSize)
        .onDisappear {
            inertiaTimer?.invalidate()
        }
    }
    
    // MARK: - 交互逻辑实现
    
    private func handleDragStart(location: CGPoint, center: CGPoint) {
        // 停止之前的惯性
        inertiaTimer?.invalidate()
        inertiaTimer = nil
        
        dragStartAngle = angleFromPoint(location, center: center)
        previousDragAngle = dragStartAngle
        previousAngle = viewModel.currentAngle
        lastDragTime = Date()
        dragVelocity = 0.0
        
        // 捕获反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    private func handleDragChange(location: CGPoint, center: CGPoint) {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastDragTime)
        
        // 1. 获取当前手指角度
        let currentDragAngle = angleFromPoint(location, center: center)
        
        // 2. 计算差值
        var angleDelta = currentDragAngle - previousDragAngle
        
        // 处理 0/360 度边界跳跃
        if angleDelta > 180 { angleDelta -= 360 }
        else if angleDelta < -180 { angleDelta += 360 }
        
        // 3. 计算速度 (用于松手后的惯性)
        if timeDelta > 0 {
            let instantaneousVelocity = angleDelta / timeDelta
            // 低通滤波平滑速度，防止噪点
            dragVelocity = dragVelocity * 0.7 + instantaneousVelocity * 0.3
        }
        
        // 4. 更新数据 (无磁吸干扰，绝对跟随)
        let newAngle = normalizeAngle(viewModel.currentAngle + (angleDelta * dragSensitivity))
        
        // 5. 触感反馈
        checkHapticFeedback(currentAngle: newAngle, previousAngle: previousAngle)
        
        // 6. 应用更新
        viewModel.currentAngle = newAngle
        viewModel.totalRotation += abs(angleDelta * dragSensitivity)
        
        previousDragAngle = currentDragAngle
        previousAngle = newAngle
        lastDragTime = now
    }
    
    private func handleDragEnd() {
        // 如果速度够快，启动惯性；否则吸附
        if abs(dragVelocity) > 50 {
            applyInertia()
        } else {
            snapToNearestMagneticAngle()
        }
    }
    
    /// 检查并触发触感反馈
    private func checkHapticFeedback(currentAngle: Double, previousAngle: Double) {
        // 使用整数刻度来判断是否经过了触感点
        let step = hapticInterval
        let prevIndex = Int(previousAngle / step)
        let currIndex = Int(currentAngle / step)
        
        if prevIndex != currIndex {
            // 经过了刻度
            // 判断是否是主要刻度 (每30度)
            let isMajor = Int(currentAngle) % Int(majorHapticInterval) < Int(step)
            
            if isMajor {
                // 大刻度：较重的震动
                HapticManager.shared.playClick(velocity: 0.8)
            } else {
                // 小刻度：轻微的齿轮感
                HapticManager.shared.playClick(velocity: 0.3)
            }
        }
    }
    
    /// 惯性模拟
    private func applyInertia() {
        inertiaTimer?.invalidate()
        
        // 阻尼系数 (0.9 ~ 0.99)，越大滑得越远
        let friction: Double = 0.92
        let stopThreshold: Double = 5.0
        
        inertiaTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            guard let self = self as? DialViewRedesigned else { return } // 虽然Struct不能这样cast，但保留逻辑结构
            
            // 减速
            self.dragVelocity *= friction
            
            // 速度足够小则停止
            if abs(self.dragVelocity) < stopThreshold {
                timer.invalidate()
                self.snapToNearestMagneticAngle()
                return
            }
            
            let angleDelta = self.dragVelocity * 0.016
            let newAngle = self.normalizeAngle(self.viewModel.currentAngle + angleDelta)
            
            // 惯性过程中的触感
            self.checkHapticFeedback(currentAngle: newAngle, previousAngle: self.previousAngle)
            
            // 更新 UI
            self.viewModel.currentAngle = newAngle
            self.viewModel.totalRotation += abs(angleDelta)
            self.previousAngle = newAngle
        }
    }
    
    /// 磁吸吸附动画
    private func snapToNearestMagneticAngle() {
        // 吸附到最近的 5 度刻度
        let snapStep: Double = 5.0
        let targetAngle = round(viewModel.currentAngle / snapStep) * snapStep
        let normalizedTarget = normalizeAngle(targetAngle)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            viewModel.currentAngle = normalizedTarget
        }
        
        // 归位的一下轻微震动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            HapticManager.shared.playClick(velocity: 0.4)
        }
    }
    
    // MARK: - 辅助方法
    
    private func angleFromPoint(_ point: CGPoint, center: CGPoint) -> Double {
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y
        let angle = atan2(deltaY, deltaX) * 180 / .pi
        
        var normalizedAngle = angle
        if normalizedAngle < 0 { normalizedAngle += 360 }
        
        // 调整坐标系：12点为0度
        let adjustedAngle = normalizedAngle + 90
        return normalizeAngle(adjustedAngle)
    }
    
    private func updateTrailAngle(newAngle: Double, oldAngle: Double) {
        var angleDelta = newAngle - oldAngle
        if angleDelta > 180 { angleDelta -= 360 }
        else if angleDelta < -180 { angleDelta += 360 }
        trailEndAngle = normalizeAngle(trailEndAngle + angleDelta)
    }
    
    private func resetTrail() {
        withAnimation(.easeIn(duration: 0.2)) { trailOpacity = 0.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            trailEndAngle = trailStartAngle
            withAnimation(.easeOut(duration: 0.2)) { trailOpacity = 1.0 }
        }
    }
    
    private func normalizeAngle(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 360)
        if a < 0 { a += 360 }
        return a
    }
}

// MARK: - 子视图组件 (保持原样，无需修改)

struct InnerRedTrailRing: View {
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let trailColor: Color
    let trailOpacity: Double
    let startAngle: Double
    let endAngle: Double
    let shouldAnimate: Bool
    
    var body: some View {
        let adjustedEndAngle = endAngle >= startAngle ? endAngle : endAngle + 360
        Path { path in
            path.addArc(center: center, radius: outerRadius,
                       startAngle: .degrees(startAngle), endAngle: .degrees(adjustedEndAngle),
                       clockwise: false)
            path.addArc(center: center, radius: innerRadius,
                       startAngle: .degrees(adjustedEndAngle), endAngle: .degrees(startAngle),
                       clockwise: true)
            path.closeSubpath()
        }
        .fill(trailColor)
        .opacity(trailOpacity)
        .animation(shouldAnimate ? .easeInOut(duration: 0.1) : .none, value: endAngle)
        .animation(.easeInOut(duration: 0.2), value: trailOpacity)
    }
}

struct ParticleBackground: View {
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let particleOpacity: Double
    let particleRotation: Double
    
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.01), Color.clear]), center: .center, startRadius: innerRadius, endRadius: outerRadius))
                .frame(width: outerRadius * 2, height: outerRadius * 2)
                .blur(radius: 2)
                .opacity(particleOpacity)
            
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * 45
                let radian = angle * Double.pi / 180
                let distance = outerRadius - 10
                let x = center.x + CGFloat(distance * cos(radian))
                let y = center.y + CGFloat(distance * sin(radian))
                
                Circle()
                    .fill(RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.1), Color.clear]), center: .center, startRadius: 0, endRadius: 4))
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
            ForEach(0..<12, id: \.self) { index in
                let adjustedIndex = (index + 9) % 12
                let angle = Double(adjustedIndex) * 30
                let radian = angle * Double.pi / 180
                let isMajor = adjustedIndex == 0 || adjustedIndex == 3 || adjustedIndex == 6 || adjustedIndex == 9
                let startRadius = grayRingInnerRadius
                let endRadius = grayRingOuterRadius
                let majorEndRadius = dotRadius
                
                let x1 = center.x + CGFloat(startRadius * cos(radian))
                let y1 = center.y + CGFloat(startRadius * sin(radian))
                let x2 = center.x + CGFloat((isMajor ? majorEndRadius : endRadius) * cos(radian))
                let y2 = center.y + CGFloat((isMajor ? majorEndRadius : endRadius) * sin(radian))
                
                Path { path in
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                }
                .stroke(isMajor ? fluorescentHighlight : fluorescentColor, lineWidth: isMajor ? 3 : 2)
                .shadow(color: (isMajor ? fluorescentHighlight : fluorescentColor).opacity(0.8), radius: isMajor ? 4 : 2)
            }
            
            ForEach(0..<60, id: \.self) { index in
                let angle = Double(index) * 6
                let radian = angle * Double.pi / 180
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
            let adjustedIndex = (index + 9) % 12
            let angle = Double(adjustedIndex) * 30
            let radian = angle * Double.pi / 180
            let x = center.x + CGFloat(dotRadius * cos(radian))
            let y = center.y + CGFloat(dotRadius * sin(radian))
            let isMajor = adjustedIndex == 0 || adjustedIndex == 3 || adjustedIndex == 6 || adjustedIndex == 9
            let dotSize: CGFloat = isMajor ? 14 : 10
            let glowRadius: CGFloat = isMajor ? 10 : 6
            let dotColor = isMajor ? fluorescentHighlight : fluorescentColor
            
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .position(x: x, y: y)
                .shadow(color: dotColor.opacity(0.8), radius: glowRadius)
                .shadow(color: dotColor.opacity(0.4), radius: glowRadius * 2)
        }
    }
}

struct InnerNumbers: View {
    let center: CGPoint
    let innerRadius: CGFloat
    let grayRingInnerRadius: CGFloat
    
    var body: some View {
        ForEach(0..<12, id: \.self) { index in
            let adjustedIndex = (index + 9) % 12
            let angle = Double(adjustedIndex) * 30
            let radian = angle * Double.pi / 180
            let radius = (innerRadius + grayRingInnerRadius) / 2
            let innerNumber = index == 0 ? 12 : index
            let x = center.x + CGFloat(radius * cos(radian))
            let y = center.y + CGFloat(radius * sin(radian))
            let isMajor = adjustedIndex == 0 || adjustedIndex == 3 || adjustedIndex == 6 || adjustedIndex == 9
            
            Text("\(innerNumber)")
                .font(.system(size: isMajor ? 22 : 18, weight: isMajor ? .bold : .medium, design: .rounded))
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
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.26), Color.white.opacity(0.3), Color.clear]), center: .center, startRadius: 0, endRadius: innerRadius))
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            ForEach(0..<36, id: \.self) { index in
                let angle = Double(index) * 10
                let radian = angle * Double.pi / 180
                let tickOuterRadius = innerRadius - 5
                let isLongTick = index % 3 == 0
                let tickLength: CGFloat = isLongTick ? 12 : 8
                
                let x1 = center.x + CGFloat(tickOuterRadius * cos(radian))
                let y1 = center.y + CGFloat(tickOuterRadius * sin(radian))
                let x2 = center.x + CGFloat((tickOuterRadius - tickLength) * cos(radian))
                let y2 = center.y + CGFloat((tickOuterRadius - tickLength) * sin(radian))
                
                Path { path in
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                }
                .stroke(isLongTick ? fluorescentColor : Color.white.opacity(0.4), lineWidth: isLongTick ? 1.5 : 1)
            }
            
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
            .shadow(color: fluorescentColor.opacity(0.5), radius: 3)
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
            RedDialBase(centerRadius: centerRadius, gearRed: gearRed)
            ExtendedPointer(outerRadius: outerRadius, currentAngle: currentAngle, bubbleBlue: bubbleBlue, gearRed: gearRed, centerRadius: centerRadius)
        }
    }
}

struct RedDialBase: View {
    let centerRadius: CGFloat
    let gearRed: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: [gearRed.opacity(0.3), gearRed.opacity(0.2), gearRed.opacity(0.1)]), center: .center, startRadius: 0, endRadius: centerRadius))
                .frame(width: centerRadius * 2, height: centerRadius * 2)
                .shadow(color: gearRed.opacity(0.1), radius: 8)
            DialBaseTicks(centerRadius: centerRadius)
        }
    }
}

struct DialBaseTicks: View {
    let centerRadius: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * 30
                let radian = angle * .pi / 180
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

struct ExtendedPointer: View {
    let outerRadius: CGFloat
    let currentAngle: Double
    let bubbleBlue: Color
    let gearRed: Color
    let centerRadius: CGFloat
    
    private var pointerLength: CGFloat { outerRadius - centerRadius + 15 }
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 6, height: pointerLength)
                .offset(y: -centerRadius - (pointerLength / 2))
                .rotationEffect(.degrees(currentAngle))
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            
            ZStack {
                Capsule()
                    .fill(gearRed)
                    .frame(width: 8, height: pointerLength * 0.4)
                    .offset(y: -centerRadius - (pointerLength * 0.2))
                    .rotationEffect(.degrees(currentAngle))
                
                Capsule()
                    .fill(LinearGradient(gradient: Gradient(colors: [gearRed, bubbleBlue]), startPoint: .bottom, endPoint: .top))
                    .frame(width: 4, height: pointerLength * 0.4)
                    .offset(y: -centerRadius - (pointerLength * 0.6))
                    .rotationEffect(.degrees(currentAngle))
                
                Capsule()
                    .fill(bubbleBlue)
                    .frame(width: 3, height: pointerLength * 0.4)
                    .offset(y: -centerRadius - (pointerLength * 1.0))
                    .rotationEffect(.degrees(currentAngle))
            }
            .shadow(color: bubbleBlue.opacity(0.4), radius: 4)
            
            ZStack {
                Circle()
                    .stroke(bubbleBlue.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .blur(radius: 0.5)
                    .shadow(color: bubbleBlue.opacity(0.3), radius: 2)
                
                Circle()
                    .fill(RadialGradient(gradient: Gradient(colors: [bubbleBlue.opacity(0.9), bubbleBlue.opacity(0.7), bubbleBlue.opacity(0.4)]), center: .center, startRadius: 0, endRadius: 8))
                    .frame(width: 14, height: 14)
                    .shadow(color: bubbleBlue.opacity(0.8), radius: 3)
            }
            .offset(y: -centerRadius - pointerLength)
            .rotationEffect(.degrees(currentAngle))
            
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: [gearRed, gearRed.opacity(0.8)]), center: .center, startRadius: 0, endRadius: 7))
                .frame(width: 16, height: 16)
                .offset(y: -centerRadius)
                .rotationEffect(.degrees(currentAngle))
                .shadow(color: gearRed.opacity(0.5), radius: 3)
        }
    }
}
