// Views/SoundPackStore/SoundPackStore.swift
import SwiftUI

struct SoundPackStoreView: View {
    @StateObject private var soundPackManager = SoundPackManager.shared
    @StateObject private var hapticManager = HapticManager.shared
    
    @State private var showingInstallAlert = false
    @State private var installPackId: String?
    @State private var showingInstallSuccess = false
    @State private var successMessage = ""
    @State private var showingInstallError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    // 修复：添加一个布尔状态来跟踪安装状态，移除未使用的参数
    @State private var isInstallingAll = false
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.08, green: 0.06, blue: 0.15)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // 内容
                VStack(spacing: 0) {
                    // 标题
                    VStack(spacing: 8) {
                        Text("音效包商店")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("安装自定义音效，增强你的触感体验")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    // 控制按钮
                    HStack(spacing: 15) {
                        Button(action: {
                            Task {
                                do {
                                    if let packId = hapticManager.currentCustomSoundPack {
                                        hapticManager.setCurrentSoundPack(nil)
                                    } else {
                                        // 选择第一个音效包
                                        if let firstPack = soundPackManager.availablePacks.first {
                                            hapticManager.setCurrentSoundPack(firstPack.id)
                                        }
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: hapticManager.currentCustomSoundPack != nil ? "speaker.wave.2.fill" : "speaker.slash")
                                Text(hapticManager.currentCustomSoundPack != nil ? "使用音效" : "禁用音效")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            soundPackManager.refreshAll()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("刷新")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            showInstallAllAlert()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("一键安装")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    // 音效包列表
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(soundPackManager.availablePacks) { pack in
                                SoundPackCard(
                                    pack: pack,
                                    isInstalled: soundPackManager.isSoundPackInstalled(pack.id),
                                    isCurrent: hapticManager.currentCustomSoundPack == pack.id,
                                    onInstall: { installPack(pack) },
                                    onUninstall: { uninstallPack(pack) },
                                    onTest: { testPack(pack) },
                                    onUse: { usePack(pack) }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    
                    // 当前使用的音效包
                    if let currentPackId = hapticManager.currentCustomSoundPack,
                       let currentPack = soundPackManager.availablePacks.first(where: { $0.id == currentPackId }) {
                        VStack(spacing: 8) {
                            Text("当前使用")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                Text(currentPack.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button("测试") {
                                    testPack(currentPack)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 20)
                    }
                }
                
                // 安装状态覆盖层
                if soundPackManager.isInstalling {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                
                                VStack(spacing: 8) {
                                    Text("安装中...")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    if let installingPackId = soundPackManager.currentInstallation,
                                       let pack = soundPackManager.availablePacks.first(where: { $0.id == installingPackId }) {
                                        Text(pack.name)
                                            .font(.headline)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Text("请稍候")
                                        .font(.body)
                                        .foregroundColor(.gray)
                                }
                            }
                        )
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("安装音效包", isPresented: $showingInstallAlert) {
            Button("取消", role: .cancel) { }
            Button("安装") {
                if let packId = installPackId {
                    installPackById(packId)
                }
            }
        } message: {
            if let packId = installPackId,
               let pack = soundPackManager.availablePacks.first(where: { $0.id == packId }) {
                Text("确定要安装「\(pack.name)」吗？")
            }
        }
        .alert("安装成功", isPresented: $showingInstallSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .alert("安装失败", isPresented: $showingInstallError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            soundPackManager.refreshAll()
        }
    }
    
    // MARK: - 操作函数
    
    private func installPack(_ pack: SoundPack) {
        installPackId = pack.id
        showingInstallAlert = true
    }
    
    private func installPackById(_ packId: String) {
        Task {
            do {
                let installedPack = try await soundPackManager.installSoundPack(packId)
                
                DispatchQueue.main.async {
                    self.successMessage = "「\(installedPack.name)」安装成功！"
                    self.showingInstallSuccess = true
                    
                    // 播放测试
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        hapticManager.testSoundPack(packId)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "安装失败: \(error.localizedDescription)"
                    self.showingInstallError = true
                }
            }
        }
    }
    
    private func uninstallPack(_ pack: SoundPack) {
        Task {
            do {
                try soundPackManager.deleteSoundPack(pack)
                
                DispatchQueue.main.async {
                    // 如果正在使用这个包，清除当前选择
                    if hapticManager.currentCustomSoundPack == pack.id {
                        hapticManager.setCurrentSoundPack(nil)
                    }
                    
                    self.successMessage = "「\(pack.name)」已卸载"
                    self.showingInstallSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "卸载失败: \(error.localizedDescription)"
                    self.showingInstallError = true
                }
            }
        }
    }
    
    private func testPack(_ pack: SoundPack) {
        hapticManager.testSoundPack(pack.id)
    }
    
    private func usePack(_ pack: SoundPack) {
        if hapticManager.currentCustomSoundPack == pack.id {
            hapticManager.setCurrentSoundPack(nil)
        } else {
            hapticManager.setCurrentSoundPack(pack.id)
        }
    }
    
    private func showInstallAllAlert() {
        let alert = UIAlertController(
            title: "一键安装所有音效包",
            message: "确定要安装所有4个内置音效包吗？这可能需要一些时间。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "安装", style: .default) { _ in
            installAllPacks()
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func installAllPacks() {
        Task {
            let installedPacks = await soundPackManager.installAllBuiltInPacks()
            
            DispatchQueue.main.async {
                if installedPacks.isEmpty {
                    self.successMessage = "所有音效包都已安装"
                } else {
                    self.successMessage = "成功安装 \(installedPacks.count) 个音效包"
                }
                self.showingInstallSuccess = true
                
                // 播放测试
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let firstPack = installedPacks.first {
                        hapticManager.testSoundPack(firstPack.id)
                    }
                }
            }
        }
    }
}

// MARK: - 音效包卡片组件

struct SoundPackCard: View {
    let pack: SoundPack
    let isInstalled: Bool
    let isCurrent: Bool
    let onInstall: () -> Void
    let onUninstall: () -> Void
    let onTest: () -> Void
    let onUse: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(pack.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if isCurrent {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        
                        if isInstalled {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    Text(pack.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 作者和版本
                VStack(alignment: .trailing, spacing: 4) {
                    Text(pack.author)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text("v\(pack.version)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // 音效列表
            if !pack.sounds.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("包含音效 (\(pack.sounds.count)个)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        ForEach(pack.sounds.prefix(3)) { sound in
                            Text(sound.name)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white.opacity(0.8))
                                .cornerRadius(6)
                        }
                        
                        if pack.sounds.count > 3 {
                            Text("+\(pack.sounds.count - 3)更多")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(.gray)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            // 操作按钮
            HStack(spacing: 10) {
                if isInstalled {
                    // 已安装状态
                    Button(action: onTest) {
                        HStack {
                            Image(systemName: "play.circle")
                            Text("测试")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: onUse) {
                        HStack {
                            Image(systemName: isCurrent ? "speaker.slash" : "speaker.wave.2")
                            Text(isCurrent ? "停用" : "使用")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isCurrent ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: onUninstall) {
                        HStack {
                            Image(systemName: "trash")
                            Text("卸载")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                } else {
                    // 未安装状态
                    Button(action: onInstall) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("安装")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    // 预览按钮（即使未安装也可以试听）
                    Button(action: onTest) {
                        HStack {
                            Image(systemName: "play.circle")
                            Text("预览")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCurrent ? Color.green.opacity(0.3) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 预览

struct SoundPackStoreView_Previews: PreviewProvider {
    static var previews: some View {
        SoundPackStoreView()
            .preferredColorScheme(.dark)
    }
}
