// Views/DialView.swift
import SwiftUI
import Combine

struct DialView: View {
    @ObservedObject var viewModel: DialViewModel
    @State private var isDragging = false
    
    let dialSize: CGFloat = 300
    
    // 外部数字：0-330（每30度一个）
    private let outerNumbers: [Int] = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]
    
    // 内部数字：1-12（时钟数字）
    private let innerNumbers: [Int] = [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    
    // 橙粉色
    private let orangePinkColor = Color(red: 1.0, green: 0.4, blue: 0.3)
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // 外圈玻璃效果 - 调整为浅灰色圆环
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 35  // 更宽的圆环
                    )
                    .frame(width: dialSize, height: dialSize)
                    .blur(radius: 0.5)
                
                // 外圈数字：0-330（每30度）- 移到灰色圆环外面
                ForEach(0..<12, id: \.self) { index in
                    let angle = Double(index * 30)
                    let radian = angle * Double.pi / 180
                    let radius = dialSize / 2 + 35  // 移到圆环外面
                    
                    Text("\(outerNumbers[index])")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(orangePinkColor)  // 橙粉色
                        .position(
                            x: center.x + CGFloat(radius * sin(radian)),
                            y: center.y - CGFloat(radius * cos(radian))
                        )
                }
                
                // 内圈数字：1-12（时钟数字）
                ForEach(0..<12, id: \.self) { index in
                    let angle = Double(index * 30)
                    let radian = angle * Double.pi / 180
                    let radius = dialSize / 2 - 60
                    
                    Text("\(innerNumbers[index])")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .position(
                            x: center.x + CGFloat(radius * sin(radian)),
                            y: center.y - CGFloat(radius * cos(radian))
                        )
                }
                
                // 主刻度线（每30度一个，对应时钟刻度）
                ForEach(0..<12, id: \.self) { index in
                    let angle = Double(index * 30)
                    let radian = angle * Double.pi / 180
                    let outerRadius = dialSize / 2 - 10  // 调整到圆环内侧
                    let innerRadius = dialSize / 2 - 40
                    
                    Path { path in
                        path.move(to: CGPoint(
                            x: center.x + CGFloat(outerRadius * sin(radian)),
                            y: center.y - CGFloat(outerRadius * cos(radian))
                        ))
                        path.addLine(to: CGPoint(
                            x: center.x + CGFloat(innerRadius * sin(radian)),
                            y: center.y - CGFloat(innerRadius * cos(radian))
                        ))
                    }
                    .stroke(Color.white, lineWidth: 2)
                }
                
                // 次刻度线（每6度一个）
                ForEach(0..<60, id: \.self) { index in
                    let angle = Double(index * 6)
                    let radian = angle * Double.pi / 180
                    let outerRadius = dialSize / 2 - 10
                    let innerRadius = dialSize / 2 - 25
                    
                    Path { path in
                        path.move(to: CGPoint(
                            x: center.x + CGFloat(outerRadius * sin(radian)),
                            y: center.y - CGFloat(outerRadius * cos(radian))
                        ))
                        path.addLine(to: CGPoint(
                            x: center.x + CGFloat(innerRadius * sin(radian)),
                            y: center.y - CGFloat(innerRadius * cos(radian))
                        ))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                }
                
                // 中心圆
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)
                    .background(
                        .ultraThinMaterial,
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                // 当前角度显示在中心
                VStack(spacing: 2) {
                    Text("\(Int(viewModel.currentAngle.rounded()))°")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("ANGLE")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                }
                
                // 指示器（光标）
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue,
                                Color.purple
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 40)
                    .offset(y: -dialSize / 2 + 25)
                    .rotationEffect(.degrees(viewModel.currentAngle))
                    .shadow(color: .blue.opacity(0.5), radius: 6, x: 0, y: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            viewModel.handleDragStart(location: value.location, center: center)
                            isDragging = true
                        }
                        viewModel.handleDragChange(location: value.location, center: center)
                    }
                    .onEnded { _ in
                        viewModel.handleDragEnd()
                        isDragging = false
                    }
            )
        }
        .frame(width: dialSize, height: dialSize)
    }
}
