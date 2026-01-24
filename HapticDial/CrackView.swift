import SwiftUI

struct CrackView: View {
    // 引用单例，不要重新定义类
    @ObservedObject private var manager = CrackManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 透明背景用于拦截点击 (保持兼容手动点击)
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        manager.triggerCrack(at: location, screenSize: geometry.size)
                    }
                
                if manager.showCracks {
                    // 2. 裂纹层
                    ZStack {
                        // 绘制裂纹线条
                        ForEach(manager.cracks) { crack in
                            // 只有当延迟结束且开始生长时才渲染
                            if crack.startDelay <= 0 && crack.progress > 0 {
                                JaggedCrackShape(points: crack.points)
                                    // 核心动画：trim 控制绘制长度
                                    .trim(from: 0, to: crack.progress)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.9),
                                                .white.opacity(0.3)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        style: StrokeStyle(
                                            lineWidth: crack.width,
                                            lineCap: .butt,
                                            lineJoin: .miter,
                                            miterLimit: 5
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0.5, y: 0.5)
                                    .opacity(crack.opacity * manager.crackOpacity)
                                    .blendMode(.plusLighter) // 增加玻璃质感
                            }
                        }
                        
                        // 3. 撞击点 (Crater)
                        ForEach(manager.impactPoints) { impact in
                            ImpactCraterView()
                                .position(impact.position)
                                .opacity(manager.crackOpacity)
                                .transition(.scale.animation(.spring(duration: 0.1)))
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            // 关键：禁用默认动画，强制使用 trim 动画
            .animation(nil, value: manager.cracks.map { $0.progress })
        }
    }
}

// MARK: - Shapes & Components

struct JaggedCrackShape: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        
        path.move(to: first)
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        return path
    }
}

struct ImpactCraterView: View {
    var body: some View {
        ZStack {
            // 中心粉碎点
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 6, height: 6)
                .blur(radius: 0.5)
            
            // 周围的碎屑
            ForEach(0..<12) { _ in
                CraterShard()
            }
        }
    }
}

struct CraterShard: View {
    // 随机静态属性
    let angle: Double = Double.random(in: 0...360)
    let distance: CGFloat = CGFloat.random(in: 5...25)
    let size: CGFloat = CGFloat.random(in: 2...5)
    let shapeRotation: Double = Double.random(in: 0...360)
    
    var body: some View {
        PolygonShape()
            .fill(Color.white.opacity(Double.random(in: 0.6...0.95)))
            .frame(width: size, height: size/1.3)
            .rotationEffect(Angle(degrees: shapeRotation))
            .offset(x: distance * cos(angle * .pi / 180),
                    y: distance * sin(angle * .pi / 180))
    }
}

struct PolygonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // 画一个不规则三角形
        path.move(to: CGPoint(x: rect.width * 0.5, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.6))
        path.addLine(to: CGPoint(x: rect.width * 0.1, y: rect.height))
        path.closeSubpath()
        return path
    }
}
