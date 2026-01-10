// Views/DialViewRedesigned.swift
import SwiftUI
import Combine

struct DialViewRedesigned: View {
    @ObservedObject var viewModel: DialViewModel
    @State private var isDragging = false
    @State private var particleOpacity: Double = 0.0
    @State private var particleRotation: Double = 0.0
    
    // 红色轨迹相关状态
    @State private var trailStartAngle: Double = 270.0  // 起始角度（12点方向）
    @State private var trailEndAngle: Double = 0.0    // 当前结束角度
    @State private var previousAngle: Double = 0.0     // 用于检测旋转方向
    @State private var trailOpacity: Double = 1.0      // 轨迹透明度
    @State private var shouldAnimateTrail: Bool = false // 是否需要动画
    
    // 机械控制相关状态
    @State private var dragStartAngle: Double = 0.0
    @State private var previousDragAngle: Double = 0.0
    @State private var dragVelocity: Double = 0.0
    @State private var lastDragTime: Date = Date()
    @State private var isInMagneticZone: Bool = false
    @State private var magneticAngle: Double = 0.0
    @State private var isAnimatingToMagnetic: Bool = false
    
    let dialSize: CGFloat = 320
    let innerRadius: CGFloat = 105     // 中心圆的半径（液态玻璃外沿）
    let outerRadius: CGFloat = 145     // 灰色刻度环的中心半径
    let grayRingWidth: CGFloat = 22    // 灰色圆环宽度
    let dotRadius: CGFloat = 180       // 荧光圆点的半径
    
    // 红色圆环参数 - 内环到中环之间
    private let redTrailInnerRadius: CGFloat = 35  // 内环外沿（液态玻璃外沿）
    private let redTrailOuterRadius: CGFloat = 135  // 中环外沿（数字环内沿）
    private let redTrailColor = Color.red
    
    // 荧光颜色
    private let fluorescentColor = Color(red: 0.8, green: 1.0, blue: 0.6)
    private let fluorescentHighlight = Color(red: 0.9, green: 1.0, blue: 0.7)
    
    // 指示器颜色
    private let bubbleBlue = Color(red: 0.2, green: 0.8, blue: 1.0)
    private let gearRed = Color(red: 1.0, green: 0.4, blue: 0.2)
    
    // 🔴 修改：机械控制参数 - 降低灵敏度，增加控制性
    private let magneticStep: Double = 5.0  // 磁吸步进角度（度数）从1度改为5度
    private let velocityDamping: Double = 0.85  // 降低速度阻尼系数，让惯性更持久
    private let magneticStrength: Double = 0.6  // 增加磁吸强度（0-1），让指针更稳定
    private let dragSensitivity: Double = 0.7  // 🔴 降低拖拽灵敏度，从1.2改为0.7
    private let minimumDragDistance: Double = 5.0  // 最小拖拽距离（角度），防止微小移动
    private let velocityThreshold: Double = 100.0  // 速度阈值，只有大于此值才应用惯性
    
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
    
    // 红色圆环的宽度
    private var redTrailWidth: CGFloat {
        return redTrailOuterRadius - redTrailInnerRadius
    }
    
    // 红色圆环的中心半径
    private var redTrailCenterRadius: CGFloat {
        return (redTrailInnerRadius + redTrailOuterRadius) / 2
    }
    
    // 🔴 新增：有效的拖拽区域半径范围
    private var validDragMinRadius: CGFloat {
        return grayRingInnerRadius - 5
    }
    
