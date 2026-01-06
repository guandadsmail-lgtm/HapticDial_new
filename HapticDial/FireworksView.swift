// Views/FireworksView.swift
import SwiftUI
import Combine

struct FireworksView: View {
    @StateObject private var viewModel = FireworksViewModel()
    
    var body: some View {
        // 使用完全透明的全屏视图作为基础
        Color.clear
            .overlay(
                GeometryReader { geometry in
                    ZStack {
                        // 爆炸闪光（放在最底层）
                        ForEach(viewModel.flashes) { flash in
                            FlashView(flash: flash)
                        }
                        
                        // 爆炸粒子（放在中间层）
                        ForEach(viewModel.particles) { particle in
                            FireworkParticleView(particle: particle)
                        }
                        
                        // 烟火主体（放在最上层）
                        ForEach(viewModel.fireworks) { firework in
                            FireworkView(firework: firework, screenHeight: geometry.size.height)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(false)
                    .onAppear {
                        print("🎆 FireworksView 出现，屏幕尺寸: \(geometry.size)")
                        viewModel.screenSize = geometry.size
                        
                        // 立即开始烟火效果
                        viewModel.startFireworks()
                    }
                    .onChange(of: geometry.size) { oldSize, newSize in
                        viewModel.screenSize = newSize
                    }
                }
            )
            .ignoresSafeArea()
            .onDisappear {
                print("🎆 FireworksView 消失")
                viewModel.stopFireworks()
            }
    }
}

// 烟火状态
enum FireworkState {
    case launching   // 发射中
    case exploding   // 爆炸中
    case finished    // 结束
}

// 爆炸区域枚举
enum ExplosionZone {
    case top     // 屏幕上部 (0-0.33)
    case middle  // 屏幕中部 (0.33-0.66)
    case bottom  // 屏幕下部 (0.66-1.0)
    
    var heightRange: (CGFloat, CGFloat) {
        switch self {
        case .top:
            return (0.1, 0.3)     // 屏幕高度10%-30%
        case .middle:
            return (0.4, 0.6)     // 屏幕高度40%-60%
        case .bottom:
            return (0.7, 0.9)     // 屏幕高度70%-90%
        }
    }
}

// 烟火视图
struct FireworkView: View {
    let firework: Firework
    let screenHeight: CGFloat
    
    var body: some View {
        ZStack {
            // 发射轨迹 - 只显示一小段
            if firework.state == .launching {
                Path { path in
                    // 计算轨迹起点（当前位置后面一点）
                    let trailLength: CGFloat = 40
                    let trailStart = CGPoint(
                        x: firework.position.x - firework.velocity.x * trailLength,
                        y: firework.position.y - firework.velocity.y * trailLength
                    )
                    path.move(to: trailStart)
                    path.addLine(to: firework.position)
                }
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            firework.mainColor.opacity(0.8),
                            firework.mainColor.opacity(0.3),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            }
            
            // 烟火头
            if firework.state == .launching {
                // 核心亮点
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                .white,
                                firework.mainColor,
                                firework.mainColor.opacity(0.5)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: firework.size / 2
                        )
                    )
                    .frame(width: firework.size, height: firework.size)
                    .position(firework.position)
                    .shadow(color: firework.mainColor.opacity(0.9), radius: firework.size/2, x: 0, y: 0)
                    .blur(radius: 1)
                
                // 光晕
                Circle()
                    .fill(firework.mainColor.opacity(0.4))
                    .frame(width: firework.size * 4, height: firework.size * 4)
                    .position(firework.position)
                    .blur(radius: 8)
            }
        }
    }
}

// 烟火粒子视图
struct FireworkParticleView: View {
    let particle: FireworkParticle
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        particle.color.opacity(0.9),
                        particle.color.opacity(0.6),
                        particle.color.opacity(0.3)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: particle.size / 2
                )
            )
            .frame(width: particle.size, height: particle.size)
            .position(particle.position)
            .shadow(color: particle.color.opacity(0.5), radius: particle.size/3, x: 0, y: 0)
            .rotationEffect(.degrees(particle.rotation))
            .opacity(particle.opacity)
    }
}

