import AsyncHTTPClient
import Foundation
import NIOFoundationCompat

public class HTTP {
    let client: HTTPClient

    public init() {
        self.client = HTTPClient(eventLoopGroupProvider: .createNew)
    }

    deinit {
        try? self.client.syncShutdown()
    }

    public func getFromJSON<T: Decodable>(url: String, type: T.Type) async throws -> T {
        var request = HTTPClientRequest(url: url)
        request.headers.add(name: "User-Agent", value: "swiftly")
        let response = try await client.execute(request, timeout: .seconds(30))

        // if defined, the content-length headers announces the size of the body
        let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init) ?? 1024 * 1024
        let buffer = try await response.body.collect(upTo: expectedBytes)

        return try JSONDecoder().decode(type.self, from: buffer)
    }
}
