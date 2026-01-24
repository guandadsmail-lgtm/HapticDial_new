//
//  FireworksManager.swift
//  HapticDial
//
//  Created by [Your Name] on [Date].
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Enums

enum FireworkState {
    case launching
    case exploding
    case finished
}

enum ExplosionZone {
    case top, middle, bottom
    var heightRange: (CGFloat, CGFloat) {
        switch self {
        case .top: return (0.1, 0.35)
        case .middle: return (0.35, 0.65)
        case .bottom: return (0.65, 0.85)
        }
    }
}

// MARK: - Models

struct Firework: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    let mainColor: Color
    let targetY: CGFloat
    let zone: ExplosionZone
    var opacity: Double = 1.0
    var state: FireworkState = .launching
    var lifeTime: TimeInterval = 0
    var size: CGFloat
}

struct FireworkParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    let color: Color
    var size: CGFloat = 3
    var initialSize: CGFloat = 3
    var opacity: Double = 1.0
    var lifeTime: TimeInterval = 0
}

struct Flash: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    var size: CGFloat = 200
    var opacity: Double = 1.0
    var lifeTime: TimeInterval = 0
}

// MARK: - Manager Class

@MainActor
class FireworksManager: ObservableObject {
    static let shared = FireworksManager()
    
    @Published var showFireworks = false
    
    var fireworks: [Firework] = []
    var particles: [FireworkParticle] = []
    var flashes: [Flash] = []
    
    var screenSize: CGSize = CGSize(width: 390, height: 844)
    var isiPad: Bool = false
    
    private var isActive = false
    private var launchTask: Task<Void, Never>?
    
    private var fireworkCount = 0
    // [修改点 1] 总数设为 50
    private let maxFireworks = 60
    private var totalExplosions = 0
    
    private init() { }
    
    func updateScreenInfo(size: CGSize, isPad: Bool) {
        self.screenSize = size
        self.isiPad = isPad
    }
    
