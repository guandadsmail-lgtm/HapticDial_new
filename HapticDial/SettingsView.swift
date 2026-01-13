
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
                        Text("SPECIAL_EFFECTS_SECTION".localized)
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
                                    
                                    Text("FIREWORKS_EFFECT_LABEL".localized)
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
                                    
                                    Text("GLASS_CRACK_EFFECT_LABEL".localized)
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
                                Text("TEST_EFFECT_BUTTON".localized)
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
                    Text("SPECIAL_EFFECTS_SECTION".localized)
                } footer: {
                    Text("SPECIAL_EFFECTS_FOOTER".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // 触感反馈设置
                Section {
                    Toggle("HAPTIC_FEEDBACK_TOGGLE".localized, isOn: $viewModel.hapticEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: orangePinkColor))
                    
                    if viewModel.hapticEnabled {
                        // 触感强度
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "hand.tap")
                                    .foregroundColor(orangePinkColor.opacity(0.8))
                                    .frame(width: 24)
                                
                                Text("HAPTIC_INTENSITY_LABEL".localized)
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
                                Text("HAPTIC_INTENSITY_LABEL".localized)
                            }
                            .accentColor(orangePinkColor)
                            
                            // 触感模式选择
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "waveform.path")
                                        .foregroundColor(orangePinkColor.opacity(0.8))
                                        .frame(width: 24)
                                    
                                    Text("HAPTIC_PATTERN_LABEL".localized)
                                        .font(.system(size: 15))
                                    
                                    Spacer()
                                    
                                    Button("TEST_BUTTON".localized) {
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
                                
                                Picker("HAPTIC_PATTERN_LABEL".localized, selection: Binding(
                                    get: { hapticManager.customHapticMode },
                                    set: { hapticManager.setCustomHapticMode($0) }
                                )) {
                                    ForEach(HapticManager.CustomHapticMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue.localized).tag(mode)
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
                            
                            Text("SOUND_LABEL".localized)
                                .font(.system(size: 15))
                            
                            Spacer()
                            
                            Button("CHANGE_SOUND_BUTTON".localized) {
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
                                
                                Text(unifiedSoundManager.isSoundEnabled() ? "SOUND_ENABLED_LABEL".localized : "SOUND_DISABLED_LABEL".localized)
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
                            Text("VOLUME_LABEL".localized)
                        }
                        .accentColor(bubbleColor)
                        .disabled(!hapticManager.isSoundEnabled())
                        
                        Button("TEST_SOUND_BUTTON".localized) {
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
                    Text("FEEDBACK_SETTINGS_SECTION".localized)
                } footer: {
                    Text("FEEDBACK_SETTINGS_FOOTER".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // 智能效果设置
                Section {
                    Toggle("SMART_ADAPTIVE_EFFECTS_TOGGLE".localized, isOn: $smartEffectsManager.isAdaptiveEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: customGreen))
                    
                    if smartEffectsManager.isAdaptiveEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("TIME_BASED_EFFECTS_TOGGLE".localized, isOn: $smartEffectsManager.timeBasedEffects)
                                .toggleStyle(SwitchToggleStyle(tint: customGreen.opacity(0.8)))
                            
                            Toggle("MOTION_BASED_EFFECTS_TOGGLE".localized, isOn: $smartEffectsManager.motionBasedEffects)
                                .toggleStyle(SwitchToggleStyle(tint: customGreen.opacity(0.8)))
                            
                            Text("SMART_EFFECTS_DESCRIPTION".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("SMART_EFFECTS_SECTION".localized)
                } footer: {
                    Text("SMART_EFFECTS_FOOTER".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // 统计信息
                Section {
                    HStack {
                        Text("MAIN_DIAL_LABEL".localized)
                        Spacer()
                        Text("\(Int(viewModel.totalRotation / 360)) rotations")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("BUBBLE_DIAL_LABEL".localized)
                        Spacer()
                        Text("\(bubbleViewModel.tapCount) taps")
                            .foregroundColor(bubbleColor)
                    }
                    
                    HStack {
                        Text("GEAR_DIAL_LABEL".localized)
                        Spacer()
                        Text("\(gearViewModel.spinCount) spins")
                            .foregroundColor(gearColor)
                    }
                    
                    Button("RESET_STATISTICS_BUTTON".localized) {
                        viewModel.resetStats()
                        bubbleViewModel.resetCount()
                        gearViewModel.resetCount()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("STATISTICS_SECTION".localized)
                } footer: {
                    Text("STATISTICS_FOOTER".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("SETTINGS_TITLE".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE_BUTTON".localized) {
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showSoundPicker) {
                UnifiedSoundPickerView()
            }
            .alert("DELETE_SOUND_PACK_ALERT_TITLE".localized, isPresented: $showingDeleteAlert) {
                Button("CANCEL_BUTTON".localized, role: .cancel) { }
                Button("DELETE_BUTTON".localized, role: .destructive) {
                    // 处理删除逻辑
                }
            } message: {
                Text("DELETE_SOUND_PACK_ALERT_MESSAGE".localized)
            }
        }
    }
    
    private func showAboutInfo() {
        // 创建简单的关于弹窗
        let alert = UIAlertController(
            title: "ABOUT_ALERT_TITLE".localized,
            message: "ABOUT_ALERT_MESSAGE".localized,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK_BUTTON".localized, style: .default))
        
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
