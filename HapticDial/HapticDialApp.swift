// HapticDial/HapticDialApp.swift - 完整增强版
import SwiftUI
import Combine
import AVFoundation
import CoreHaptics  // 添加 CoreHaptics 导入
import CoreMedia
import AudioToolbox  // 为了使用 ExtAudioFileCreateWithURL

@main
struct HapticDialApp: App {
    @State private var isLaunching = true
    @State private var showLoadingProgress = false
    @State private var loadingProgress: CGFloat = 0.0
    @State private var loadingMessage = "Initializing..."
    
    // 应用状态
    @StateObject private var appState = AppState()
    
    init() {
        // 应用启动前的配置
        configureAppearance()
        
        // 注册默认设置
        registerDefaults()
        
        // 设置音频会话
        setupAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isLaunching {
                    // 启动屏幕
                    ZStack {
                        // 背景
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.03, green: 0.03, blue: 0.08),
                                Color(red: 0.08, green: 0.05, blue: 0.15),
                                Color(red: 0.05, green: 0.05, blue: 0.12)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        // 加载进度屏幕
                        if showLoadingProgress {
                            LoadingProgressView(
                                progress: loadingProgress,
                                message: loadingMessage
                            )
                            .transition(.opacity)
                        } else {
                            LaunchScreen()
                                .transition(.opacity)
                        }
                    }
                    .onAppear {
                        // 启动初始化序列
                        startInitializationSequence()
                    }
                } else {
                    // 主应用界面
                    ContentView()
                        .preferredColorScheme(.dark)
                        .environmentObject(appState)
                        .onAppear {
                            // 应用启动完成，开始后台任务
                            startBackgroundTasks()
                        }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: isLaunching)
            .animation(.easeInOut(duration: 0.3), value: showLoadingProgress)
        }
    }
    
    // MARK: - 私有方法
    
    private func configureAppearance() {
        // 配置全局UI外观
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.gray], for: .normal)
    }
    
    private func registerDefaults() {
        // 注册UserDefaults默认值
        let defaults = UserDefaults.standard
        let defaultValues: [String: Any] = [
            "haptic_volume": 0.5,
            "haptic_intensity": 0.7,
            "effect_mode": "fireworks",
            "custom_haptic_mode": "Default",
            "custom_sound_mode": "Default",
            "crack_sound": true,
            "smart_effects_enabled": true,
            "first_launch": true
        ]
        
        defaults.register(defaults: defaultValues)
        
        // 检查是否是首次启动
        if defaults.bool(forKey: "first_launch") {
            print("🎉 首次启动应用")
            defaults.set(false, forKey: "first_launch")
            defaults.set(Date(), forKey: "first_launch_date")
        }
    }
    
    private func setupAudioSession() {
        // 配置音频会话
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("🎵 音频会话配置成功")
        } catch {
            print("⚠️ 音频会话配置失败: \(error.localizedDescription)")
        }
    }
    
    private func startInitializationSequence() {
        print("🚀 开始应用初始化...")
        
        // 第一阶段：显示启动动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                self.showLoadingProgress = true
                self.loadingProgress = 0.2
                self.loadingMessage = "Loading Haptic Engine..."
            }
            
            // 第二阶段：初始化触觉引擎
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.initializeHapticEngine()
                
                withAnimation(.linear(duration: 0.5)) {
                    self.loadingProgress = 0.5
                    self.loadingMessage = "Loading Sound System..."
                }
                
                // 第三阶段：初始化音频系统
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.initializeAudioSystem()
                    
                    withAnimation(.linear(duration: 0.5)) {
                        self.loadingProgress = 0.8
                        self.loadingMessage = "Finalizing..."
                    }
                    
                    // 第四阶段：完成初始化
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.finalizeInitialization()
                        
                        withAnimation(.linear(duration: 0.3)) {
                            self.loadingProgress = 1.0
                            self.loadingMessage = "Ready!"
                        }
                        
                        // 第五阶段：切换到主应用
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeOut(duration: 0.8)) {
                                self.isLaunching = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func initializeHapticEngine() {
        print("🔧 初始化触觉引擎...")
        
        // 确保HapticManager单例被创建
        _ = HapticManager.shared
        
        // 测试触觉是否可用
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            print("✅ 设备支持高级触觉")
            appState.hapticCapability = .supported
        } else {
            print("⚠️ 设备不支持高级触觉，使用基本触觉")
            appState.hapticCapability = .basic
        }
        
        // 预加载常用触感模式
        DispatchQueue.main.async {
            // 这里可以调用预加载方法
            // HapticManager.shared.preloadCommonPatterns()
        }
    }
    
    private func initializeAudioSystem() {
        print("🔊 初始化音频系统...")
        
        // 生成示例音频文件（仅用于演示）
        DispatchQueue.global(qos: .utility).async {
            AudioResources.shared.generateSampleSounds()
        }
        
        // 检查音频权限
        checkAudioPermissions()
    }
    
    private func checkAudioPermissions() {
        let audioSession = AVAudioSession.sharedInstance()
        
        // 使用新的方式检查录音权限
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            print("✅ 已获得音频权限")
            appState.audioPermission = .granted
        case .denied:
            print("⚠️ 音频权限被拒绝")
            appState.audioPermission = .denied
        case .undetermined:
            print("❓ 音频权限未确定")
            appState.audioPermission = .undetermined
            // 可以在这里请求权限，但我们的应用不一定需要录音权限
        @unknown default:
            print("❓ 未知的音频权限状态")
            appState.audioPermission = .unknown
        }
    }
    
    private func finalizeInitialization() {
        print("🎯 完成应用初始化")
        
        // 记录应用启动
        appState.recordAppLaunch()
        
        // 初始化智能效果管理器
        _ = SmartEffectsManager.shared
        
        // 初始化效果管理器
        _ = EffectManager.shared
        
        // 初始化烟火和破裂管理器
        _ = FireworksManager.shared
        _ = CrackManager.shared
        
        // 检查电池状态
        checkBatteryState()
        
        // 检查设备型号
        checkDeviceModel()
        
        print("""
        ✅ 应用初始化完成
        - Haptic: \(appState.hapticCapability.description)
        - Audio: \(appState.audioPermission.description)
        - Device: \(appState.deviceModel)
        - Battery: \(appState.batteryLevel)%
        """)
    }
    
    private func checkBatteryState() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let batteryLevel = Int(UIDevice.current.batteryLevel * 100)
        appState.batteryLevel = batteryLevel
        
        if UIDevice.current.batteryState == .charging {
            appState.isCharging = true
            print("🔋 设备正在充电 (\(batteryLevel)%)")
        } else {
            appState.isCharging = false
            print("🔋 电池电量: \(batteryLevel)%")
        }
    }
    
    private func checkDeviceModel() {
        let device = UIDevice.current
        appState.deviceModel = device.model
        appState.systemVersion = device.systemVersion
        
        // 检查设备性能等级
        if device.userInterfaceIdiom == .pad {
            appState.performanceLevel = .high
        } else {
            // 根据设备型号粗略判断
            // 使用新的方式获取屏幕信息
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let screenSize = windowScene.screen.bounds.size
                let screenArea = screenSize.width * screenSize.height
                
                if screenArea > 400000 { // 大致是 Pro Max 型号
                    appState.performanceLevel = .high
                } else if screenArea > 300000 { // 标准型号
                    appState.performanceLevel = .medium
                } else { // SE 或小屏型号
                    appState.performanceLevel = .low
                }
            } else {
                appState.performanceLevel = .medium
            }
        }
        
        print("📱 设备信息: \(appState.deviceModel) (\(appState.systemVersion)), 性能等级: \(appState.performanceLevel)")
    }
    
    private func startBackgroundTasks() {
        print("🔄 启动后台任务...")
        
        // 启动电池监控
        startBatteryMonitoring()
        
        // 启动内存监控
        startMemoryMonitoring()
        
        // 启动应用生命周期监控
        setupAppLifecycleObservers()
    }
    
    private func startBatteryMonitoring() {
        // 监控电池状态变化
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let batteryLevel = Int(UIDevice.current.batteryLevel * 100)
            self.appState.batteryLevel = batteryLevel
            
            // 低电量模式：降低效果强度
            if batteryLevel < 20 && !UIDevice.current.isBatteryMonitoringEnabled {
                self.appState.isLowPowerMode = true
                HapticManager.shared.setHapticIntensity(0.3)
                HapticManager.shared.setVolume(0.2)
                print("⚠️ 低电量模式激活，降低效果强度")
            } else {
                self.appState.isLowPowerMode = false
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.appState.isCharging = UIDevice.current.batteryState == .charging
        }
    }
    
    private func startMemoryMonitoring() {
        // 监控内存警告
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("⚠️ 收到内存警告，清理缓存")
            
            // 清理不必要的缓存
            self.appState.clearMemoryCache()
            
            // 暂时降低效果质量
            self.appState.isMemoryWarning = true
            self.appState.effectQuality = .low
            
            // 10秒后恢复正常
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.appState.isMemoryWarning = false
                self.appState.effectQuality = .high
            }
        }
    }
    
    private func setupAppLifecycleObservers() {
        // 应用进入后台
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 应用进入后台")
            self.appState.isInBackground = true
            
            // 暂停耗电功能 - 调用实际存在的方法
            // 注意：SmartEffectsManager 目前没有 pauseMonitoring 方法
            // 我们这里暂时注释掉，或者添加相应的方法
            // SmartEffectsManager.shared.pauseMonitoring()
            
            // 保存当前状态
            self.appState.saveAppState()
        }
        
        // 应用回到前台
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 应用回到前台")
            self.appState.isInBackground = false
            
            // 恢复功能 - 调用实际存在的方法
            // 注意：SmartEffectsManager 目前没有 resumeMonitoring 方法
            // SmartEffectsManager.shared.resumeMonitoring()
            
            // 检查电池状态
            self.checkBatteryState()
        }
        
        // 应用即将终止
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 应用即将终止")
            
            // 保存所有数据
            self.appState.saveAllData()
            
            // 清理资源
            HapticManager.shared.stopContinuousHaptic()
            // 注意：SmartEffectsManager 目前没有 cleanup 方法
            // SmartEffectsManager.shared.cleanup()
        }
    }
}