// 爆炸闪光视图
struct FlashView: View {
    let flash: Flash
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0.9),
                        flash.color.opacity(0.7),
                        flash.color.opacity(0.3),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: flash.size / 2
                )
            )
            .frame(width: flash.size, height: flash.size)
            .position(flash.position)
            .blur(radius: 15)
            .opacity(flash.opacity)
    }
}

// 烟火数据模型
class Firework: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    let mainColor: Color
    var size: CGFloat
    var opacity: Double
    var state: FireworkState
    var lifeTime: TimeInterval = 0
    let maxLifeTime: TimeInterval = 5.0
    var explosionZone: ExplosionZone  // 爆炸区域
    var targetHeight: CGFloat         // 目标爆炸高度
    
    init(position: CGPoint, velocity: CGPoint, color: Color, size: CGFloat = 8, explosionZone: ExplosionZone) {
        self.position = position
        self.velocity = velocity
        self.mainColor = color
        self.size = size
        self.opacity = 1.0
        self.state = .launching
        self.explosionZone = explosionZone
        self.targetHeight = 0
    }
}

// 烟火粒子数据模型
class FireworkParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    let color: Color
    var initialSize: CGFloat
    var size: CGFloat
    var opacity: Double
    var rotation: Double
    var rotationSpeed: Double
    var lifeTime: TimeInterval = 0
    let maxLifeTime: TimeInterval = 3.5
    var explosionTime: TimeInterval = 0
    
    init(position: CGPoint, velocity: CGPoint, color: Color, size: CGFloat = 4) {
        self.position = position
        self.velocity = velocity
        self.color = color
        self.initialSize = size
        self.size = size
        self.opacity = 1.0
        self.rotation = Double.random(in: 0...360)
        self.rotationSpeed = Double.random(in: -5...5)
    }
}

// 闪光数据模型
class Flash: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    var size: CGFloat
    var opacity: Double
    var lifeTime: TimeInterval = 0
    let maxLifeTime: TimeInterval = 0.8
    
    init(position: CGPoint, color: Color, size: CGFloat = 180) {
        self.position = position
        self.color = color
        self.size = size
        self.opacity = 1.0
    }
}

// 烟火视图模型 - 重新设计，支持多区域爆炸
@MainActor
class FireworksViewModel: ObservableObject {
    @Published var fireworks: [Firework] = []
    @Published var particles: [FireworkParticle] = []
    @Published var flashes: [Flash] = []
    
    var screenSize: CGSize = .zero
    private var launchTimer: Timer?
    private var isActive = false
    private var fireworkCount = 0
    private let maxFireworks = 4
    
    // 区域计数器
    private var topExplosions = 0
    private var middleExplosions = 0
    private var bottomExplosions = 0
    private var totalExplosions = 0
    
    // 动画相关
    private var animationStartTime: Date?
    private var animationTask: Task<Void, Never>?
    
    // 用于比较 FireworkState 的辅助函数
    private func isFireworkStateEqualTo(_ firework: Firework, _ state: FireworkState) -> Bool {
        switch (firework.state, state) {
        case (.launching, .launching): return true
        case (.exploding, .exploding): return true
        case (.finished, .finished): return true
        default: return false
        }
    }
    
    func startFireworks() {
        guard screenSize.width > 0, screenSize.height > 0 else { return }
        
        isActive = true
        fireworkCount = 0
        topExplosions = 0
        middleExplosions = 0
        bottomExplosions = 0
        totalExplosions = 0
        animationStartTime = Date()
        
        print("🎆 开始烟火效果，屏幕尺寸: \(screenSize)")
        
        // 清除现有效果
        fireworks.removeAll()
        particles.removeAll()
        flashes.removeAll()
        
        // 启动动画循环
        startAnimationLoop()
        
        // 立即发射第一波烟火
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task { @MainActor in
                self.launchFireworksWave()
            }
        }
        
