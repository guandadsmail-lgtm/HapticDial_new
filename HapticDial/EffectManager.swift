// Core/EffectManager.swift
import SwiftUI
import Combine

class EffectManager: ObservableObject {
    static let shared = EffectManager()
    
    // MARK: - Published Properties
    @Published var currentEffectMode: String = "fireworks" // "fireworks" 或 "crack"
    @Published var showSettingsInfo: Bool = false
    @Published var currentEffectDescription: String = "Classic colorful fireworks"
    
    // MARK: - Private Properties
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    private init() {
        // 从UserDefaults加载设置
        if let savedMode = defaults.string(forKey: "effect_mode") {
            currentEffectMode = savedMode
            updateEffectDescription(for: savedMode)
            print("🎆 EffectManager 从UserDefaults加载模式: \(savedMode)")
        } else {
            // 默认值为烟火效果
            currentEffectMode = "fireworks"
            defaults.set("fireworks", forKey: "effect_mode")
            updateEffectDescription(for: "fireworks")
            print("🎆 EffectManager 使用默认模式: fireworks")
        }
        
        print("🎆 EffectManager 初始化完成，当前模式: \(currentEffectMode)")
    }
    
    // MARK: - Public Methods
    
    /// 触发效果
    /// - Parameter screenSize: 可选的屏幕尺寸，如果为nil则自动获取当前屏幕尺寸
    func triggerEffect(screenSize: CGSize? = nil) {
        print("🎆 ======== 触发效果 ========")
        print("🎆 当前模式: \(currentEffectMode)")
        
        // 获取屏幕尺寸
        let effectiveScreenSize: CGSize
        
        if let providedSize = screenSize {
            effectiveScreenSize = providedSize
        } else {
            effectiveScreenSize = getScreenSize()
        }
        
        print("🎆 最终使用屏幕尺寸: \(effectiveScreenSize)")
        
        // 确保只有一个效果在运行
        stopAllEffects()
        
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
    
    /// 停止所有效果
    func stopAllEffects() {
        print("🎆 停止所有当前效果")
        CrackManager.shared.stopCracks()
        FireworksManager.shared.showFireworks = false
    }
    
    /// 设置效果模式
    /// - Parameter mode: "fireworks" 或 "crack"
    func setEffectMode(_ mode: String) {
        guard mode == "fireworks" || mode == "crack" else {
            print("🎆 错误：无效的模式: \(mode)")
            return
        }
        
        print("🎆 设置效果模式: \(mode)")
        currentEffectMode = mode
        updateEffectDescription(for: mode)
        defaults.set(mode, forKey: "effect_mode")
        
        print("🎆 效果模式已更改为: \(mode), 已保存到UserDefaults")
        
        // 显示切换提示
        showSettingsInfo = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showSettingsInfo = false
        }
    }
    
    /// 切换效果模式
    func toggleEffectMode() {
        print("🎆 切换效果模式")
        let newMode = currentEffectMode == "fireworks" ? "crack" : "fireworks"
        setEffectMode(newMode)
    }
    
    // MARK: - Computed Properties
    
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
    
    // MARK: - Helper Methods
    
    /// 获取当前屏幕尺寸
    private func getScreenSize() -> CGSize {
        #if os(iOS)
        // 改进的设备检测逻辑，支持iPad
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let size = window.bounds.size
            print("🎆 从WindowScene获取尺寸: \(size)")
            return size
        } else {
            // 使用UIScreen作为备用
            let size = UIScreen.main.bounds.size
            print("🎆 从UIScreen获取尺寸: \(size)")
            return size
        }
        #else
        // 非iOS设备使用默认尺寸
        let defaultSize = CGSize(width: 390, height: 844) // iPhone 15 Pro 默认尺寸
        print("🎆 使用默认尺寸: \(defaultSize)")
        return defaultSize
        #endif
    }
    
    /// 更新效果描述
    private func updateEffectDescription(for mode: String) {
        switch mode {
        case "fireworks":
            currentEffectDescription = "Classic colorful fireworks display"
        case "crack":
            currentEffectDescription = "Realistic glass crack effect"
        default:
            currentEffectDescription = "Special effect"
        }
    }
    
    /// 获取效果模式的显示名称（用于通知）
    func effectModeForNotification() -> String {
        return currentEffectMode
    }
}