// MARK: - 加载进度视图

struct LoadingProgressView: View {
    let progress: CGFloat
    let message: String
    
    var body: some View {
        VStack(spacing: 30) {
            // 加载动画
            ZStack {
                // 背景环
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                // 进度环
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.4, blue: 0.2),
                                Color(red: 0.2, green: 0.8, blue: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                // 进度百分比
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // 加载消息
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                // 跳动点动画
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .scaleEffect(pulseScale(for: index))
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: progress
                            )
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: 200)
        }
    }
    
    private func pulseScale(for index: Int) -> CGFloat {
        let cycle = 1.2 // 完整周期
        let offset = Double(index) * 0.2
        let time = Date().timeIntervalSince1970
        let normalizedTime = (time.truncatingRemainder(dividingBy: cycle)) / cycle
        let adjustedTime = (normalizedTime + offset).truncatingRemainder(dividingBy: 1.0)
        
        if adjustedTime < 0.5 {
            return 1.0 + CGFloat(adjustedTime * 0.5)
        } else {
            return 1.5 - CGFloat((adjustedTime - 0.5) * 0.5)
        }
    }
}

// MARK: - 应用状态管理

class AppState: ObservableObject {
    @Published var hapticCapability: HapticCapability = .unknown
    @Published var audioPermission: AudioPermission = .unknown
    @Published var batteryLevel = 100
    @Published var isCharging = false
    @Published var isLowPowerMode = false
    @Published var deviceModel = "Unknown"
    @Published var systemVersion = "Unknown"
    @Published var performanceLevel: PerformanceLevel = .medium
    @Published var effectQuality: EffectQuality = .high
    @Published var isInBackground = false
    @Published var isMemoryWarning = false
    
