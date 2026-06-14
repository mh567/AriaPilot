import AppKit
import Foundation

@MainActor
final class UpdateManager: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case available(ReleaseInfo)
        case upToDate
        case downloading
        case readyToRestart
        case failed(String)
    }

    @Published var state: State = .idle

    var currentVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.4.0"
    }

    func checkForUpdates() async {
        state = .checking
        do {
            let release = try await fetchLatestRelease()
            if Version(release.version) > Version(currentVersion),
               release.downloadURL != nil {
                state = .available(release)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func installUpdate(_ release: ReleaseInfo) async {
        guard let downloadURL = release.downloadURL else {
            state = .failed("最新版本中没有找到 macOS 安装包。")
            return
        }

        state = .downloading
        do {
            let packageURL = try await downloadPackage(from: downloadURL)
            let extractedApp = try await extractPackage(packageURL)
            try validateApp(extractedApp, for: release)
            try launchInstaller(with: extractedApp)
            state = .readyToRestart
            NSApplication.shared.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func fetchLatestRelease() async throws -> ReleaseInfo {
        do {
            return try await fetchLatestReleaseFromRedirect()
        } catch {
            return try await fetchLatestReleaseFromAPI()
        }
    }

    private func fetchLatestReleaseFromRedirect() async throws -> ReleaseInfo {
        let url = URL(string: "https://github.com/mh567/AriaPilot/releases/latest")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("AriaPilot", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.badServerResponse(nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UpdateError.badServerResponse(http.statusCode)
        }
        guard let releaseURL = http.url,
              let tagName = latestTagName(from: releaseURL) else {
            throw UpdateError.badServerResponse(http.statusCode)
        }

        let version = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let downloadURL = URL(
            string: "https://github.com/mh567/AriaPilot/releases/download/\(tagName)/AriaPilot-\(tagName)-macos.zip"
        )

        return ReleaseInfo(
            version: version,
            tagName: tagName,
            releaseURL: releaseURL,
            downloadURL: downloadURL
        )
    }

    private func latestTagName(from url: URL) -> String? {
        let components = url.pathComponents
        guard let tagIndex = components.firstIndex(of: "tag"),
              components.indices.contains(tagIndex + 1) else {
            return nil
        }
        return components[tagIndex + 1]
    }

    private func fetchLatestReleaseFromAPI() async throws -> ReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/mh567/AriaPilot/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("AriaPilot", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.badServerResponse(nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UpdateError.badServerResponse(http.statusCode)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let asset = release.assets.first { asset in
            asset.name.hasSuffix(".zip") &&
            asset.name.localizedCaseInsensitiveContains("macos")
        }

        guard let downloadURL = asset?.browserDownloadURL else {
            throw UpdateError.packageMissing
        }

        return ReleaseInfo(
            version: release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v")),
            tagName: release.tagName,
            releaseURL: release.htmlURL,
            downloadURL: downloadURL
        )
    }

    private func downloadPackage(from url: URL) async throws -> URL {
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.badServerResponse(nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UpdateError.badServerResponse(http.statusCode)
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("AriaPilot-update-\(UUID().uuidString)")
            .appendingPathExtension("zip")
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func extractPackage(_ packageURL: URL) async throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("AriaPilot-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        try await run("/usr/bin/ditto", ["-x", "-k", packageURL.path, destination.path])

        let paths = try FileManager.default.subpathsOfDirectory(atPath: destination.path)
        for path in paths {
            if path.hasSuffix("AriaPilot.app") {
                let appURL = destination.appendingPathComponent(path, isDirectory: true)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(
                    atPath: appURL.path,
                    isDirectory: &isDirectory
                ), isDirectory.boolValue {
                    return appURL
                }
            }
        }

        throw UpdateError.extractedAppMissing
    }

    private func validateApp(_ appURL: URL, for release: ReleaseInfo) throws {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any],
              let bundleID = info["CFBundleIdentifier"] as? String,
              let version = info["CFBundleShortVersionString"] as? String else {
            throw UpdateError.invalidPackage
        }

        guard bundleID == "com.ariapilot.app",
              Version(version) == Version(release.version),
              Version(version) > Version(currentVersion) else {
            throw UpdateError.invalidPackage
        }
    }

    private func launchInstaller(with newAppURL: URL) throws {
        let currentAppURL = Bundle.main.bundleURL
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AriaPilot-install-\(UUID().uuidString).sh")

        let script = """
        #!/bin/bash
        set -e

        CURRENT_PID="\(ProcessInfo.processInfo.processIdentifier)"
        NEW_APP=\(shellQuoted(newAppURL.path))
        TARGET_APP=\(shellQuoted(currentAppURL.path))
        TARGET_PARENT="$(dirname "$TARGET_APP")"

        while /bin/kill -0 "$CURRENT_PID" >/dev/null 2>&1; do
            /bin/sleep 0.2
        done

        if [ -w "$TARGET_PARENT" ]; then
            /bin/rm -rf "$TARGET_APP"
            /usr/bin/ditto "$NEW_APP" "$TARGET_APP"
            /usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1 || true
            /usr/bin/open "$TARGET_APP"
        else
            /usr/bin/osascript -e \(shellQuoted(adminAppleScript(newAppPath: newAppURL.path, targetAppPath: currentAppURL.path)))
        fi

        /bin/rm -f "$0"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        try process.run()
    }

    private func adminAppleScript(newAppPath: String, targetAppPath: String) -> String {
        let command = [
            "/bin/rm -rf \(shellQuoted(targetAppPath))",
            "/usr/bin/ditto \(shellQuoted(newAppPath)) \(shellQuoted(targetAppPath))",
            "/usr/bin/xattr -dr com.apple.quarantine \(shellQuoted(targetAppPath)) >/dev/null 2>&1 || true",
            "/usr/bin/open \(shellQuoted(targetAppPath))"
        ].joined(separator: " && ")

        return "do shell script \(appleScriptString(command)) with administrator privileges"
    }

    private func run(_ executable: String, _ arguments: [String]) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let errorPipe = Pipe()
            process.standardError = errorPipe
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw UpdateError.processFailed(message ?? "更新命令执行失败。")
            }
        }.value
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

struct ReleaseInfo: Equatable {
    let version: String
    let tagName: String
    let releaseURL: URL
    let downloadURL: URL?
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private struct Version: Comparable {
    private let parts: [Int]

    init(_ value: String) {
        parts = value
            .trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

private enum UpdateError: LocalizedError {
    case badServerResponse(Int?)
    case packageMissing
    case extractedAppMissing
    case invalidPackage
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .badServerResponse(let statusCode):
            if let statusCode {
                return "GitHub 返回了异常响应（HTTP \(statusCode)）。"
            }
            return "GitHub 返回了异常响应。"
        case .packageMissing:
            return "最新版本中没有找到 macOS 安装包。"
        case .extractedAppMissing:
            return "下载的安装包中没有 AriaPilot.app。"
        case .invalidPackage:
            return "下载的 app 安装包未通过校验。"
        case .processFailed(let message):
            return message
        }
    }
}
