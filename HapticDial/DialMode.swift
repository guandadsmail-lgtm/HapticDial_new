// Models/DialMode.swift
import Foundation
import Combine

enum DialMode: String, CaseIterable {
    case ratchet    // 棘轮模式
    case aperture   // 光圈模式
    
    var displayName: String {
        switch self {
        case .ratchet: return "RATCHET"
        case .aperture: return "APERTURE"
        }
    }
    
    var iconName: String {
        switch self {
        case .ratchet: return "gear"
        case .aperture: return "camera.aperture"
        }
    }
    
    // 触觉参数
    var hapticSharpness: Float {
        switch self {
        case .ratchet: return 0.9   // 更尖锐
        case .aperture: return 0.3   // 更柔和
        }
    }
    
    var hapticIntensity: Float {
        switch self {
        case .ratchet: return 0.7
        case .aperture: return 0.4
        }
    }
    
    // 每转多少度触发一次触觉
    var notchInterval: Double {
        switch self {
        case .ratchet: return 12.0   // 30个齿/圈
        case .aperture: return 22.5  // 16个定位点/圈
        }
    }
    
    // 描述文本
    var description: String {
        switch self {
        case .ratchet: return "Mechanical click every 12°"
        case .aperture: return "Smooth detent every 22.5°"
        }
    }
}
