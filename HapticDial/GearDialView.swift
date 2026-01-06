// Views/GearDialView.swift
import SwiftUI
import Combine

struct GearDialView: View {
    @ObservedObject var viewModel: GearDialViewModel
    
    let size: CGFloat = 120
    
    // 颜色定义 - 修改外圈环为白色，数字为红色
    private let metalBaseColor = Color(red: 0.7, green: 0.7, blue: 0.75)
    private let metalHighlightColor = Color(red: 0.9, green: 0.9, blue: 0.95)
    private let metalShadowColor = Color(red: 0.4, green: 0.4, blue: 0.45)
    private let gearTeethColor = Color(red: 1.0, green: 0.4, blue: 0.2)
    private let whiteRingColor = Color.white.opacity(0.8)  // 修改：灰色环改为白色

    private let tickColor = Color.white  // 主刻度线为白色
    private let tickColorDim = Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.7)  // 浅灰色
    private let whiteTickColorDim = Color.white.opacity(0.7)
    private let numberColor = Color.red  // 新增：数字颜色为红色
    
    init(viewModel: GearDialViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // 1. 辐射背景 - 中心暗，周边亮
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12, opacity: 0.7),  // 中心暗
                          Color(red: 0.15, green: 0.15, blue: 0.20, opacity: 0.7),  // 中间
                          Color(red: 0.22, green: 0.22, blue: 0.28, opacity: 0.7)   // 边缘亮
                ]),
                center: .center,
                startRadius: 0,
                endRadius: size/2
            )
            .frame(width: size, height: size)
            .clipShape(Circle())
            
            // 2. 齿轮外和最外圈边界之间的白色填充环 - 修改为白色
            Circle()
                .fill(whiteRingColor.opacity(0.3))  // 修改为白色
                .frame(width: size - 16, height: size - 16)
            
            // 3. 灰色环带 - 用于放置数字
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: size - 40, height: size - 40)
            
            // 4. 外圈齿轮
            GearTeethView(size: size, gearTeethColor: gearTeethColor)
            
            // 5. 内圈刻度 - 每30度一个主刻度，每15度一个次刻度
            ForEach(0..<12, id: \.self) { index in
                makeMainTick(index: index)
            }
            
            // 6. 次要刻度线（每15度一个，颜色较暗）
            ForEach(0..<24, id: \.self) { index in
                makeMinorTick(index: index)
            }
            
            // 7. 数字标签 - 移动到最外圈，修改为红色
            ForEach([0, 3, 6, 9], id: \.self) { hour in
                makeHourText(hour: hour)
            }
            
            // 8. 旋转次数显示（无背景）
            Text("\(viewModel.spinCount)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(numberColor)  // 修改为红色
                .shadow(color: numberColor.opacity(0.5), radius: 8, x: 0, y: 0)
                .zIndex(1)
            
            // 重置按钮（长按）
            .onLongPressGesture(minimumDuration: 1.0) {
                viewModel.resetCount()
                HapticManager.shared.playClick()
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(viewModel.rotationAngle))
        .onTapGesture {
            viewModel.spinGear()
        }
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            metalHighlightColor.opacity(0.2),
                            metalShadowColor.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // 主刻度线（每30度一个）- 白色
    @ViewBuilder
    private func makeMainTick(index: Int) -> some View {
        let angle = Double(index) * 30
        let radian = angle * Double.pi / 180
        let center = CGPoint(x: size / 2, y: size / 2)
        
        // 计算内圈和外圈的位置
        let innerRadius = size / 2 - 25
        let outerRadius = size / 2 - 12
        
        let innerX = center.x + CGFloat(innerRadius * cos(radian))
        let innerY = center.y + CGFloat(innerRadius * sin(radian))
        let outerX = center.x + CGFloat(outerRadius * cos(radian))
        let outerY = center.y + CGFloat(outerRadius * sin(radian))
        
        // 主刻度线 - 深灰色
        Path { path in
            path.move(to: CGPoint(x: innerX, y: innerY))
            path.addLine(to: CGPoint(x: outerX, y: outerY))
        }
        .stroke(tickColor, lineWidth: 2)  // 修改为深灰色
        .rotationEffect(.degrees(0))
    }
    
    // 次要刻度线（每15度一个）- 深灰色（稍暗）
    @ViewBuilder
       private func makeMinorTick(index: Int) -> some View {
           let angle = Double(index) * 15
           // 跳过主刻度位置
           if angle.truncatingRemainder(dividingBy: 30) != 0 {
               let radian = angle * Double.pi / 180
               let center = CGPoint(x: size / 2, y: size / 2)
               
               // 计算内圈和外圈的位置
               let innerRadius = size / 2 - 20
               let outerRadius = size / 2 - 14
               
               let innerX = center.x + CGFloat(innerRadius * cos(radian))
               let innerY = center.y + CGFloat(innerRadius * sin(radian))
               let outerX = center.x + CGFloat(outerRadius * cos(radian))
               let outerY = center.y + CGFloat(outerRadius * sin(radian))
               
               // 次要刻度线 - 深灰色稍暗
               Path { path in
                   path.move(to: CGPoint(x: innerX, y: innerY))
                   path.addLine(to: CGPoint(x: outerX, y: outerY))
               }
               .stroke(tickColorDim, lineWidth: 1)  // 修改为深灰色稍暗
               .rotationEffect(.degrees(0))
           }
       }
    
    // 小时标签（显示为时钟数字：3, 6, 9, 12）- 移动到最外圈，修改为红色
    private func makeHourText(hour: Int) -> some View {
        let angle: Double
        let label: String
        
        // 将小时转换为角度（时钟布局，12点在顶部）
        switch hour {
        case 0: // 12点位置
            angle = -90.0
            label = "12"
        case 3: // 3点位置
            angle = 0.0
            label = "3"
        case 6: // 6点位置
            angle = 90.0
            label = "6"
        case 9: // 9点位置
            angle = 180.0
            label = "9"
        default:
            return AnyView(EmptyView())
        }
        
        let radian = angle * Double.pi / 180
        let center = CGPoint(x: size / 2, y: size / 2)
        let labelRadius = size / 2 - 3  // 移动到最外圈，紧贴边缘
        
        let labelX = center.x + CGFloat(labelRadius * cos(radian))
        let labelY = center.y + CGFloat(labelRadius * sin(radian))
        
        return AnyView(
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(numberColor)  // 修改为红色
                .position(x: labelX, y: labelY)
        )
    }
}

