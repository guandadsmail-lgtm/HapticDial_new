import SwiftUI
import UniformTypeIdentifiers

struct SoundPackStoreView: View {
    @ObservedObject var manager = SoundPackManager.shared
    @State private var showingImportSheet = false
    @State private var showingCreatePackDialog = false
    @State private var newPackName = ""
    @State private var newPackDescription = ""
    @State private var newPackAuthor = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Group {
                if manager.isLoading {
                    ProgressView("加载音效包...")
                        .padding()
                } else if manager.availablePacks.isEmpty && manager.installedSoundPacks.isEmpty {
                    emptyStateView
                } else {
                    List {
                        // 已安装的音效包
                        if !manager.installedSoundPacks.isEmpty {
                            Section("已安装的音效包") {
                                ForEach(manager.installedSoundPacks) { pack in
                                    SoundPackRow(pack: pack, isInstalled: true)
                                }
                                .onDelete { indexSet in
                                    deleteInstalledPack(at: indexSet)
                                }
                            }
                        }
                        
                        // 可用的音效包
                        if !manager.availablePacks.isEmpty {
                            Section("可用的音效包") {
                                ForEach(manager.availablePacks) { pack in
                                    SoundPackRow(pack: pack, isInstalled: false)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("音效包商店")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreatePackDialog = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingImportSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .alert("创建音效包", isPresented: $showingCreatePackDialog) {
                TextField("包名", text: $newPackName)
                TextField("描述", text: $newPackDescription)
                TextField("作者", text: $newPackAuthor)
                
                Button("取消", role: .cancel) {
                    resetCreateDialog()
                }
                Button("创建") {
                    createNewPack()
                }
            } message: {
                Text("输入新音效包的详细信息")
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [UTType.zip, UTType(filenameExtension: "hapticpack") ?? .zip],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("错误", isPresented: $showingErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                manager.loadInstalledSoundPacks()
                manager.observeSoundPackChanges()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 25) {
            Image(systemName: "speaker.wave.3")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.7))
            
            VStack(spacing: 10) {
                Text("暂无音效包")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                Text("点击下方按钮导入或创建音效包")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 15) {
                Button(action: {
                    showingImportSheet = true
                }) {
                    Label("导入音效包", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                Button(action: {
                    showingCreatePackDialog = true
                }) {
                    Label("创建新包", systemImage: "plus.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
        }
        .padding()
    }
    
    private func deleteInstalledPack(at offsets: IndexSet) {
        for index in offsets {
            guard index < manager.installedSoundPacks.count else { return }
            
            let pack = manager.installedSoundPacks[index]
            
            do {
                try manager.deleteSoundPack(pack)
                showSuccessMessage("删除成功")
            } catch {
                showError("删除失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func createNewPack() {
        guard !newPackName.isEmpty else {
            showError("包名不能为空")
            return
        }
        
        do {
            _ = try manager.createSoundPack(
                name: newPackName,
                description: newPackDescription,
                author: newPackAuthor
            )
            resetCreateDialog()
            showSuccessMessage("创建成功")
        } catch {
            showError("创建失败: \(error.localizedDescription)")
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // 获取访问权限
            guard url.startAccessingSecurityScopedResource() else {
                showError("无法访问文件")
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                _ = try manager.importSoundPack(from: url)
                manager.loadInstalledSoundPacks()
                showSuccessMessage("导入成功")
            } catch {
                showError("导入失败: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            showError("选择文件失败: \(error.localizedDescription)")
        }
    }
    
    private func resetCreateDialog() {
        newPackName = ""
        newPackDescription = ""
        newPackAuthor = ""
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
    
    private func showSuccessMessage(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
}

struct SoundPackRow: View {
    let pack: SoundPack
    let isInstalled: Bool
    
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var exportedFileURL: URL?
    @State private var showingTestAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.headline)
                    
                    if !pack.description.isEmpty {
                        Text(pack.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if isInstalled {
                    Menu {
                        Button(action: {
                            testSoundPack()
                        }) {
                            Label("测试", systemImage: "play.circle")
                        }
                        
                        Button(action: {
                            exportPack()
                        }) {
                            Label("导出", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                } else {
                    Button("安装") {
                        installPack()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
            
            HStack {
                if !pack.author.isEmpty {
                    Text("作者: \(pack.author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(pack.sounds.count) 个音效")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 8)
        .alert("删除确认", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deletePack()
            }
        } message: {
            Text("确定要删除音效包 \"\(pack.name)\" 吗？此操作不可撤销。")
        }
        .alert("测试音效包", isPresented: $showingTestAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("音效包测试中，请检查声音输出...")
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: ExportedSoundPackDocument(fileURL: exportedFileURL),
            contentType: UTType(filenameExtension: "hapticpack") ?? .zip,
            defaultFilename: "\(pack.name).hapticpack"
        ) { result in
            handleExportResult(result)
        }
    }
    
    private func installPack() {
        // 模拟安装过程
        print("安装音效包: \(pack.name)")
        
        // 在实际应用中，这里会下载并安装音效包
        HapticManager.shared.playClick()
    }
    
    private func testSoundPack() {
        showingTestAlert = true
        
        // 使用 HapticManager 测试音效包
        HapticManager.shared.testSoundPack(pack.id)
    }
    
    private func exportPack() {
        do {
            let fileURL = try SoundPackManager.shared.exportSoundPack(pack)
            exportedFileURL = fileURL
            showingExportSheet = true
        } catch {
            print("导出失败: \(error)")
            // 在实际应用中，这里应该显示错误提示
        }
    }
    
    private func deletePack() {
        do {
            try SoundPackManager.shared.deleteSoundPack(pack)
        } catch {
            print("删除失败: \(error)")
            // 在实际应用中，这里应该显示错误提示
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("导出成功: \(url)")
            // 在实际应用中，这里可以显示成功提示
        case .failure(let error):
            print("导出失败: \(error)")
            // 在实际应用中，这里应该显示错误提示
        }
        
        // 清理临时文件
        if let exportedFileURL = exportedFileURL {
            try? FileManager.default.removeItem(at: exportedFileURL)
            self.exportedFileURL = nil
        }
    }
}

// 用于文件导出的文档包装器
struct ExportedSoundPackDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "hapticpack") ?? .zip]
    }
    
    let fileURL: URL?
    
    init(fileURL: URL?) {
        self.fileURL = fileURL
    }
    
    init(configuration: ReadConfiguration) throws {
        // 这个文档是只写的，不需要读取
        fileURL = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let fileURL = fileURL,
              let fileWrapper = try? FileWrapper(url: fileURL) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return fileWrapper
    }
}

struct SoundPackStoreView_Previews: PreviewProvider {
    static var previews: some View {
        SoundPackStoreView()
    }
}
