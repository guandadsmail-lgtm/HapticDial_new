// Core/FireworksManager.swift
import SwiftUI
import Combine

class FireworksManager: ObservableObject {
    static let shared = FireworksManager()
    
    @Published var showFireworks = false
    
    private init() {}
    
    func triggerFireworks() {
        guard !showFireworks else { return }
        
        showFireworks = true
        
        // 8秒后自动隐藏（烟火持续5秒+3秒淡出）
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            self.showFireworks = false
        }
    }
}
