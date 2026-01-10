// Views/CoinRainView.swift
import SwiftUI

struct CoinRainView: View {
    @ObservedObject private var coinManager = CoinManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            
            ZStack {
                // 半透明背景
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                
                // 绘制所有金币
                ForEach(coinManager.coins) { coin in
                    CoinView(coin: coin, opacity: coinManager.coinOpacity)
                }
            }
            .frame(width: screenSize.width, height: screenSize.height)
            .allowsHitTesting(false)
            .onAppear {
                print("💰 CoinRainView 出现，屏幕尺寸: \(screenSize)")
            }
        }
        .ignoresSafeArea()
    }
}

// 单个金币视图
struct CoinView: View {
    let coin: Coin
    let opacity: Double
    
    var body: some View {
        ZStack {
            // 金币主体 - 圆形
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            coin.color,
                            coin.color.opacity(0.8),
                            coin.color.opacity(0.6)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: coin.size / 2
                    )
                )
                .frame(width: coin.size, height: coin.size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .white.opacity(0.8),
                                    .white.opacity(0.4),
                                    .clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            
            // 金币高光
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(0.4),
                            .white.opacity(0.1),
                            .clear
                        ]),
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: coin.size * 0.4
                    )
                )
                .frame(width: coin.size * 0.4, height: coin.size * 0.4)
                .offset(x: -coin.size * 0.15, y: -coin.size * 0.15)
            
            // 金币中心
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            coin.color.opacity(0.9),
                            coin.color.opacity(0.5)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: coin.size * 0.3
                    )
                )
                .frame(width: coin.size * 0.3, height: coin.size * 0.3)
            
            // 金币值
            Text("\(coin.value)")
                .font(.system(size: coin.size * 0.3, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0)
        }
        .position(coin.position)
        .rotationEffect(.degrees(coin.rotation))
        .opacity(coin.opacity * opacity)
        .shadow(color: coin.color.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}
