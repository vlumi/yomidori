import Foundation

enum AppInfo {
    static var versionLine: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        let commit = (info["GitCommitSHA"] as? String).map { String($0.prefix(7)) }
        return ["\(version) (\(build))", commit].compactMap { $0 }.joined(separator: " · ")
    }

    static var notices: String {
        guard let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }
}
