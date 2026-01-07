// HapticDial/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DialViewModel()
    @StateObject private var bubbleViewModel = BubbleDialViewModel()
    @StateObject private var gearViewModel = GearDialViewModel()
    @StateObject private var fireworksManager = FireworksManager.shared
    @StateObject private var crackManager = CrackManager.shared
    @StateObject private var effectManager = EffectManager.shared
    @State private var showSettings = false
    @State private var showSoundOptions = false
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let screenHeight = geometry.size.height
            let isSmallScreen = screenHeight < 800
            
            // 根据屏幕方向和大小计算垂直间距
            let verticalPadding: CGFloat = isSmallScreen ? 20 : (isLandscape ? 20 : 40)
            
            // 计算转盘的缩放比例
            let scaleFactor: CGFloat = isSmallScreen ? 0.85 : 1.0
            
            ZStack {
                // 深度渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.03, green: 0.03, blue: 0.08),
                        Color(red: 0.08, green: 0.05, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.12)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // 效果模式提示
                if effectManager.showSettingsInfo {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: effectManager.currentEffectIcon)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                            Text("Effect Mode: \(effectManager.currentEffectName)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.bottom, 100)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: effectManager.showSettingsInfo)
                    }
                    .zIndex(999)
                }
                
                if isLandscape {
                    // 横屏布局：两侧小转盘，中间主转盘，主转盘下方是缩小的音效选择器
                    HStack(spacing: isSmallScreen ? 10 : 20) {
                        // 左侧：气泡转盘
                        VStack {
                            BubbleDialViewWrapper(viewModel: bubbleViewModel)
                                .scaleEffect(scaleFactor)
                                .frame(width: 120 * scaleFactor, height: 120 * scaleFactor)
                                .padding(.bottom, isSmallScreen ? 4 : 8)
                            
                            Text("BUBBLE")
                                .font(.system(size: isSmallScreen ? 10 : 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1)
                        }
                        .frame(width: isSmallScreen ? 100 : 120)
                        
                        Spacer()
                        
                        // 中间：主转盘 + 缩小的音效选择器
                        VStack(spacing: 0) {
                            // 标题
                            Text("HAPTIC DIAL")
                                .font(.system(size: isSmallScreen ? 12 : 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(2)
                                .padding(.bottom, isSmallScreen ? 8 : 15)
                            
                            // 主转盘
                            DialViewRedesigned(viewModel: viewModel)
                                .scaleEffect(scaleFactor)
                                .frame(width: 320 * scaleFactor, height: 320 * scaleFactor)
                                .padding(.vertical, isSmallScreen ? 5 : 10)
                            
                            Spacer(minLength: isSmallScreen ? 5 : 10)
                            
                            // 音效选择器（横屏时缩小并水平居中）
                            HorizontalSoundPicker(
                                onAddSound: {
                                    showSoundOptions = true
                                },
                                scaleFactor: 0.7,
                                isLandscape: true
                            )
                            .frame(height: 60)
                            .padding(.horizontal, 20)
                            .frame(width: 320 * scaleFactor)
                            .padding(.bottom, isSmallScreen ? 10 : 15)
                        }
                        .frame(maxHeight: .infinity)
                        
                        Spacer()
                        
                        // 右侧：齿轮转盘
                        VStack {
                            GearDialViewWrapper(viewModel: gearViewModel)
                                .scaleEffect(scaleFactor)
                                .frame(width: 120 * scaleFactor, height: 120 * scaleFactor)
                                .padding(.bottom, isSmallScreen ? 4 : 8)
                            
                            Text("GEAR")
                                .font(.system(size: isSmallScreen ? 10 : 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1)
                        }
                        .frame(width: isSmallScreen ? 100 : 120)
                    }
                    .padding(.horizontal, isSmallScreen ? 15 : 30)
                    .frame(maxHeight: .infinity)
                } else {
                    // 竖屏布局：上-主转盘，中-两个小转盘，下-音效选择器
                    VStack(spacing: 0) {
                        // 标题
                        Text("HAPTIC DIAL")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(2)
                            .padding(.top, verticalPadding)
                        
                        // 当前效果模式显示
                        HStack(spacing: 8) {
                            Image(systemName: effectManager.currentEffectIcon)
                                .font(.system(size: 12))
                                .foregroundColor(effectManager.currentEffectMode == "fireworks" ?
                                               Color(red: 1.0, green: 0.6, blue: 0.2) :
                                               Color(red: 0.2, green: 0.8, blue: 1.0))
                            
                            Text("Effect: \(effectManager.currentEffectName)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 8)
                        
                        Spacer(minLength: isSmallScreen ? 15 : 20)
                        
                        // 角度显示标题
                        Text("ROTATION ANGLE")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.bottom, isSmallScreen ? 15 : 20)
                        
                        // 上：主转盘
                        DialViewRedesigned(viewModel: viewModel)
                            .scaleEffect(isSmallScreen ? 0.9 : 1.0)
                            .padding(.vertical, isSmallScreen ? 0 : 10)
                        
                        Spacer(minLength: isSmallScreen ? 20 : 30)
                        
                        // 中：两个小转盘（水平排列）
                        VStack(spacing: 12) {
                            Text("MINI DIALS")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .tracking(1)
                            
                            HStack(spacing: isSmallScreen ? 40 : 60) {
                                VStack(spacing: 8) {
                                    BubbleDialViewWrapper(viewModel: bubbleViewModel)
                                        .scaleEffect(0.7)
                                        .frame(width: 90, height: 90)
                                    
                                    Text("BUBBLE")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                        .tracking(1)
                                }
                                
                                VStack(spacing: 8) {
                                    GearDialViewWrapper(viewModel: gearViewModel)
                                        .scaleEffect(0.7)
                                        .frame(width: 90, height: 90)
                                    
                                    Text("GEAR")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                        .tracking(1)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: isSmallScreen ? 20 : 30)
                        
                        // 下：音效选择器
                        VStack(spacing: 8) {
                            HorizontalSoundPicker(onAddSound: {
                                showSoundOptions = true
                            })
                            .frame(height: 85)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, isSmallScreen ? 25 : 35)
                        
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                }
                
                // 右上角按钮区域
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            // 设置按钮
                            Button(action: { showSettings.toggle() }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        .ultraThinMaterial,
                                        in: Circle()
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.top, isSmallScreen ? 8 : 12)
                        .padding(.trailing, isSmallScreen ? 12 : 16)
                    }
                    Spacer()
                }
                
                // 烟火效果
                if fireworksManager.showFireworks {
                    FireworksView()
                        .edgesIgnoringSafeArea(.all)
                        .zIndex(1000)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                
                // 玻璃破裂效果
                if crackManager.showCracks {
                    CrackView()
                        .edgesIgnoringSafeArea(.all)
                        .zIndex(1000)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                viewModel: viewModel,
                bubbleViewModel: bubbleViewModel,
                gearViewModel: gearViewModel
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSoundOptions) {
            NavigationView {
                SoundSelectionView()
                    .navigationBarTitle("Select Sound", displayMode: .inline)
                    .navigationBarItems(trailing: Button("Done") {
                        showSoundOptions = false
                    })
            }
        }
    }
}

// 包装器视图，用于传递ViewModel
struct BubbleDialViewWrapper: View {
    @ObservedObject var viewModel: BubbleDialViewModel
    
    var body: some View {
        ZStack {
            BubbleDialView(viewModel: viewModel)
        }
    }
}

struct GearDialViewWrapper: View {
    @ObservedObject var viewModel: GearDialViewModel
    
    var body: some View {
        ZStack {
            GearDialView(viewModel: viewModel)
        }
    }
}
