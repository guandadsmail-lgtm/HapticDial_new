// Core/EffectManager.swift
import SwiftUI
import Combine

class EffectManager: ObservableObject {
    static let shared = EffectManager()
    
    // MARK: - Published Properties
    @Published var currentEffectMode: String = "fireworks"
    @Published var showSettingsInfo: Bool = false
    @Published var currentEffectDescription: String = "Classic colorful fireworks"
    
    // MARK: - Private Properties
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    private init() {
        if let savedMode = defaults.string(forKey: "effect_mode") {
            currentEffectMode = savedMode
            updateEffectDescription(for: savedMode)
        } else {
            currentEffectMode = "fireworks"
            defaults.set("fireworks", forKey: "effect_mode")
            updateEffectDescription(for: "fireworks")
        }
    }
    
    // MARK: - Public Methods
    
    func triggerEffect(screenSize: CGSize? = nil) {
        print("🎆 EffectManager: 准备触发效果 -> \(currentEffectMode)")
        
        // 1. 获取有效尺寸
        let effectiveScreenSize = screenSize ?? getScreenSize()
        
        // 2. 根据模式分发指令
        switch currentEffectMode {
        case "crack":
            // 只有当碎屏没有在运行时才触发，防止重置
            if !CrackManager.shared.isActive {
                // 停止可能正在运行的烟火
                FireworksManager.shared.stopFireworks(clearImmediately: true)
                print("💥 触发碎屏 (CrackManager)")
                CrackManager.shared.triggerCrack(screenSize: effectiveScreenSize)
            } else {
                print("💥 碎屏正在进行中，忽略触发")
            }
            
        case "fireworks":
            // 停止可能正在运行的碎屏
            CrackManager.shared.stopCracks()
            print("🎇 触发烟火 (FireworksManager)")
            // 直接调用单例，不再使用通知！
            FireworksManager.shared.triggerFireworks(screenSize: effectiveScreenSize)
            
        default:
            break
        }
    }
    
    func stopAllEffects() {
        print("🛑 停止所有效果")
        CrackManager.shared.stopCracks()
        FireworksManager.shared.stopFireworks(clearImmediately: true)
    }
    
    func setEffectMode(_ mode: String) {
        guard mode == "fireworks" || mode == "crack" else { return }
        currentEffectMode = mode
        updateEffectDescription(for: mode)
        defaults.set(mode, forKey: "effect_mode")
        
        showSettingsInfo = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showSettingsInfo = false
        }
    }
    
    func toggleEffectMode() {
        let newMode = currentEffectMode == "fireworks" ? "crack" : "fireworks"
        setEffectMode(newMode)
    }
    
    // MARK: - Helper Methods
    
    private func getScreenSize() -> CGSize {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.bounds.size
        }
        return CGSize(width: 390, height: 844)
    }
    
    private func updateEffectDescription(for mode: String) {
        if mode == "fireworks" {
            currentEffectDescription = "Classic colorful fireworks display"
        } else {
            currentEffectDescription = "Realistic glass crack effect"
        }
    }
    
    // MARK: - Computed Properties
    var currentEffectName: String { currentEffectMode == "crack" ? "Glass Crack" : "Fireworks" }
    var currentEffectIcon: String { currentEffectMode == "crack" ? "burst" : "sparkles" }
}
