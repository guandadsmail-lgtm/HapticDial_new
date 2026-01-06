// Views/CrackView.swift（添加CrackGradient定义）
import SwiftUI
import CoreHaptics

struct CrackView: View {
    @ObservedObject private var crackManager = CrackManager.shared
    @State private var flashOpacity: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            
            ZStack {
                // 半透明黑色背景
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                
                // 初始闪光效果
                if flashOpacity > 0 {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    .white.opacity(0.8),
                                    .white.opacity(0.3),
                                    .clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .position(
                            x: screenSize.width / 2,
                            y: screenSize.height / 2
                        )
                        .blur(radius: 10)
                        .opacity(flashOpacity)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.5)) {
                                flashOpacity = 0
                            }
                        }
                }
                
                // 绘制所有裂纹 - 按深度分层绘制
                ForEach(crackManager.cracks.filter { $0.depth == 1 }) { crack in
                    CrackLine(crack: crack, opacity: crackManager.crackOpacity)
                }
                
                ForEach(crackManager.cracks.filter { $0.depth == 2 }) { crack in
                    CrackLine(crack: crack, opacity: crackManager.crackOpacity * 0.8)
                }
                
                ForEach(crackManager.cracks.filter { $0.depth >= 3 }) { crack in
                    CrackLine(crack: crack, opacity: crackManager.crackOpacity * 0.6)
                }
                
                // 裂纹端点的高光效果
                ForEach(crackManager.cracks.filter { $0.animationProgress > 0.9 }) { crack in
                    CrackTipView(
                        position: interpolatePoint(
                            start: crack.startPoint,
                            end: crack.endPoint,
                            progress: crack.animationProgress
                        ),
                        opacity: crackManager.crackOpacity * (1 - crack.animationProgress) * 0.5
                    )
                }
            }
            .frame(width: screenSize.width, height: screenSize.height)
            .allowsHitTesting(false)
            .onAppear {
                print("💥 CrackView 出现，屏幕尺寸: \(screenSize)")
                flashOpacity = 0.6
            }
        }
        .ignoresSafeArea()
    }
    
    private func interpolatePoint(start: CGPoint, end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }
}

// 单个裂纹线 - 更优雅的绘制
struct CrackLine: View {
    let crack: Crack
    let opacity: Double
    
    var body: some View {
        Path { path in
            // 计算当前动画位置
            let currentEnd = CGPoint(
                x: crack.startPoint.x + (crack.endPoint.x - crack.startPoint.x) * CGFloat(crack.animationProgress),
                y: crack.startPoint.y + (crack.endPoint.y - crack.startPoint.y) * CGFloat(crack.animationProgress)
            )
            
            path.move(to: crack.startPoint)
            
            // 创建自然弯曲的裂纹路径
            let controlPointCount = 3
            let segmentProgress = crack.animationProgress / CGFloat(controlPointCount + 1)
            
            for i in 1...controlPointCount {
                let segment = CGFloat(i) * segmentProgress
                if segment <= crack.animationProgress {
                    let point = CGPoint(
                        x: crack.startPoint.x + (currentEnd.x - crack.startPoint.x) * segment,
                        y: crack.startPoint.y + (currentEnd.y - crack.startPoint.y) * segment
                    )
                    
                    // 添加轻微的自然弯曲
                    let jitterAmount = crack.depth == 1 ? 8 : 4
                    let jitterX = CGFloat.random(in: -CGFloat(jitterAmount)...CGFloat(jitterAmount))
                    let jitterY = CGFloat.random(in: -CGFloat(jitterAmount)...CGFloat(jitterAmount))
                    
                    path.addLine(to: CGPoint(x: point.x + jitterX, y: point.y + jitterY))
                }
            }
            
            path.addLine(to: currentEnd)
        }
        .stroke(
            CrackGradient(depth: crack.depth),
            style: StrokeStyle(
                lineWidth: crack.thickness,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 0
            )
        )
        .shadow(color: Color.white.opacity(0.4), radius: crack.depth == 1 ? 2 : 1)
        .opacity(opacity)
    }
}

// 裂纹渐变颜色定义 - 新增部分
struct CrackGradient: ShapeStyle {
    let depth: Int
    
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        switch depth {
        case 1: // 主要裂纹 - 白色到浅蓝色的渐变
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.9),  // 白色
                    Color(red: 0.8, green: 0.95, blue: 1.0).opacity(0.8), // 浅蓝
                    Color(red: 0.6, green: 0.9, blue: 1.0).opacity(0.7)  // 天蓝
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case 2: // 第一级分支 - 浅蓝色调
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.9, green: 0.95, blue: 1.0).opacity(0.8),
                    Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.7),
                    Color(red: 0.5, green: 0.8, blue: 1.0).opacity(0.6)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        default: // 细节裂纹 - 淡蓝色
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0).opacity(0.7),
                    Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.5),
                    Color(red: 0.75, green: 0.88, blue: 1.0).opacity(0.3)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// 裂纹端点高光
struct CrackTipView: View {
    let position: CGPoint
    let opacity: Double
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0.9),
                        .white.opacity(0.6),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 4
                )
            )
            .frame(width: 8, height: 8)
            .position(position)
            .opacity(opacity)
            .blur(radius: 1)
    }
}