    // 使用统计
    @Published var totalAppLaunches = 0
    @Published var totalUsageTime: TimeInterval = 0
    @Published var lastLaunchDate: Date?
    
    enum HapticCapability {
        case unknown
        case unsupported
        case basic
        case supported
        
        var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .unsupported: return "Unsupported"
            case .basic: return "Basic"
            case .supported: return "Supported"
            }
        }
    }
    
    enum AudioPermission {
        case unknown
        case undetermined
        case denied
        case granted
        
        var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .undetermined: return "Undetermined"
            case .denied: return "Denied"
            case .granted: return "Granted"
            }
        }
    }
    
    enum PerformanceLevel {
        case low
        case medium
        case high
    }
    
    enum EffectQuality {
        case low
        case medium
        case high
    }
    
    init() {
        loadAppState()
    }
    
    func recordAppLaunch() {
        totalAppLaunches += 1
        lastLaunchDate = Date()
        
        // 保存到UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(totalAppLaunches, forKey: "total_app_launches")
        defaults.set(lastLaunchDate, forKey: "last_launch_date")
        
        // 更新总使用时间
        if let lastLaunch = defaults.object(forKey: "last_session_end") as? Date {
            let sessionDuration = Date().timeIntervalSince(lastLaunch)
            totalUsageTime += sessionDuration
            defaults.set(totalUsageTime, forKey: "total_usage_time")
        }
        
        print("📊 应用启动次数: \(totalAppLaunches), 总使用时间: \(formatTimeInterval(totalUsageTime))")
    }
    
    func saveAppState() {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: "last_session_end")
        defaults.synchronize()
    }
    
    func saveAllData() {
        saveAppState()
        
        // 保存所有需要持久化的数据
        let defaults = UserDefaults.standard
        defaults.set(totalUsageTime, forKey: "total_usage_time")
        defaults.synchronize()
        
        print("💾 应用数据已保存")
    }
    
    private func loadAppState() {
        let defaults = UserDefaults.standard
        totalAppLaunches = defaults.integer(forKey: "total_app_launches")
        totalUsageTime = defaults.double(forKey: "total_usage_time")
        lastLaunchDate = defaults.object(forKey: "last_launch_date") as? Date
    }
    
    func clearMemoryCache() {
        // 清理内存缓存
        print("🧹 清理内存缓存")
        
        // 可以在这里添加清理代码
        // 例如：清理图片缓存、临时数据等
    }
    
    func getPerformanceRecommendation() -> String {
        switch performanceLevel {
        case .low:
            return "Consider using simpler effects on this device for better performance."
        case .medium:
            return "Device can handle most effects well."
        case .high:
            return "Device can handle all effects with optimal performance."
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - 音频资源管理器

class AudioResources {
    static let shared = AudioResources()
    
    private let fileManager = FileManager.default
    private let documentsURL: URL
    private var generatedSounds: Set<String> = []
    
    private init() {
        // 获取文档目录
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 创建音频目录
        let audioDirectory = documentsURL.appendingPathComponent("AudioResources")
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }
        
        // 加载已生成的声音列表
        loadGeneratedSounds()
    }
    
    func generateSampleSounds() {
        print("🎵 开始生成示例音频...")
        
        // 定义要生成的声音
        let sounds = [
            ("mechanical_click", 1000, 0.08, 0.3),
            ("mechanical_tick", 1200, 0.05, 0.2),
            ("mechanical_pop", 800, 0.12, 0.4),
            ("digital_click", 2000, 0.06, 0.3),
            ("digital_tick", 1800, 0.04, 0.25),
            ("digital_pop", 1500, 0.1, 0.35),
            ("water_drop", 600, 0.15, 0.5),
            ("wood_tap", 400, 0.12, 0.3),
            ("bubble_pop", 500, 0.1, 0.4),
            ("laser_click", 3000, 0.07, 0.3),
            ("synth_tick", 2500, 0.05, 0.25),
            ("energy_pop", 2800, 0.09, 0.45)
        ]
        
        // 在后台线程生成声音
        DispatchQueue.global(qos: .userInitiated).async {
            for (name, frequency, duration, volume) in sounds {
                // 检查是否已生成
                if !self.generatedSounds.contains(name) {
                    self.generateTone(name: name, frequency: Float(frequency), duration: duration, volume: Float(volume))
                    self.generatedSounds.insert(name)
                    self.saveGeneratedSounds()
                    
                    // 短暂延迟，避免同时生成太多文件
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
            
            print("✅ 示例音频生成完成，共 \(self.generatedSounds.count) 个文件")
        }
    }
    
    private func generateTone(name: String, frequency: Float, duration: Double, volume: Float) {
        // 简单生成正弦波音频文件
        let outputURL = documentsURL.appendingPathComponent("\(name).caf")
        
        // 如果文件已存在，跳过生成
        if fileManager.fileExists(atPath: outputURL.path) {
            print("🎵 音频文件已存在: \(name)")
            return
        }
        
        // 创建音频文件设置
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = 44100.0
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        asbd.mBytesPerPacket = 4
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerFrame = 4
        asbd.mChannelsPerFrame = 1
        asbd.mBitsPerChannel = 32
        asbd.mReserved = 0
        
        var audioFile: ExtAudioFileRef?
        
        // 创建音频文件
        let status = ExtAudioFileCreateWithURL(
            outputURL as CFURL,
            kAudioFileCAFType,
            &asbd,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &audioFile
        )
        
        guard status == noErr, let file = audioFile else {
            print("❌ 创建音频文件失败: \(name)")
            return
        }
        
        // 生成音频数据
        let sampleRate: Double = 44100.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let channelData = buffer.floatChannelData?[0]
        
        // 生成正弦波
        let phaseIncrement = (2.0 * .pi * Double(frequency)) / sampleRate
        
        for frame in 0..<Int(frameCount) {
            let samplePhase = Float(phaseIncrement * Double(frame))
            
            // 应用ADSR包络
            let envelope = adsrEnvelope(frame: frame, totalFrames: Int(frameCount))
            
            // 生成正弦波样本
            let sample = sin(samplePhase) * volume * envelope
            
            channelData?[frame] = sample
        }
        
        // 写入音频文件
        let writeStatus = ExtAudioFileWrite(file, frameCount, buffer.audioBufferList)
        
        // 清理
        ExtAudioFileDispose(file)
        
        if writeStatus == noErr {
            print("✅ 生成音频: \(name) (\(Int(frequency))Hz, \(duration)s)")
        } else {
            print("❌ 写入音频文件失败: \(name)")
        }
    }
    
    private func adsrEnvelope(frame: Int, totalFrames: Int) -> Float {
        let attack = 0.1 // 起音时间比例
        let decay = 0.2  // 衰减时间比例
        let sustain = 0.6 // 持续电平
        let release = 0.1 // 释音时间比例
        
        let attackFrames = Int(Float(totalFrames) * Float(attack))
        let decayFrames = Int(Float(totalFrames) * Float(decay))
        let releaseStart = totalFrames - Int(Float(totalFrames) * Float(release))
        
        if frame < attackFrames {
            // 起音阶段：线性增加到1.0
            return Float(frame) / Float(attackFrames)
        } else if frame < attackFrames + decayFrames {
            // 衰减阶段：线性衰减到持续电平
            let decayProgress = Float(frame - attackFrames) / Float(decayFrames)
            return 1.0 - decayProgress * (1.0 - Float(sustain))
        } else if frame < releaseStart {
            // 持续阶段
            return Float(sustain)
        } else {
            // 释音阶段：线性衰减到0
            let releaseProgress = Float(frame - releaseStart) / Float(totalFrames - releaseStart)
            return Float(sustain) * (1.0 - releaseProgress)
        }
    }
    
    func getAudioURL(for soundName: String) -> URL? {
        let url = documentsURL.appendingPathComponent("\(soundName).caf")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
    
    func playSound(_ soundName: String) {
        guard let url = getAudioURL(for: soundName) else {
            print("❌ 音频文件不存在: \(soundName)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            print("▶️ 播放音频: \(soundName)")
        } catch {
            print("❌ 播放音频失败: \(error)")
        }
    }
    
    private func loadGeneratedSounds() {
        let key = "generated_sounds"
        if let sounds = UserDefaults.standard.stringArray(forKey: key) {
            generatedSounds = Set(sounds)
        }
    }
    
    private func saveGeneratedSounds() {
        UserDefaults.standard.set(Array(generatedSounds), forKey: "generated_sounds")
    }
    
    func cleanupOldFiles() {
        // 清理30天前的音频文件
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                if file.pathExtension == "caf" {
                    let attributes = try fileManager.attributesOfItem(atPath: file.path)
                    if let creationDate = attributes[.creationDate] as? Date,
                       creationDate < cutoffDate {
                        try fileManager.removeItem(at: file)
                        print("🗑️ 清理旧音频文件: \(file.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("❌ 清理音频文件失败: \(error)")
        }
    }
}
