// Core/EffectManager.swift
import SwiftUI
import Combine

class EffectManager: ObservableObject {
    static let shared = EffectManager()
    
    @Published var currentEffectMode: String = "fireworks" // "fireworks" 或 "crack"
    @Published var showSettingsInfo: Bool = false
    
    private let defaults = UserDefaults.standard
    
    private init() {
        // 从UserDefaults加载设置
        if let savedMode = defaults.string(forKey: "effect_mode") {
            currentEffectMode = savedMode
        } else {
            // 默认值为烟火效果
            currentEffectMode = "fireworks"
            defaults.set("fireworks", forKey: "effect_mode")
        }
        
        print("🎆 EffectManager 初始化，当前模式: \(currentEffectMode)")
    }
    
    // 注意：这个方法需要在调用时传入屏幕尺寸
    func triggerEffect(screenSize: CGSize? = nil) {
        print("🎆 触发效果，当前模式: \(currentEffectMode)")
        
        // 获取屏幕尺寸
        let effectiveScreenSize: CGSize
        
        if let providedSize = screenSize {
            effectiveScreenSize = providedSize
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first {
            effectiveScreenSize = window.frame.size
        } else {
            effectiveScreenSize = CGSize(width: 390, height: 844) // iPhone 15 Pro 默认尺寸
        }
        
        print("🎆 使用屏幕尺寸: \(effectiveScreenSize)")
        
        switch currentEffectMode {
        case "crack":
            print("💥 触发玻璃破裂效果")
            CrackManager.shared.triggerCrack(screenSize: effectiveScreenSize)
            
        case "fireworks":
            print("🎇 触发烟火效果")
            FireworksManager.shared.triggerFireworks()
            
        default:
            print("🎇 触发烟火效果 (默认)")
            FireworksManager.shared.triggerFireworks()
        }
    }
    
    func setEffectMode(_ mode: String) {
        guard mode == "fireworks" || mode == "crack" else { return }
        
        currentEffectMode = mode
        defaults.set(mode, forKey: "effect_mode")
        
        print("🎆 效果模式已更改为: \(mode)")
        
        // 显示切换提示
        showSettingsInfo = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showSettingsInfo = false
        }
    }
    
    func toggleEffectMode() {
        let newMode = currentEffectMode == "fireworks" ? "crack" : "fireworks"
        setEffectMode(newMode)
    }
    
    // 添加回 currentEffectName 属性，返回本地化后的字符串
    var currentEffectName: String {
        switch currentEffectMode {
        case "crack":
            return "EFFECT_NAME_GLASS_CRACK".localized
        case "fireworks":
            return "EFFECT_NAME_FIREWORKS".localized
        default:
            return "EFFECT_NAME_FIREWORKS".localized
        }
    }
    
    // 保留 localizedEffectName 用于其他场景
    var localizedEffectName: LocalizedStringKey {
        switch currentEffectMode {
        case "crack":
            return "EFFECT_NAME_GLASS_CRACK"
        case "fireworks":
            return "EFFECT_NAME_FIREWORKS"
        default:
            return "EFFECT_NAME_FIREWORKS"
        }
    }
    
    // 同样需要本地化描述
    var currentEffectDescription: String {
        switch currentEffectMode {
        case "crack":
            return NSLocalizedString("EFFECT_DESC_GLASS_CRACK", comment: "达到100次时触发全屏玻璃破裂效果")
        case "fireworks":
            return NSLocalizedString("EFFECT_DESC_FIREWORKS", comment: "达到100次时触发烟火效果")
        default:
            return NSLocalizedString("EFFECT_DESC_FIREWORKS", comment: "达到100次时触发烟火效果")
        }
    }
    
    var currentEffectIcon: String {
        switch currentEffectMode {
        case "crack":
            return "burst"
        case "fireworks":
            return "sparkles"
        default:
            return "sparkles"
        }
    }
}
