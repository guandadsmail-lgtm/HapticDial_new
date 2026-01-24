//
//  FireworksView.swift
//  HapticDial
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

struct FireworksView: View {
    @ObservedObject private var manager = FireworksManager.shared
    
    // 时间线用于驱动 Canvas 动画
    @State private var timeline = Date()
    
    var body: some View {
        TimelineView(.animation) { context in
            // 使用 Canvas 进行高性能渲染
            Canvas { context, size in
                // 1. 绘制闪光 (最底层)
                for flash in manager.flashes {
                    let rect = CGRect(
                        x: flash.position.x - flash.size / 2,
                        y: flash.position.y - flash.size / 2,
                        width: flash.size,
                        height: flash.size
                    )
                    var graphicsContext = context
                    graphicsContext.opacity = flash.opacity
                    
                    // [修复点] center: .center -> center: flash.position
                    graphicsContext.fill(
                        Circle().path(in: rect),
                        with: .radialGradient(
                            Gradient(colors: [.white, flash.color.opacity(0.5), .clear]),
                            center: flash.position, // 这里必须是 CGPoint
                            startRadius: 0,
                            endRadius: flash.size / 2
                        )
                    )
                }
                
                // 2. 绘制尾迹 (烟火上升阶段)
                for firework in manager.fireworks where firework.state == .launching {
                    var path = Path()
                    let trailLen: CGFloat = 30.0
                    let start = CGPoint(
                        x: firework.position.x - firework.velocity.x * trailLen,
                        y: firework.position.y - firework.velocity.y * trailLen
                    )
                    path.move(to: start)
                    path.addLine(to: firework.position)
                    
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [firework.mainColor.opacity(0), firework.mainColor]),
                            startPoint: start,
                            endPoint: firework.position
                        ),
                        lineWidth: 3
                    )
                    
                    // 烟火头
                    let headRect = CGRect(
                        x: firework.position.x - 3,
                        y: firework.position.y - 3,
                        width: 6,
                        height: 6
                    )
                    context.fill(Circle().path(in: headRect), with: .color(firework.mainColor))
                }
                
                // 3. 绘制爆炸粒子 (核心性能瓶颈，Canvas 轻松处理)
                for particle in manager.particles {
                    let rect = CGRect(
                        x: particle.position.x - particle.size / 2,
                        y: particle.position.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    var graphicsContext = context
                    graphicsContext.opacity = particle.opacity
                    // 使用混合模式让颜色叠加更亮 (类似发光)
                    graphicsContext.blendMode = .plusLighter
                    
                    // 直接填充颜色比画渐变快得多
                    graphicsContext.fill(
                        Circle().path(in: rect),
                        with: .color(particle.color)
                    )
                }
            }
            .onChange(of: context.date) {
                // 驱动 Manager 的物理计算
                // 我们不再依赖 Manager 内部的 Task.sleep，而是依赖屏幕刷新率
                manager.updatePhysicsFromView()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            let size = UIScreen.main.bounds.size
            let isPad = size.width > 500
            manager.updateScreenInfo(size: size, isPad: isPad)
        }
    }
}
