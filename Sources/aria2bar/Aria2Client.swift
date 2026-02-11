import Foundation

struct Aria2Client {
    let rpcURL: String
    let secret: String

    private var tokenParam: RPCParam? {
        secret.isEmpty ? nil : .string("token:\(secret)")
    }

    private func call<T: Decodable>(method: String, params: [RPCParam] = []) async throws -> T {
        guard let url = URL(string: rpcURL) else {
            throw URLError(.badURL)
        }

        var allParams: [RPCParam] = []
        if let token = tokenParam { allParams.append(token) }
        allParams.append(contentsOf: params)

        let body = RPCRequest(method: method, params: allParams)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(RPCResponse<T>.self, from: data)

        if let error = response.error { throw error }
        guard let result = response.result else {
            throw URLError(.cannotParseResponse)
        }
        return result
    }

    private static let defaultKeys: RPCParam = .strings([
        "gid", "status", "totalLength", "completedLength",
        "downloadSpeed", "uploadSpeed", "files", "bittorrent"
    ])

    // MARK: - Query

    func getGlobalStat() async throws -> GlobalStat {
        try await call(method: "aria2.getGlobalStat")
    }

    func tellActive() async throws -> [Download] {
        try await call(method: "aria2.tellActive", params: [Self.defaultKeys])
    }

    func tellWaiting() async throws -> [Download] {
        try await call(method: "aria2.tellWaiting", params: [.int(0), .int(100), Self.defaultKeys])
    }

    func tellStopped(offset: Int = 0, num: Int = 30) async throws -> [Download] {
        try await call(method: "aria2.tellStopped", params: [.int(offset), .int(num), Self.defaultKeys])
    }

    // MARK: - Actions

    @discardableResult
    func addUri(_ uri: String) async throws -> String {
        try await call(method: "aria2.addUri", params: [.arrayOfStrings([[uri]])])
    }

    func pause(gid: String) async throws {
        let _: String = try await call(method: "aria2.pause", params: [.string(gid)])
    }

    func unpause(gid: String) async throws {
        let _: String = try await call(method: "aria2.unpause", params: [.string(gid)])
    }

    func remove(gid: String) async throws {
        let _: String = try await call(method: "aria2.remove", params: [.string(gid)])
    }

    func removeResult(gid: String) async throws {
        let _: String = try await call(method: "aria2.removeDownloadResult", params: [.string(gid)])
    }
}
