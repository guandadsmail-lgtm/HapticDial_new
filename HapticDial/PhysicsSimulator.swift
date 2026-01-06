// Core/PhysicsSimulator.swift
import Foundation
import Combine
import CoreGraphics  // 添加这个

class PhysicsSimulator: ObservableObject {
    @Published var angularVelocity: Double = 0.0
    @Published var angle: Double = 0.0
    @Published var angularAcceleration: Double = 0.0
    
    private var lastUpdateTime: Date?
    private var inertiaTimer: Timer?
    
    // 物理参数
    var damping: Double = 0.96
    var momentOfInertia: Double = 1.0
    var friction: Double = 0.002
    
    // 触摸参数
    var isTouching = false
    var touchAngularVelocity: Double = 0.0
    var lastTouchAngle: Double = 0.0
    var lastTouchTime: Date?
    
    // 防止急促触发的参数
    private var lastHapticTime: Date = Date()
    private let minHapticInterval: TimeInterval = 0.03  // 最小触觉触发间隔30ms
    
    init() {
        startPhysicsLoop()
    }
    
    private func startPhysicsLoop() {
        inertiaTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updatePhysics()
        }
    }
    
    func updatePhysics() {
        guard !isTouching else { return }
        
        let now = Date()
        let deltaTime = lastUpdateTime.map { now.timeIntervalSince($0) } ?? 0.016
        lastUpdateTime = now
        
        // 计算加速度
        angularAcceleration = -angularVelocity * friction
        
        // 更新角速度
        angularVelocity = angularVelocity + (angularAcceleration * deltaTime)
        
        // 应用阻尼
        angularVelocity = angularVelocity * damping
        
        // 更新角度
        if abs(angularVelocity) > 0.01 {
            angle = angle + (angularVelocity * deltaTime)
            angle = fmod(angle, 360.0)
            if angle < 0 {
                angle = angle + 360
            }
        } else {
            angularVelocity = 0
        }
    }
    
    func startTouch(initialAngle: Double) {
        isTouching = true
        angularVelocity = 0
        lastTouchAngle = initialAngle
        lastTouchTime = Date()
        lastHapticTime = Date()  // 重置触觉计时器
    }
    
    func updateTouch(newAngle: Double) {
        guard let lastTime = lastTouchTime else { return }
        
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastTime)
        
        if deltaTime > 0 {
            // 计算瞬时角速度
            var deltaAngle = newAngle - angle
            
            // 处理角度跨越0/360的情况
            if deltaAngle > 180 {
                deltaAngle = deltaAngle - 360
            } else if deltaAngle < -180 {
                deltaAngle = deltaAngle + 360
            }
            
            // 限制最大角速度，防止在中心区域过快的角度变化
            let maxDeltaAngle: Double = 30.0  // 每帧最大角度变化
            if abs(deltaAngle) > maxDeltaAngle {
                deltaAngle = deltaAngle > 0 ? maxDeltaAngle : -maxDeltaAngle
            }
            
            touchAngularVelocity = deltaAngle / deltaTime
            
            // 更新物理模拟的角速度
            angularVelocity = touchAngularVelocity
            
            // 直接设置角度
            angle = newAngle
        }
        
        lastTouchAngle = newAngle
        lastTouchTime = now
    }
    
    func endTouch() {
        isTouching = false
        lastUpdateTime = Date()
        
        // 保持惯性
        angularVelocity = touchAngularVelocity * 0.8
    }
    
    // 根据速度计算触觉强度（0-1），添加时间限制
    func hapticIntensityForCurrentVelocity() -> Float {
        let now = Date()
        let timeSinceLastHaptic = now.timeIntervalSince(lastHapticTime)
        
        // 如果距离上次触觉触发时间太短，返回0强度
        if timeSinceLastHaptic < minHapticInterval {
            return 0.0
        }
        
        // 更新触觉触发时间
        lastHapticTime = now
        
        let normalizedVelocity = min(abs(angularVelocity) / 800.0, 1.0)  // 降低除数，减少高速度时的强度
        return Float(0.3 + 0.5 * normalizedVelocity)  // 降低最大值，减少强度
    }
    
    deinit {
        inertiaTimer?.invalidate()
    }
}
