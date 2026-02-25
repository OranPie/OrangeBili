import Foundation

public enum L10n {
    public static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    public static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, bundle: .module, comment: ""), arguments: args)
    }
}
