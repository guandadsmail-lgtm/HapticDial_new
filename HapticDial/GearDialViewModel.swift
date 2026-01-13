
import SwiftUI
import Combine
import AVFoundation
import AudioToolbox

class GearDialViewModel: ObservableObject {
    @Published var spinCount = 0
    @Published var rotationAngle = 0.0
    
    // 用于追踪已经触发过的倍数，避免重复触发
    private var triggered50Multiples = Set<Int>()    // 50的倍数但不是100的倍数
    private var triggered100Multiples = Set<Int>()   // 100的倍数
    
    // 从UserDefaults加载设置
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "gear_dial_enabled")
        }
    }
    
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "gear_sound_enabled")
        }
    }
    
    @Published var hapticEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticEnabled, forKey: "gear_haptic_enabled")
        }
    }
    
    @Published var gearOpacity: Double = 1.0
    
    // 添加动画状态
    @Published var isAnimating = false
    
    init() {
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.object(forKey: "gear_dial_enabled") as? Bool ?? true
        self.soundEnabled = defaults.object(forKey: "gear_sound_enabled") as? Bool ?? true
        self.hapticEnabled = defaults.object(forKey: "gear_haptic_enabled") as? Bool ?? true
        
        print("🔧 GearDialViewModel 初始化完成")
    }
    
    func spinGear() {
        spinCount += 1
        
        print("🔧 Gear 旋转: 计数=\(spinCount), 当前角度=\(rotationAngle)")
        
        // 使用动画进行旋转
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1)) {
            rotationAngle += 360.0
        }
        
        // 检查是否为100的倍数（烟火/玻璃破裂）
        if spinCount % 100 == 0 {
            // 确保每个100倍数只触发一次
            if !triggered100Multiples.contains(spinCount) {
                triggered100Multiples.insert(spinCount)
                triggerSpecialEffect()
            }
        }
        // 检查是否为50的倍数但不是100的倍数（金币雨）
        else if spinCount % 50 == 0 && spinCount % 100 != 0 {
            // 确保每个符合条件的50倍数只触发一次
            if !triggered50Multiples.contains(spinCount) {
                triggered50Multiples.insert(spinCount)
                triggerCoinRain()
            }
        }
        
        // 播放音效和触觉反馈
        if soundEnabled {
            playGearSound()
        }
        
        if hapticEnabled {
            HapticManager.shared.playClick()
        }
    }
    
    private func triggerCoinRain() {
        print("🎯 Gear 达到50的倍数但不是100的倍数 (\(spinCount))，触发金币雨")
        // 通过NotificationCenter通知ContentView触发金币雨
        NotificationCenter.default.post(
            name: NSNotification.Name("TriggerCoinRain"),
            object: nil,
            userInfo: ["type": "gear", "count": spinCount]
        )
    }
    
    private func triggerSpecialEffect() {
        print("🎇 Gear 达到100的倍数 (\(spinCount))，触发特殊效果")
        
        // ✅ 修正：使用EffectManager中的当前设置效果模式
        let effectManager = EffectManager.shared
        let effectType = effectManager.currentEffectMode
        
        print("🎇 当前设置的效果模式: \(effectType)")
        
        NotificationCenter.default.post(
            name: NSNotification.Name("TriggerSpecialEffect"),
            object: nil,
            userInfo: ["type": "gear", "effect": effectType, "count": spinCount]
        )
    }
    
    private func playGearSound() {
        // 播放齿轮旋转音效
        AudioServicesPlaySystemSound(1104) // 轻微机械声
    }
    
    func resetCount() {
        spinCount = 0
        rotationAngle = 0
        triggered50Multiples.removeAll()
        triggered100Multiples.removeAll()
        
        // 播放重置音效
        if soundEnabled {
            AudioServicesPlaySystemSound(1057) // 重置音效
        }
        
        print("🔧 Gear 计数器已重置")
    }
    
    func toggleEnabled() {
        isEnabled.toggle()
        print("🔧 Gear 启用状态: \(isEnabled)")
    }
    
    func toggleSound() {
        soundEnabled.toggle()
        print("🔧 Gear 音效状态: \(soundEnabled)")
    }
    
    func toggleHaptic() {
        hapticEnabled.toggle()
        print("🔧 Gear 触觉反馈状态: \(hapticEnabled)")
    }
    
    func setOpacity(_ opacity: Double) {
        gearOpacity = opacity
        print("🔧 Gear 不透明度设置为: \(opacity)")
    }
}
