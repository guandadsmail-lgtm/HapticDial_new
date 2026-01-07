// Views/SettingsView.swift
import SwiftUI
import Combine
import AVFoundation

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: DialViewModel
    @ObservedObject var bubbleViewModel: BubbleDialViewModel
    @ObservedObject var gearViewModel: GearDialViewModel
    @StateObject private var hapticManager = HapticManager.shared
    @StateObject private var effectManager = EffectManager.shared
    @StateObject private var unifiedSoundManager = UnifiedSoundManager.shared
    @StateObject private var smartEffectsManager = SmartEffectsManager.shared
    
    // 颜色定义
    private let orangePinkColor = Color(red: 1.0, green: 0.4, blue: 0.3)
    private let bubbleColor = Color(red: 0.2, green: 0.8, blue: 1.0)
    private let gearColor = Color(red: 1.0, green: 0.4, blue: 0.2)
    private let fireworksColor = Color(red: 1.0, green: 0.6, blue: 0.2)
    private let crackColor = Color(red: 0.2, green: 0.8, blue: 1.0)
    private let customGreen = Color(red: 0.3, green: 0.8, blue: 0.5)
    private let accentBlue = Color(red: 0.3, green: 0.7, blue: 1.0)
    
    @State private var showHapticTestSheet = false
    @State private var showSoundTestSheet = false
    @State private var showingAdvancedSettings = false
    @State private var showSoundPicker = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // 特殊效果设置
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SPECIAL EFFECT")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)
                            .padding(.bottom, 4)
                        
                        // 效果模式选择器
                        HStack(spacing: 12) {
                            // 烟火效果选项
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    effectManager.setEffectMode("fireworks")
                                }
                                hapticManager.playClick()
                            }) {
                                VStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(effectManager.currentEffectMode == "fireworks" ?
                                                  fireworksColor.opacity(0.15) :
                                                  Color.white.opacity(0.05))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 24))
                                            .foregroundColor(effectManager.currentEffectMode == "fireworks" ?
                                                           fireworksColor :
                                                           .white.opacity(0.5))
                                    }
                                    
                                    Text("Fireworks")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(effectManager.currentEffectMode == "fireworks" ?
                                                       fireworksColor :
                                                       .white.opacity(0.6))
                                    
                                    if effectManager.currentEffectMode == "fireworks" {
                                        Circle()
                                            .fill(fireworksColor)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 2)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            // 玻璃破裂效果选项
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    effectManager.setEffectMode("crack")
                                }
                                hapticManager.playClick()
                            }) {
                                VStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(effectManager.currentEffectMode == "crack" ?
                                                  crackColor.opacity(0.15) :
                                                  Color.white.opacity(0.05))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "burst")
                                            .font(.system(size: 24))
                                            .foregroundColor(effectManager.currentEffectMode == "crack" ?
                                                           crackColor :
                                                           .white.opacity(0.5))
                                    }
                                    
                                    Text("Glass Crack")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(effectManager.currentEffectMode == "crack" ?
                                                       crackColor :
                                                       .white.opacity(0.6))
                                    
                                    if effectManager.currentEffectMode == "crack" {
                                        Circle()
                                            .fill(crackColor)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 2)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                        
                        // 当前模式描述
                        Text(effectManager.currentEffectDescription)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 8)
                        
                        // 测试按钮
                        Button(action: {
                            print("🎯 测试效果，当前模式: \(effectManager.currentEffectMode)")
                            
                            // 获取屏幕尺寸
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                let screenSize = window.frame.size
                                effectManager.triggerEffect(screenSize: screenSize)
                            }
                            
                            hapticManager.playClick()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
                                Text("Test Effect")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(effectManager.currentEffectMode == "fireworks" ?
                                           fireworksColor :
                                           crackColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill((effectManager.currentEffectMode == "fireworks" ?
                                           fireworksColor :
                                           crackColor).opacity(0.1))
                            )
                        }
                        .padding(.top, 12)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Special Effects")
                } footer: {
                    Text("Choose what happens when you reach 100 taps or 100 rotations")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // 触感反馈设置
                Section {
                    Toggle("Haptic Feedback", isOn: $viewModel.hapticEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: orangePinkColor))
                    
                    if viewModel.hapticEnabled {
                        // 触感强度
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "hand.tap")
                                    .foregroundColor(orangePinkColor.opacity(0.8))
                                    .frame(width: 24)
                                
                                Text("Haptic Intensity")
                                    .font(.system(size: 15))
                                
                                Spacer()
                                
                                Text("\(Int(hapticManager.hapticIntensity * 100))%")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: Binding(
                                get: { hapticManager.hapticIntensity },
                                set: { hapticManager.setHapticIntensity($0) }
                            ), in: 0.1...1.0, step: 0.1) {
                                Text("Haptic Intensity")
                            }
                            .accentColor(orangePinkColor)
                            
                            // 触感模式选择
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "waveform.path")
                                        .foregroundColor(orangePinkColor.opacity(0.8))
                                        .frame(width: 24)
                                    
                                    Text("Haptic Pattern")
                                        .font(.system(size: 15))
                                    
                                    Spacer()
                                    
                                    Button("Test") {
                                        hapticManager.testHapticMode(hapticManager.customHapticMode)
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(orangePinkColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(orangePinkColor.opacity(0.1))
                                    )
                                }
                                
                                Picker("Haptic Pattern", selection: Binding(
                                    get: { hapticManager.customHapticMode },
                                    set: { hapticManager.setCustomHapticMode($0) }
                                )) {
                                    ForEach(HapticManager.CustomHapticMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(.vertical, 4)
                                
                                Text(hapticManager.customHapticMode.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // 声音设置（统一音效选择器）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "speaker.wave.2")
                                .foregroundColor(bubbleColor.opacity(0.8))
                                .frame(width: 24)
                            
                            Text("Sound")
                                .font(.system(size: 15))
                            
                            Spacer()
                            
                            Button("Change Sound") {
                                showSoundPicker = true
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(bubbleColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(bubbleColor.opacity(0.1))
                            )
                        }
                        
                        // 当前音效显示
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(unifiedSoundManager.getCurrentSoundName())
                                    .font(.system(size: 14, weight: .medium))
                                
                                Text(unifiedSoundManager.isSoundEnabled() ? "Sound enabled" : "Sound disabled")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(Int(hapticManager.volume * 100))%")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        // 音量控制
                        Slider(value: Binding(
                            get: { hapticManager.volume },
                            set: { hapticManager.setVolume($0) }
                        ), in: 0...1, step: 0.1) {
                            Text("Volume")
                        }
                        .accentColor(bubbleColor)
                        .disabled(!hapticManager.isSoundEnabled())
                        
                        Button("Test Sound") {
                            hapticManager.playClick()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(bubbleColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(bubbleColor.opacity(0.1))
                        )
                        .disabled(!hapticManager.isSoundEnabled())
                        
                        // 显示音效包信息
                        if let selectedSound = unifiedSoundManager.selectedSound,
                           selectedSound.type == .custom {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("From: \(selectedSound.category)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Text(selectedSound.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .lineLimit(2)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Feedback Settings")
                } footer: {
                    Text("Customize haptic patterns and sounds for a personalized experience")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // 智能效果设置
                Section {
                    Toggle("Smart Adaptive Effects", isOn: $smartEffectsManager.isAdaptiveEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: customGreen))
                    
                    if smartEffectsManager.isAdaptiveEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Time-based Effects", isOn: $smartEffectsManager.timeBasedEffects)
                                .toggleStyle(SwitchToggleStyle(tint: customGreen.opacity(0.8)))
                            
                            Toggle("Motion-based Effects", isOn: $smartEffectsManager.motionBasedEffects)
                                .toggleStyle(SwitchToggleStyle(tint: customGreen.opacity(0.8)))
                            
                            Text("Effects adjust based on time of day and device motion")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Smart Effects")
                } footer: {
                    Text("Adaptive effects change based on your usage patterns and environment")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // 统计信息
                Section {
                    HStack {
                        Text("Main Dial")
                        Spacer()
                        Text("\(Int(viewModel.totalRotation / 360)) rotations")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Bubble Dial")
                        Spacer()
                        Text("\(bubbleViewModel.tapCount) taps")
                            .foregroundColor(bubbleColor)
                    }
                    
                    HStack {
                        Text("Gear Dial")
                        Spacer()
                        Text("\(gearViewModel.spinCount) spins")
                            .foregroundColor(gearColor)
                    }
                    
                    Button("Reset All Statistics") {
                        viewModel.resetStats()
                        bubbleViewModel.resetCount()
                        gearViewModel.resetCount()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Statistics")
                } footer: {
                    Text("Tap counts and rotation statistics")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // 应用信息
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1001")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("HapticDial Team")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // 显示关于页面或开发者信息
                        showAboutInfo()
                    }) {
                        HStack {
                            Text("About & Credits")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showSoundPicker) {
                UnifiedSoundPickerView()
            }
            .alert("Delete Sound Pack?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    // 处理删除逻辑
                }
            } message: {
                Text("Are you sure you want to delete this sound pack? This action cannot be undone.")
            }
        }
    }
    
    private func showAboutInfo() {
        // 创建简单的关于弹窗
        let alert = UIAlertController(
            title: "HapticDial v1.0.0",
            message: "A tactile feedback dial app with customizable haptics and sounds.\n\nCreated with ❤️ by HapticDial Team",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // 获取当前视图控制器
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

// 预览
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            viewModel: DialViewModel(),
            bubbleViewModel: BubbleDialViewModel(),
            gearViewModel: GearDialViewModel()
        )
        .preferredColorScheme(.dark)
    }
}
