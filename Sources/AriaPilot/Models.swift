import Foundation

// MARK: - JSON-RPC

enum RPCParam: Encodable {
    case string(String)
    case int(Int)
    case strings([String])
    case arrayOfStrings([[String]])
    case options([String: String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .strings(let v): try container.encode(v)
        case .arrayOfStrings(let v): try container.encode(v)
        case .options(let v): try container.encode(v)
        }
    }
}

struct RPCRequest: Encodable {
    let jsonrpc = "2.0"
    let id = "AriaPilot"
    let method: String
    let params: [RPCParam]
}

struct RPCResponse<T: Decodable>: Decodable {
    let id: String?
    let result: T?
    let error: RPCError?
}

struct RPCError: Decodable, LocalizedError {
    let code: Int
    let message: String
    var errorDescription: String? { message }
}

struct Aria2Options: Decodable {
    let dir: String?
    let split: String?
    let maxConnectionPerServer: String?
    let maxConcurrentDownloads: String?
    let maxOverallDownloadLimit: String?
    let maxOverallUploadLimit: String?

    enum CodingKeys: String, CodingKey {
        case dir
        case split
        case maxConnectionPerServer = "max-connection-per-server"
        case maxConcurrentDownloads = "max-concurrent-downloads"
        case maxOverallDownloadLimit = "max-overall-download-limit"
        case maxOverallUploadLimit = "max-overall-upload-limit"
    }
}

struct Aria2Version: Decodable {
    let version: String
    let enabledFeatures: [String]?
}

// MARK: - Download

struct Download: Identifiable, Codable {
    let gid: String
    let status: String
    let totalLength: String
    let completedLength: String
    let downloadSpeed: String
    let uploadSpeed: String
    let files: [FileInfo]?
    let bittorrent: BTInfo?

    var id: String { gid }

    enum CodingKeys: String, CodingKey {
        case gid, status, totalLength, completedLength
        case downloadSpeed, uploadSpeed, files, bittorrent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gid = try c.decode(String.self, forKey: .gid)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        totalLength = try c.decodeIfPresent(String.self, forKey: .totalLength) ?? "0"
        completedLength = try c.decodeIfPresent(String.self, forKey: .completedLength) ?? "0"
        downloadSpeed = try c.decodeIfPresent(String.self, forKey: .downloadSpeed) ?? "0"
        uploadSpeed = try c.decodeIfPresent(String.self, forKey: .uploadSpeed) ?? "0"
        files = try c.decodeIfPresent([FileInfo].self, forKey: .files)
        bittorrent = try c.decodeIfPresent(BTInfo.self, forKey: .bittorrent)
    }

    var totalBytes: Int64 { Int64(totalLength) ?? 0 }
    var completedBytes: Int64 { Int64(completedLength) ?? 0 }
    var speed: Int64 { Int64(downloadSpeed) ?? 0 }
    var upSpeed: Int64 { Int64(uploadSpeed) ?? 0 }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(completedBytes) / Double(totalBytes)
    }

    var displayName: String {
        if let name = bittorrent?.info?.name, !name.isEmpty { return name }
        if let path = files?.first?.path, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        if let uri = files?.first?.uris?.first?.uri, !uri.isEmpty {
            return URL(string: uri)?.lastPathComponent ?? gid
        }
        return gid
    }

    var isActive: Bool { status == "active" }
    var isPaused: Bool { status == "paused" || status == "waiting" }
    var isComplete: Bool { status == "complete" }
    var isError: Bool { status == "error" || status == "removed" }
}

struct FileInfo: Codable {
    let path: String?
    let uris: [URIInfo]?

    var localPath: String? {
        path?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct URIInfo: Codable {
    let uri: String
}

struct BTInfo: Codable {
    let info: BTName?
}

struct BTName: Codable {
    let name: String?
}

// MARK: - Global Stat

struct GlobalStat: Decodable {
    let downloadSpeed: String
    let uploadSpeed: String
    let numActive: String
    let numWaiting: String
    let numStopped: String

    var dlSpeed: Int64 { Int64(downloadSpeed) ?? 0 }
    var ulSpeed: Int64 { Int64(uploadSpeed) ?? 0 }
    var activeCount: Int { Int(numActive) ?? 0 }
    var waitingCount: Int { Int(numWaiting) ?? 0 }
    var stoppedCount: Int { Int(numStopped) ?? 0 }
}