    func triggerFireworks(screenSize: CGSize? = nil) {
        if let size = screenSize { self.screenSize = size }
        
        stopFireworks(clearImmediately: true)
        showFireworks = true
        isActive = true
        fireworkCount = 0
        totalExplosions = 0
        
        launchFirework()
        fireworkCount += 1
        
        launchTask = Task {
            while !Task.isCancelled && isActive && fireworkCount < maxFireworks {
                // [修改点 2] 发射间隔设为 0.5秒
                // 50发 * 0.5秒 = 25秒持续发射时间，加上停留时间正好约 30秒
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                if Task.isCancelled || !isActive { break }
                
                launchFirework()
                fireworkCount += 1
            }
        }
        
        // 30秒后自动停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            Task { @MainActor in self?.stopFireworks() }
        }
    }
    
    func stopFireworks(clearImmediately: Bool = false) {
        isActive = false
        launchTask?.cancel()
        launchTask = nil
        
        if clearImmediately {
            showFireworks = false
            fireworks.removeAll()
            particles.removeAll()
            flashes.removeAll()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                Task { @MainActor in
                    self?.showFireworks = false
                    self?.fireworks.removeAll()
                    self?.particles.removeAll()
                    self?.flashes.removeAll()
                }
            }
        }
        objectWillChange.send()
    }
    
    func updatePhysicsFromView() {
        guard isActive || !particles.isEmpty else { return }
        
        for i in fireworks.indices {
            var fw = fireworks[i]
            if fw.state == .launching {
                fw.position.x += fw.velocity.x
                fw.position.y += fw.velocity.y
                fw.velocity.y += 0.12
                
                if fw.velocity.y >= 0 || fw.position.y <= fw.targetY {
                    fw.state = .exploding
                    fw.opacity = 0
                    createExplosionEffects(at: fw.position, color: fw.mainColor, parentSize: fw.size)
                }
            }
            fireworks[i] = fw
        }
        
        if !particles.isEmpty {
            for i in particles.indices {
                particles[i].position.x += particles[i].velocity.x
                particles[i].position.y += particles[i].velocity.y
                particles[i].velocity.y += 0.08
                particles[i].velocity.x *= 0.96
                particles[i].velocity.y *= 0.96
                particles[i].lifeTime += 0.016
                
                if particles[i].lifeTime > 1.2 {
                    particles[i].opacity -= 0.04
                }
            }
            particles.removeAll { $0.opacity <= 0 }
        }
        
        if !flashes.isEmpty {
            for i in flashes.indices {
                flashes[i].opacity -= 0.08
            }
            flashes.removeAll { $0.opacity <= 0 }
        }
        
        fireworks.removeAll { $0.state == .exploding || $0.state == .finished }
        
        objectWillChange.send()
    }
    
    // MARK: - Private Logic
    
    private func launchFirework() {
        let startX = CGFloat.random(in: screenSize.width * 0.1...screenSize.width * 0.9)
        let startPos = CGPoint(x: startX, y: screenSize.height + 20)
        
        let zone = selectExplosionZone()
        let targetY = calculateTargetY(for: zone)
        let color = selectRandomColor()
        
        let distance = abs(startPos.y - targetY)
        let gravity: CGFloat = 0.12
        let velocityY = -sqrt(2.0 * gravity * distance) * 1.05
        let velocityX = CGFloat.random(in: -1.0...1.0)
        
        // 保持约 35% 的大烟花概率 (18/50)
        let isLarge = Double.random(in: 0...1) < 0.36
        
        let baseSize: CGFloat = isiPad ? 9 : 7
        let size = isLarge ? baseSize * 2.0 : baseSize
        
        let firework = Firework(
            position: startPos,
            velocity: CGPoint(x: velocityX, y: velocityY),
            mainColor: color,
            targetY: targetY,
            zone: zone,
            size: size
        )
        fireworks.append(firework)
    }
    
    private func createExplosionEffects(at position: CGPoint, color: Color, parentSize: CGFloat) {
        totalExplosions += 1
        
        let baseSize: CGFloat = isiPad ? 9 : 7
        let isLargeExplosion = parentSize > (baseSize * 1.5)
        
        let scaleFactor: CGFloat = isLargeExplosion ? 2.0 : 1.0
        
        flashes.append(Flash(position: position, color: color))
        
        // [修改点 3] 增加粒子数量以补偿尺寸减小
        // 基础数量提升到 140 (iPhone) / 220 (iPad)
        let baseCount = isiPad ? 240 : 160
        let count = Int(CGFloat(baseCount) * (isLargeExplosion ? 1.8 : 1.0))
        
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...CGFloat.pi * 2)
            
            let baseSpeed = CGFloat.random(in: 2...8)
            let speed = baseSpeed * scaleFactor
            
            let vel = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
            
            // [修改点 4] 极致细腻的粒子尺寸：1.2 - 3.2
            let particleSize = CGFloat.random(in: 1.0...3.0)
            
            particles.append(FireworkParticle(
                position: position,
                velocity: vel,
                color: color,
                size: particleSize
            ))
        }
        
        let hapticIntensity = isLargeExplosion ? 1.0 : 0.7
        HapticManager.shared.playClick(velocity: hapticIntensity)
    }
    
    private func selectExplosionZone() -> ExplosionZone {
        let r = Int.random(in: 0...10)
        if r < 4 { return .top }
        if r < 8 { return .middle }
        return .bottom
    }
    
    private func calculateTargetY(for zone: ExplosionZone) -> CGFloat {
        switch zone {
        case .top: return screenSize.height * CGFloat.random(in: 0.15...0.30)
        case .middle: return screenSize.height * CGFloat.random(in: 0.35...0.55)
        case .bottom: return screenSize.height * CGFloat.random(in: 0.60...0.75)
        }
    }
    
    private func selectRandomColor() -> Color {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .mint
        ]
        return colors.randomElement() ?? .white
    }
}
