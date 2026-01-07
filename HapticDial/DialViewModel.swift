// ViewModels/DialViewModel.swift - 简化版
import Foundation
import Combine
import CoreGraphics
import AVFoundation

class DialViewModel: ObservableObject {
    @Published var currentMode: DialMode = .ratchet
    @Published var currentAngle: Double = 0.0
    @Published var totalRotation: Double = 0.0
    @Published var isRotating = false
    @Published var hapticEnabled = true
    @Published var soundEnabled = true
    
    private let hapticManager = HapticManager.shared
    private let physicsSimulator = PhysicsSimulator()
    private var lastNotchAngle: Double = 0.0
    private var lastDragAngle: Double = 0.0
    private var cancellables = Set<AnyCancellable>()
    private var lastEffectRotation: Double = 0.0
    
    init(initialMode: DialMode = .ratchet) {
        self.currentMode = initialMode
        setupBindings()
    }
    
    private func setupBindings() {
        physicsSimulator.$angle
            .sink { [weak self] newAngle in
                self?.currentAngle = newAngle
                self?.handleNotchFeedback(newAngle: newAngle)
            }
            .store(in: &cancellables)
        
        $currentMode
            .sink { [weak self] mode in
                self?.hapticManager.currentMode = mode
            }
            .store(in: &cancellables)
    }
    
    func handleDragStart(location: CGPoint, center: CGPoint) {
        lastDragAngle = angleFromPoint(location, center: center)
        physicsSimulator.startTouch(initialAngle: lastDragAngle)
        isRotating = true
        lastNotchAngle = currentAngle
    }
    
    func handleDragChange(location: CGPoint, center: CGPoint) {
        let newAngle = angleFromPoint(location, center: center)
        
        // 计算角度变化
        var delta = newAngle - lastDragAngle
        
        // 处理0/360边界情况
        if delta > 180 {
            delta = delta - 360
        } else if delta < -180 {
            delta = delta + 360
        }
        
        // 更新当前角度
        currentAngle = currentAngle + delta
        currentAngle = fmod(currentAngle, 360.0)
        if currentAngle < 0 {
            currentAngle = currentAngle + 360
        }
        
        // 更新物理模拟
        physicsSimulator.updateTouch(newAngle: currentAngle)
        
        // 保存当前角度用于下一次计算
        lastDragAngle = newAngle
        
        // 累加总旋转
        totalRotation = totalRotation + abs(delta)
        
        // 检查是否需要触发特殊效果
        checkForEffect()
    }
    
    func handleDragEnd() {
        physicsSimulator.endTouch()
        isRotating = false
    }
    
    func isTouchInValidZone(location: CGPoint, center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) -> Bool {
        let deltaX = Double(location.x - center.x)
        let deltaY = Double(location.y - center.y)
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        // 有效区域：从内环数字到外圈刻度
        return distance >= Double(innerRadius - 10) && distance <= Double(outerRadius + 20)
    }
    
    private func angleFromPoint(_ point: CGPoint, center: CGPoint) -> Double {
        let deltaX = Double(point.x - center.x)
        let deltaY = Double(point.y - center.y)
        
        // 计算角度（弧度）: atan2(deltaY, deltaX)
        var angle = atan2(deltaY, deltaX) * 180 / Double.pi
        
        // 转换为0-360度范围
        if angle < 0 {
            angle = angle + 360
        }
        
        // 调整角度，使0°在顶部（12点方向）
        angle = angle + 90
        if angle >= 360 {
            angle = angle - 360
        }
        
        return angle
    }
    
    private func handleNotchFeedback(newAngle: Double) {
        guard hapticEnabled else { return }
        
        let notchInterval = currentMode.notchInterval
        let notchThreshold = notchInterval / 2.0
        
        // 计算角度变化
        var deltaAngle = newAngle - lastNotchAngle
        
        // 处理0/360边界
        if deltaAngle > 180 {
            deltaAngle = deltaAngle - 360
        } else if deltaAngle < -180 {
            deltaAngle = deltaAngle + 360
        }
        
        // 检查是否跨越了一个刻度
        if abs(deltaAngle) >= notchThreshold {
            // 计算跨越了几个刻度
            let notchesCrossed = Int((abs(deltaAngle) + notchThreshold) / notchInterval)
            
            // 每次跨越都触发触觉，但限制频率
            for i in 0..<notchesCrossed {
                // 添加延迟，防止急促触发
                let delay = Double(i) * 0.01
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let velocity = self.physicsSimulator.hapticIntensityForCurrentVelocity()
                    self.hapticManager.playClick(velocity: Double(min(velocity, 0.8)))
                    
                    // 播放声音（如果启用）
                    if self.soundEnabled {
                        self.playSoundForNotch()
                    }
                }
            }
            
            // 更新最后一个刻度位置
            lastNotchAngle = lastNotchAngle + Double(notchesCrossed) * notchInterval * (deltaAngle > 0 ? 1 : -1)
        }
    }

    // 播放刻度声音
    private func playSoundForNotch() {
        guard soundEnabled else { return }
        
        // 直接调用HapticManager播放声音
        HapticManager.shared.playClick()
    }

    func resetStats() {
        totalRotation = 0
        lastEffectRotation = 0
    }
    
    private func checkForEffect() {
        let currentRotationCount = Int(totalRotation / 360)
        let lastRotationCount = Int(lastEffectRotation / 360)
        
        // 每当达到100圈或100圈的整数倍时触发效果
        if currentRotationCount >= 100 && currentRotationCount % 100 == 0 && currentRotationCount > lastRotationCount {
            lastEffectRotation = totalRotation
            EffectManager.shared.triggerEffect()
        }
    }
}