    private var validDragMaxRadius: CGFloat {
        return grayRingOuterRadius + 5
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
                
                // 内环红色轨迹圆环（从内环外沿到中环外沿，起始端在指针位置）
                InnerRedTrailRing(center: center,
                                 innerRadius: redTrailInnerRadius,
                                 outerRadius: redTrailOuterRadius,
                                 trailColor: redTrailColor,
                                 trailOpacity: trailOpacity,
                                 startAngle: trailStartAngle, // 起始角度固定为12点方向
                                 endAngle: trailEndAngle,      // 结束角度跟随指针
                                 shouldAnimate: shouldAnimateTrail)
                
                // 荧光刻度线
                FluorescentTicks(center: center, innerRadius: innerRadius, grayRingInnerRadius: grayRingInnerRadius,
                                 grayRingOuterRadius: grayRingOuterRadius, dotRadius: dotRadius,
                                 fluorescentColor: fluorescentColor, fluorescentHighlight: fluorescentHighlight)
                
                // 荧光圆点
                FluorescentDots(center: center, dotRadius: dotRadius,
                                fluorescentColor: fluorescentColor, fluorescentHighlight: fluorescentHighlight)
                
                // 内圈数字：1-12（时钟数字）
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
                
                // 指示器（光标）
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
                // 初始时，红色圆环长度为0（起始和结束都在12点方向）
                trailEndAngle = trailStartAngle
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
            // 🔴 修改：改进的拖拽手势，模拟机械表指针感觉
            .gesture(
                DragGesture(minimumDistance: 5) // 🔴 增加最小拖拽距离，防止误触
                    .onChanged { value in
                        let location = value.location
                        let distance = hypot(location.x - center.x, location.y - center.y)
                        
                        // 🔴 检查是否在有效拖拽区域 - 只在灰色圆环区域
                        let isInValidZone = distance >= validDragMinRadius && distance <= validDragMaxRadius
                        
                        if isInValidZone {
                            if !isDragging {
                                // 开始拖拽
                                handleDragStart(location: location, center: center)
                                isDragging = true
                                shouldAnimateTrail = false
                            } else {
                                // 持续拖拽
                                handleDragChange(location: location, center: center)
                            }
                        } else {
                            // 手指移出有效区域
                            if isDragging {
                                handleDragEnd()
                                isDragging = false
                                shouldAnimateTrail = true
                            }
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
    }
    
    /// 处理拖拽开始
    private func handleDragStart(location: CGPoint, center: CGPoint) {
        dragStartAngle = angleFromPoint(location, center: center)
        previousDragAngle = dragStartAngle
        lastDragTime = Date()
        dragVelocity = 0.0
        
        // 播放开始拖拽的触觉反馈
        HapticManager.shared.playClick()
    }
    
    /// 处理拖拽变化（核心改进）
    private func handleDragChange(location: CGPoint, center: CGPoint) {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastDragTime)
        
        // 计算当前角度
        let currentAngle = angleFromPoint(location, center: center)
        
        // 计算角度变化（考虑跨越0/360边界）
        var angleDelta = currentAngle - previousDragAngle
        
        // 🔴 修复：正确处理跨越0/360边界的情况
        if angleDelta > 180 {
            angleDelta -= 360
        } else if angleDelta < -180 {
            angleDelta += 360
        }
        
        // 🔴 新增：过滤微小移动，防止指针乱跳
        if abs(angleDelta) < minimumDragDistance {
            // 角度变化太小，忽略
            return
        }
        
        // 计算速度
        if timeDelta > 0 {
            dragVelocity = angleDelta / timeDelta * dragSensitivity
            
            // 🔴 限制最大速度，防止过快
            let maxVelocity: Double = 300.0
            if dragVelocity > maxVelocity {
                dragVelocity = maxVelocity
            } else if dragVelocity < -maxVelocity {
                dragVelocity = -maxVelocity
            }
        }
        
        // 🔴 改进：应用磁吸效果（接近刻度时自动对齐）
        let snappedAngleDelta = applyMagneticSnapToAngleDelta(angleDelta)
        
        // 更新角度
        let newAngle = normalizeAngle(viewModel.currentAngle + snappedAngleDelta)
        viewModel.currentAngle = newAngle
        viewModel.totalRotation += abs(snappedAngleDelta)
        
        // 更新拖拽状态
        previousDragAngle = currentAngle
        lastDragTime = now
        
        // 🔴 修改：只在经过主要刻度时播放触觉反馈
        let currentRoundedAngle = round(newAngle / 30) * 30  // 每30度一个主要刻度
        let previousRoundedAngle = round(previousAngle / 30) * 30
        
        if abs(currentRoundedAngle - previousRoundedAngle) >= 30 {
            // 轻微触觉反馈
            HapticManager.shared.playClick()
        }
        
        previousAngle = newAngle
    }
    
    /// 处理拖拽结束
    private func handleDragEnd() {
        // 🔴 修改：根据速度阈值决定是否应用惯性
        if abs(dragVelocity) > velocityThreshold {
            applyInertia()
        } else {
            // 速度太小，直接对齐到最近的刻度
            snapToNearestMagneticAngle()
            // 轻微振动反馈
            HapticManager.shared.playClick()
        }
    }
    
    /// 🔴 新增：对角度变化应用磁吸效果
    private func applyMagneticSnapToAngleDelta(_ angleDelta: Double) -> Double {
        let currentAngle = viewModel.currentAngle
        let targetAngle = normalizeAngle(currentAngle + angleDelta)
        
        // 计算最近的磁吸点（每magneticStep度一个）
        let steps = round(targetAngle / magneticStep)
        let snappedAngle = steps * magneticStep
        
        // 计算到磁吸点的距离
        let distanceToSnap = snappedAngle - targetAngle
        
        // 如果非常接近磁吸点，应用磁吸效果
        if abs(distanceToSnap) < magneticStep * 0.4 {
            // 计算磁吸强度
            let snapStrength = 1.0 - (abs(distanceToSnap) / (magneticStep * 0.4))
            
            // 应用磁吸力 - 让指针更容易停在刻度上
            let magneticPull = distanceToSnap * magneticStrength * snapStrength
            
            // 返回调整后的角度变化
            return angleDelta + magneticPull
        }
        
        return angleDelta
    }
    
    /// 惯性效果 - 修复：避免使用 weak self，因为self是结构体
    private func applyInertia() {
        // 创建局部变量来捕获当前状态
        var currentVelocity = dragVelocity
        let velocityDamping = self.velocityDamping
        
        // 使用DispatchQueue来模拟惯性，而不是Timer
        var shouldContinue = true
        
        func performInertiaStep() {
            guard shouldContinue else { return }
            
            // 应用阻尼
            currentVelocity *= velocityDamping
            
            // 如果速度太小，停止惯性
            if abs(currentVelocity) < 10.0 {
                shouldContinue = false
                snapToNearestMagneticAngle()
                return
            }
            
            // 计算角度变化
            let angleDelta = currentVelocity * 0.016 // 时间步长
            
            // 对惯性运动也应用磁吸效果
            let snappedAngleDelta = applyMagneticSnapToAngleDelta(angleDelta)
            let newAngle = normalizeAngle(viewModel.currentAngle + snappedAngleDelta)
            
            // 在主线程更新
            DispatchQueue.main.async {
                self.viewModel.currentAngle = newAngle
                self.viewModel.totalRotation += abs(snappedAngleDelta)
            }
            
            // 安排下一步
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
                if shouldContinue {
                    performInertiaStep()
                }
            }
        }
        
        // 开始惯性
        performInertiaStep()
        
        // 设置一个超时，防止无限循环
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            shouldContinue = false
        }
    }
    
