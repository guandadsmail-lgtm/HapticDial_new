import SwiftUI

struct ChangeSoundView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var soundManager = UnifiedSoundManager.shared
    @State private var showingFileImporter = false
    @State private var importError: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            SoundSelectionView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("完成") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingFileImporter = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18))
                        }
                    }
                }
        }
        .sheet(isPresented: $showingFileImporter) {
            FileImporter { url in
                do {
                    try soundManager.importCustomSound(from: url)
                } catch {
                    importError = error.localizedDescription
                    showingError = true
                }
            }
        }
        .alert("导入失败", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(importError ?? "未知错误")
        }
    }
}

struct ChangeSoundView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeSoundView()
    }
}
