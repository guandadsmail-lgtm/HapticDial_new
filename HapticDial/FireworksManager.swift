// Core/FireworksManager.swift
import SwiftUI
import Combine

class FireworksManager: ObservableObject {
    static let shared = FireworksManager()
    
    @Published var showFireworks = false
    
    private init() {}
    
    func triggerFireworks() {
        print("🎇 ======== 触发烟火效果 ========")
        
        // 先停止任何可能正在运行的效果
        if showFireworks {
            print("🎇 烟火效果已经在运行，先停止")
            showFireworks = false
        }
        
        // 重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🎇 开始显示烟火")
            self.showFireworks = true
            
            // 30秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                print("🎇 30秒时间到，隐藏烟火")
                self.showFireworks = false
            }
        }
    }
}