        // 开始发射烟火（间隔1.5-2.5秒）
        launchTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isActive {
                    self.launchFireworksWave()
                }
            }
        }
        
        // 30秒后停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            Task { @MainActor in
                print("🎆 30秒时间到，停止烟火")
                self?.stopFireworks()
            }
        }
        
        // 调试信息
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            Task { @MainActor in
                print("🎆 10秒后 - 顶部爆炸: \(self.topExplosions), 中部: \(self.middleExplosions), 底部: \(self.bottomExplosions)")
            }
        }
    }
    
    private func launchFireworksWave() {
        guard isActive, fireworkCount < maxFireworks else { return }
        
        // 每次发射1个烟火
        launchFirework()
        fireworkCount += 1
    }
    
    private func launchFirework() {
        guard isActive else { return }
        
        // 随机选择爆炸区域
        let explosionZone = selectExplosionZone()
        
        // 从屏幕底部发射
        let x = CGFloat.random(in: screenSize.width * 0.2...(screenSize.width * 0.8))
        let startPosition = CGPoint(x: x, y: screenSize.height + 50)
        
        // 随机选择颜色
        let mainColor = selectRandomColor()
        
        // 根据爆炸区域计算目标高度和速度
        let (targetHeight, velocity) = calculateLaunchParameters(for: explosionZone)
        
        let firework = Firework(
            position: startPosition,
            velocity: velocity,
            color: mainColor,
            size: 6,
            explosionZone: explosionZone
        )
        firework.targetHeight = targetHeight
        
        fireworks.append(firework)
        
        print("🎆 发射烟火到区域: \(explosionZone), 目标高度: \(targetHeight)")
        
        // 监控高度，到达目标高度时爆炸
        startHeightMonitoring(for: firework)
        
        // 安全清理：6秒后如果还没爆炸，强制清理
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let index = self.fireworks.firstIndex(where: { $0.id == firework.id }) {
                    if self.isFireworkStateEqualTo(self.fireworks[index], .launching) {
                        print("🎆 烟火超时，强制清理")
                        self.fireworks[index].state = .finished
                        self.fireworkCount -= 1
                    }
                }
            }
        }
    }
    
    private func selectExplosionZone() -> ExplosionZone {
        // 优先保证每个区域都有爆炸
        if totalExplosions == 0 {
            // 第一个烟火：顶部
            return .top
        } else if totalExplosions == 1 && topExplosions < 3 {
            // 第二个烟火：顶部
            return .top
        } else if totalExplosions == 2 && topExplosions < 3 {
            // 第三个烟火：顶部
            return .top
        } else if totalExplosions == 3 && middleExplosions < 2 {
            // 第四个烟火：中部
            return .middle
        } else if totalExplosions == 4 && middleExplosions < 2 {
            // 第五个烟火：中部
            return .middle
        } else if totalExplosions == 5 && bottomExplosions < 2 {
            // 第六个烟火：底部
            return .bottom
        } else if totalExplosions == 6 && bottomExplosions < 2 {
            // 第七个烟火：底部
            return .bottom
        } else {
            // 如果已经发射了7个，随机选择
            let random = Int.random(in: 1...100)
            if random <= 33 && topExplosions < 3 {
                return .top
            } else if random <= 66 && middleExplosions < 2 {
                return .middle
            } else if random <= 100 && bottomExplosions < 2 {
                return .bottom
            } else {
                // 如果某个区域已达上限，选择其他未达上限的区域
                if topExplosions < 3 { return .top }
                if middleExplosions < 2 { return .middle }
                if bottomExplosions < 2 { return .bottom }
                // 所有区域都达到上限，随机选择
                let zones: [ExplosionZone] = [.top, .middle, .bottom]
                return zones.randomElement() ?? .middle
            }
        }
    }
    
    private func selectRandomColor() -> Color {
        let colorIndex = Int.random(in: 0...5)
        switch colorIndex {
        case 0:
            return Color(red: 1.0, green: 0.2, blue: 0.2)  // 红色
        case 1:
            return Color(red: 1.0, green: 0.6, blue: 0.1)  // 橙色
        case 2:
            return Color(red: 1.0, green: 0.9, blue: 0.3)  // 黄色
        case 3:
            return Color(red: 0.2, green: 0.8, blue: 0.2)  // 绿色
        case 4:
            return Color(red: 0.2, green: 0.6, blue: 1.0)  // 蓝色
        default:
            return Color(red: 0.8, green: 0.2, blue: 1.0)  // 紫色
        }
    }
    
    private func calculateLaunchParameters(for zone: ExplosionZone) -> (targetHeight: CGFloat, velocity: CGPoint) {
        let (minHeightRatio, maxHeightRatio) = zone.heightRange
        
        // 随机目标高度在区域内
        let targetHeight = screenSize.height * CGFloat.random(in: minHeightRatio...maxHeightRatio)
        
        // 根据目标高度计算需要的速度
        // 从屏幕底部 (screenSize.height + 50) 到目标高度
        let distance = abs((screenSize.height + 50) - targetHeight)
        
        // 增加速度系数，确保能到达目标高度
        let baseSpeed = distance * 0.025  // 从0.015增加到0.025，增加速度
        
        // 添加一些随机变化
        let verticalSpeed = -baseSpeed * CGFloat.random(in: 0.95...1.05)
        let horizontalSpeed = CGFloat.random(in: -0.5...0.5)
        
        return (targetHeight, CGPoint(x: horizontalSpeed, y: verticalSpeed))
    }
    
    private func startHeightMonitoring(for firework: Firework) {
        let fireworkId = firework.id
        
        func checkHeight() {
            Task { @MainActor in
                guard let index = self.fireworks.firstIndex(where: { $0.id == fireworkId }) else {
                    return  // 烟火已不存在
                }
                
                let currentFirework = self.fireworks[index]
                
                // 检查是否到达或接近目标高度（增加容错范围）
                let heightDifference = currentFirework.position.y - currentFirework.targetHeight
                let isCloseToTarget = abs(heightDifference) < 30  // 30像素容错范围
                
                if self.isFireworkStateEqualTo(currentFirework, .launching) {
                    if isCloseToTarget {
                        print("🎆 烟火到达目标高度附近: \(currentFirework.position.y)，目标: \(currentFirework.targetHeight)，高度差: \(heightDifference)")
                        self.explodeFirework(at: index)
                        return
                    }
                    
                    // 检查是否到达目标高度以下
                    if currentFirework.position.y <= currentFirework.targetHeight {
                        print("🎆 烟火到达目标高度以下: \(currentFirework.position.y)，目标: \(currentFirework.targetHeight)")
                        self.explodeFirework(at: index)
                        return
                    }
                    
                    // 检查是否飞出屏幕顶部
                    if currentFirework.position.y < -100 {
                        print("🎆 烟火飞出屏幕，强制爆炸")
                        self.explodeFirework(at: index)
                        return
                    }
                    
                    // 继续检查
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
                        checkHeight()
                    }
                }
            }
        }
        
        // 开始检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
            checkHeight()
        }
    }
    
    private func explodeFirework(at index: Int) {
        guard index < fireworks.count else { return }
        
        let firework = fireworks[index]
        firework.state = .exploding
        firework.size = 0 // 烟火本体消失
        
        // 更新区域计数器
        switch firework.explosionZone {
        case .top:
            topExplosions += 1
        case .middle:
            middleExplosions += 1
        case .bottom:
            bottomExplosions += 1
        }
        totalExplosions += 1
        
        print("🎆 区域爆炸: \(firework.explosionZone), 位置: \(firework.position.y), 计数器: 顶部(\(topExplosions))/3, 中部(\(middleExplosions))/2, 底部(\(bottomExplosions))/2")
        
        // 创建爆炸闪光
        let flash = Flash(position: firework.position, color: firework.mainColor)
        flashes.append(flash)
        
        // 创建爆炸粒子
        createExplosionParticles(at: firework.position, color: firework.mainColor)
        
        // 播放触觉反馈
        let hapticVelocity = 0.8 + Double(firework.position.y / screenSize.height) * 0.4
        HapticManager.shared.playClick(velocity: hapticVelocity)
        
        // 3秒后清理
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            Task { @MainActor in
                guard let self = self, index < self.fireworks.count else { return }
                if self.isFireworkStateEqualTo(self.fireworks[index], .exploding) {
                    self.fireworks[index].state = .finished
                    self.fireworkCount -= 1
                }
            }
        }
    }
    
    private func createExplosionParticles(at position: CGPoint, color: Color) {
        // 创建爆炸粒子
        
        // 快速扩散的小粒子
        for i in 0..<80 {
            let angle = Double(i) * (360.0 / 80.0) * Double.pi / 180
            let speed = CGFloat.random(in: 10...40) / 10.0
            let velocity = CGPoint(
                x: CGFloat(cos(angle)) * speed,
                y: CGFloat(sin(angle)) * speed
            )
            
            let particleColor: Color
            let random = Int.random(in: 0...2)
            switch random {
            case 0:
                particleColor = color
            case 1:
                particleColor = Color(red: 1.0, green: 0.9, blue: 0.6) // 淡黄色
            default:
                particleColor = .white
            }
            
            let particle = FireworkParticle(
                position: position,
                velocity: velocity,
                color: particleColor,
                size: CGFloat.random(in: 2...4)
            )
            particle.explosionTime = Double.random(in: 0.1...0.3)
            particles.append(particle)
        }
        
        // 星星状的大粒子
        for _ in 0..<15 {
            let angle = Double.random(in: 0..<360) * Double.pi / 180
            let speed = CGFloat.random(in: 5...15) / 10.0
            let velocity = CGPoint(
                x: CGFloat(cos(angle)) * speed,
                y: CGFloat(sin(angle)) * speed
            )
            
            let starColor: Color
            let random = Int.random(in: 0...1)
            switch random {
            case 0:
                starColor = color
            default:
                starColor = Color(red: 1.0, green: 0.9, blue: 0.4) // 金色
            }
            
            let particle = FireworkParticle(
                position: position,
                velocity: velocity,
                color: starColor,
                size: CGFloat.random(in: 5...10)
            )
            particle.explosionTime = Double.random(in: 0.2...0.4)
            particle.rotationSpeed = Double.random(in: -8...8)
            particles.append(particle)
        }
    }
    
    private func startAnimationLoop() {
        animationTask?.cancel()
        animationStartTime = Date()
        
        animationTask = Task {
            let frameDuration: TimeInterval = 1.0/30.0 // 30 FPS
            
            while !Task.isCancelled && isActive {
                let frameStartTime = Date()
                
                // 更新物理模拟
                await MainActor.run {
                    self.updatePhysics()
                }
                
                // 计算这一帧的实际耗时
                let frameTime = Date().timeIntervalSince(frameStartTime)
                let sleepTime = max(0, frameDuration - frameTime)
                
                // 等待下一帧
                try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
            }
        }
    }
    
    private func updatePhysics() {
        // 更新烟火（发射中的）
        for i in fireworks.indices {
            fireworks[i].lifeTime += 1.0/30.0
            
            if isFireworkStateEqualTo(fireworks[i], .launching) {
                // 减少重力影响，让烟火更容易上升
                fireworks[i].velocity.y += 0.02  // 从0.03减少到0.02
                
                // 减少空气阻力，让烟火保持速度
                fireworks[i].velocity.x *= 0.999  // 从0.998增加到0.999
                
                // 更新位置
                fireworks[i].position.x += fireworks[i].velocity.x
                fireworks[i].position.y += fireworks[i].velocity.y
                
                // 烟火头大小随速度变化
                let speed = sqrt(pow(fireworks[i].velocity.x, 2) + pow(fireworks[i].velocity.y, 2))
                fireworks[i].size = max(4, 8 - speed * 0.1)
            }
            
            // 生命周期结束
            if fireworks[i].lifeTime > fireworks[i].maxLifeTime {
                fireworks[i].opacity = max(0, fireworks[i].opacity - 0.05)
            }
        }
        
        // 更新粒子
        for i in particles.indices {
            particles[i].lifeTime += 1.0/30.0
            
            let lifeRatio = 1 - (particles[i].lifeTime / particles[i].maxLifeTime)
            
            // 爆炸膨胀效果
            if particles[i].lifeTime < particles[i].explosionTime {
                // 爆炸初期：粒子快速膨胀
                let expansionRatio = particles[i].lifeTime / particles[i].explosionTime
                particles[i].size = particles[i].initialSize * (1 + expansionRatio * 3)
            } else {
                // 爆炸后期：粒子逐渐收缩并下落
                let timeSinceExplosion = particles[i].lifeTime - particles[i].explosionTime
                
                // 应用重力
                particles[i].velocity.y += 0.10
                
                // 空气阻力
                particles[i].velocity.x *= 0.99
                particles[i].velocity.y *= 0.995
                
                // 更新位置
                particles[i].position.x += particles[i].velocity.x
                particles[i].position.y += particles[i].velocity.y
                
                // 更新旋转
                particles[i].rotation += particles[i].rotationSpeed
                
                // 粒子逐渐变小
                if timeSinceExplosion > 0.5 {
                    particles[i].size = max(1, particles[i].initialSize * lifeRatio * 0.8)
                }
            }
            
            // 淡出效果
            if particles[i].lifeTime > particles[i].maxLifeTime * 0.5 {
                particles[i].opacity = max(0, lifeRatio * 1.2)
            }
            
            // 生命周期结束
            if particles[i].lifeTime > particles[i].maxLifeTime {
                particles[i].opacity = 0
            }
        }
        
        // 更新闪光
        for i in flashes.indices {
            flashes[i].lifeTime += 1.0/30.0
            
            // 快速膨胀然后淡出
            if flashes[i].lifeTime < 0.2 {
                flashes[i].size += 200
            }
            
            // 淡出效果
            if flashes[i].lifeTime > 0.1 {
                flashes[i].opacity = max(0, 1 - flashes[i].lifeTime / flashes[i].maxLifeTime)
            }
            
            // 生命周期结束
            if flashes[i].lifeTime > flashes[i].maxLifeTime {
                flashes[i].opacity = 0
            }
        }
        
        // 清理结束的粒子
        particles.removeAll { $0.opacity <= 0.01 }
        flashes.removeAll { $0.opacity <= 0.01 }
        fireworks.removeAll {
            isFireworkStateEqualTo($0, .finished) && $0.opacity <= 0.01
        }
    }
    
    func stopFireworks() {
        print("🎆 停止烟火效果")
        print("🎆 最终统计 - 顶部爆炸: \(topExplosions), 中部: \(middleExplosions), 底部: \(bottomExplosions)")
        
        guard isActive else { return }
        
        isActive = false
        animationTask?.cancel()
        animationTask = nil
        launchTimer?.invalidate()
        launchTimer = nil
        
        // 淡出所有效果
        withAnimation(.easeOut(duration: 1.5)) {
            for i in fireworks.indices {
                fireworks[i].opacity = 0
            }
            for i in particles.indices {
                particles[i].opacity = 0
            }
            for i in flashes.indices {
                flashes[i].opacity = 0
            }
        }
        
        // 2秒后清除所有
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            Task { @MainActor in
                self?.fireworks.removeAll()
                self?.particles.removeAll()
                self?.flashes.removeAll()
            }
        }
    }
    
    deinit {
        animationTask?.cancel()
        animationTask = nil
        launchTimer?.invalidate()
        launchTimer = nil
    }
}
