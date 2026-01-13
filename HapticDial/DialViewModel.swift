// ViewModels/DialViewModel.swift - 修改版本
import Foundation
import Combine
import CoreGraphics
import AVFoundation

#if os(iOS)
import UIKit
#endif

class DialViewModel: ObservableObject {
    @Published var currentAngle: Double = 0.0
    @Published var totalRotation: Double = 0.0
    @Published var isRotating = false
    @Published var hapticEnabled = true
    @Published var soundEnabled = true
    @Published var rotationCount: Int = 0  // 新增：公开旋转圈数
    
    private let hapticManager = HapticManager.shared
    private let physicsSimulator = PhysicsSimulator()
    private var lastNotchAngle: Double = 0.0
    private var lastDragAngle: Double = 0.0
    private var cancellables = Set<AnyCancellable>()
    private var lastEffectRotation: Double = 0.0
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        physicsSimulator.$angle
            .sink { [weak self] newAngle in
                self?.currentAngle = newAngle
                self?.handleNotchFeedback(newAngle: newAngle)
            }
            .store(in: &cancellables)
        
        // 监听总旋转角度变化，更新圈数
        $totalRotation
            .sink { [weak self] newTotalRotation in
                guard let self = self else { return }
                let newRotationCount = Int(newTotalRotation / 360)
                if self.rotationCount != newRotationCount {
                    self.rotationCount = newRotationCount
                    print("🔄 旋转圈数更新: \(newRotationCount) 圈")
                    self.checkForEffect()
                }
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
        
        // 使用统一的间隔：每12度触发一次触感
        let notchInterval = 12.0
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
                }
            }
            
            // 更新最后一个刻度位置
            lastNotchAngle = lastNotchAngle + Double(notchesCrossed) * notchInterval * (deltaAngle > 0 ? 1 : -1)
        }
    }

    func resetStats() {
        totalRotation = 0
        rotationCount = 0
        lastEffectRotation = 0
    }
    
    // MARK: - 修复：检查并触发特殊效果
    
    private func checkForEffect() {
        let currentRotationCount = self.rotationCount
        
        print("🎯 检查效果触发: \(currentRotationCount) 圈")
        
        // 规则：50, 150, 250, 350 等 50 的倍数（但不包含 100, 200, 300 等 100 的倍数）出现金币雨
        // 100, 200, 300, 400 等 100 的倍数出现当前设置的特效（烟火或裂纹）
        
        if currentRotationCount >= 50 {
            // 检查是否是50的倍数但不是100的倍数（金币雨）
            if currentRotationCount % 50 == 0 && currentRotationCount % 100 != 0 {
                print("💰 触发\(currentRotationCount)圈金币雨特效！")
                triggerCoinRainEffect()
            }
            // 检查是否是100的倍数（烟火/裂纹特效）
            else if currentRotationCount % 100 == 0 {
                print("🎆 触发\(currentRotationCount)圈特效！")
                triggerCurrentEffect()
            }
        }
    }
    
    // 触发金币雨效果
    private func triggerCoinRainEffect() {
        #if os(iOS)
        // iOS平台：使用UIApplication获取窗口
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let screenSize = window.frame.size
            
            // 触发金币雨效果
            print("💰 触发金币雨效果")
            CoinManager.shared.triggerCoinRain(screenSize: screenSize)
            
            // 播放庆祝音效
            hapticManager.playClick()
        }
        #elseif os(macOS)
        // macOS平台：使用NSApplication或直接调用CoinManager
        if let screenSize = NSScreen.main?.frame.size {
            let windowSize = CGSize(width: screenSize.width, height: screenSize.height)
            
            // 触发金币雨效果
            print("💰 触发金币雨效果")
            CoinManager.shared.triggerCoinRain(screenSize: windowSize)
            
            // 播放庆祝音效
            hapticManager.playClick()
        } else {
            // 无法获取屏幕尺寸，使用默认尺寸
            print("⚠️ 无法获取屏幕尺寸，使用默认尺寸")
            CoinManager.shared.triggerCoinRain(screenSize: nil)
            hapticManager.playClick()
        }
        #else
        // 其他平台（tvOS, watchOS等）
        print("⚠️ 未知平台，使用金币雨效果")
        CoinManager.shared.triggerCoinRain(screenSize: nil)
        hapticManager.playClick()
        #endif
    }
    
    // 触发当前设置的效果（烟火或裂纹）
    private func triggerCurrentEffect() {
        #if os(iOS)
        // iOS平台：使用UIApplication获取窗口
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let screenSize = window.frame.size
            
            // 触发当前设置的特效
            print("🎆 触发当前特效")
            EffectManager.shared.triggerEffect(screenSize: screenSize)
            
            // 播放庆祝音效
            hapticManager.playClick()
        }
        #elseif os(macOS)
        // macOS平台：使用NSApplication或直接调用EffectManager
        if let screenSize = NSScreen.main?.frame.size {
            let windowSize = CGSize(width: screenSize.width, height: screenSize.height)
            
            // 触发当前设置的特效
            print("🎆 触发当前特效")
            EffectManager.shared.triggerEffect(screenSize: windowSize)
            
            // 播放庆祝音效
            hapticManager.playClick()
        } else {
            // 无法获取屏幕尺寸，使用默认尺寸
            print("⚠️ 无法获取屏幕尺寸，使用默认尺寸")
            EffectManager.shared.triggerEffect(screenSize: nil)
            hapticManager.playClick()
        }
        #else
        // 其他平台（tvOS, watchOS等）
        print("⚠️ 未知平台，使用当前特效")
        EffectManager.shared.triggerEffect(screenSize: nil)
        hapticManager.playClick()
        #endif
    }
}
