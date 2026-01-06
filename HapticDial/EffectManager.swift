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
    
    var currentEffectName: String {
        switch currentEffectMode {
        case "crack":
            return "Glass Crack"
        case "fireworks":
            return "Fireworks"
        default:
            return "Fireworks"
        }
    }
    
    var currentEffectDescription: String {
        switch currentEffectMode {
        case "crack":
            return "Trigger full-screen glass crack effect when reaching 100 times"
        case "fireworks":
            return "Trigger fireworks effect when reaching 100 times"
        default:
            return "Trigger fireworks effect when reaching 100 times"
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