    /// 对齐到最近的磁吸角度
    private func snapToNearestMagneticAngle() {
        let currentAngle = viewModel.currentAngle
        let steps = round(currentAngle / magneticStep)
        let targetAngle = steps * magneticStep
        
        // 如果已经接近目标角度，直接设置
        let angleDiff = abs(targetAngle - currentAngle)
        if angleDiff < 1.0 {
            viewModel.currentAngle = normalizeAngle(targetAngle)
        } else {
            // 使用弹簧动画平滑移动到目标角度
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.currentAngle = normalizeAngle(targetAngle)
            }
        }
        
        // 轻微触觉反馈
        HapticManager.shared.playClick()
    }
    
    /// 从点计算角度
    private func angleFromPoint(_ point: CGPoint, center: CGPoint) -> Double {
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y
        let angle = atan2(deltaY, deltaX) * 180 / .pi
        
        // 转换为0-360范围，0度在右侧（3点钟方向）
        var normalizedAngle = angle
        if normalizedAngle < 0 {
            normalizedAngle += 360
        }
        
        // 调整到12点在顶部（减去90度）
        let adjustedAngle = normalizedAngle - 90
        return normalizeAngle(adjustedAngle)
    }
    
    /// 更新红色轨迹角度
    private func updateTrailAngle(newAngle: Double, oldAngle: Double) {
        // 计算角度变化量
        let angleDelta = newAngle - oldAngle
        
        // 调整轨迹结束角度（跟随指针绘制）
        trailEndAngle += angleDelta
        
        // 确保角度在0-360范围内
        trailEndAngle = normalizeAngle(trailEndAngle)
        
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
            // 重置红色圆环，起始和结束都在12点方向
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

// MARK: - 内环红色轨迹圆环组件

struct InnerRedTrailRing: View {
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let trailColor: Color
    let trailOpacity: Double
    let startAngle: Double  // 起始角度（12点方向）
    let endAngle: Double    // 结束角度（跟随指针）
    let shouldAnimate: Bool
    
    // 计算圆环宽度
    private var trailWidth: CGFloat {
        return outerRadius - innerRadius
    }
    
    var body: some View {
        // 确保结束角度大于起始角度（顺时针方向）
        // 如果endAngle小于startAngle，说明已经转了一圈，需要加上360度
        let adjustedEndAngle = endAngle >= startAngle ? endAngle : endAngle + 360
        
        // 创建一个圆环段（从内半径到外半径）
        Path { path in
            // 绘制外圆弧（从startAngle到adjustedEndAngle）
            path.addArc(center: center,
                       radius: outerRadius,
                       startAngle: .degrees(startAngle),
                       endAngle: .degrees(adjustedEndAngle),
                       clockwise: false)
            
            // 绘制内圆弧（从adjustedEndAngle到startAngle，反向）
            path.addArc(center: center,
                       radius: innerRadius,
                       startAngle: .degrees(adjustedEndAngle),
                       endAngle: .degrees(startAngle),
                       clockwise: true)
            
            // 闭合路径
            path.closeSubpath()
        }
        .fill(trailColor)
        .opacity(trailOpacity)
        .animation(shouldAnimate ? .easeInOut(duration: 0.1) : .none, value: endAngle)
        .animation(.easeInOut(duration: 0.2), value: trailOpacity)
    }
}

// MARK: - 子组件（保持不变，使用原来的代码）

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

// 🔴 修改：延伸指针子视图 - 添加引导点击的蓝点和圆圈
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
            
            // 🔴 修改：指针顶端引导点击的蓝点和圆圈
            ZStack {
                // 外圈圆圈 - 用于强调引导，与蓝点有间隔
                Circle()
                    .stroke(bubbleBlue.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .blur(radius: 0.5)
                    .shadow(color: bubbleBlue.opacity(0.3), radius: 2, x: 0, y: 0)
                
                // 主蓝点 - 径向渐变，有发光效果
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                bubbleBlue.opacity(0.9),
                                bubbleBlue.opacity(0.7),
                                bubbleBlue.opacity(0.4)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 8
                        )
                    )
                    .frame(width: 14, height: 14)
                    .shadow(color: bubbleBlue.opacity(0.8), radius: 3, x: 0, y: 0)
            }
            .offset(y: -centerRadius - pointerLength) // 放在指针最顶端
            .rotationEffect(.degrees(currentAngle))
            
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