// MARK: - 子组件

struct GearTeethView: View {
    let size: CGFloat
    let gearTeethColor: Color
    
    var body: some View {
        ForEach(0..<36, id: \.self) { index in
            let center = CGPoint(x: size / 2, y: size / 2)
            let outerRadius = size / 2 - 8
            let toothDepth: CGFloat = 6
            let baseAngle = Double(index) * (360 / 36.0)
            
            SingleGearTooth(center: center,
                           outerRadius: outerRadius,
                           toothDepth: toothDepth,
                           baseAngle: baseAngle,
                           gearTeethColor: gearTeethColor)
        }
    }
}

struct SingleGearTooth: View {
    let center: CGPoint
    let outerRadius: CGFloat
    let toothDepth: CGFloat
    let baseAngle: Double
    let gearTeethColor: Color
    
    var body: some View {
        let topAngle = baseAngle
        let topRadian = topAngle * Double.pi / 180
        let valleyAngle = baseAngle + (360 / 36.0) / 2
        let valleyRadian = valleyAngle * Double.pi / 180
        let nextValleyAngle = valleyAngle + (360 / 36.0)
        let nextValleyRadian = nextValleyAngle * Double.pi / 180
        
        // 计算三个顶点的坐标
        let valleyPoint = CGPoint(
            x: center.x + CGFloat((outerRadius - toothDepth) * cos(valleyRadian)),
            y: center.y + CGFloat((outerRadius - toothDepth) * sin(valleyRadian))
        )
        
        let topPoint = CGPoint(
            x: center.x + CGFloat(outerRadius * cos(topRadian)),
            y: center.y + CGFloat(outerRadius * sin(topRadian))
        )
        
        let nextValleyPoint = CGPoint(
            x: center.x + CGFloat((outerRadius - toothDepth) * cos(nextValleyRadian)),
            y: center.y + CGFloat((outerRadius - toothDepth) * sin(nextValleyRadian))
        )
        
        // 齿轮齿的填充路径
        Path { path in
            path.move(to: valleyPoint)
            path.addLine(to: topPoint)
            path.addLine(to: nextValleyPoint)
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                gradient: Gradient(colors: [
                    gearTeethColor.opacity(0.9),
                    gearTeethColor.opacity(0.7)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        
        // 齿轮齿的轮廓路径
        Path { path in
            path.move(to: valleyPoint)
            path.addLine(to: topPoint)
            let nextValleyRadian = (valleyAngle + (360 / 36.0)) * Double.pi / 180
            let finalValleyPoint = CGPoint(
                x: center.x + CGFloat((outerRadius - toothDepth) * cos(nextValleyRadian)),
                y: center.y + CGFloat((outerRadius - toothDepth) * sin(nextValleyRadian))
            )
            path.addLine(to: finalValleyPoint)
        }
        .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
    }
}
