import Foundation

public enum L10n {
    private static var resolvedBundle: Bundle {
        let override = UserDefaults.standard.string(forKey: "render.languageOverride") ?? "system"
        guard override != "system" else { return .module }
        if let path = Bundle.module.path(forResource: override, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .module
    }

    public static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: resolvedBundle, comment: "")
    }

    public static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, bundle: resolvedBundle, comment: ""), arguments: args)
    }
}
