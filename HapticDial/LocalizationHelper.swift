// LocalizationHelper.swift
import Foundation

extension String {
    // 基本本地化
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    // 带参数的本地化（用于动态文本）
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}
