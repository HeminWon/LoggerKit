import Foundation

private final class LoggerKitBundleToken {}

extension Bundle {
    static var loggerKit: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        let frameworkBundle = Bundle(for: LoggerKitBundleToken.self)
        if let resourceURL = frameworkBundle.url(forResource: "LoggerKit", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceURL) {
            return resourceBundle
        }
        return frameworkBundle
        #endif
    }
}
