import AsyncHTTPClient

class HTTP {
    let client: HTTPClient

    init() {
        self.client = HTTPClient(eventLoopGroupProvider: .createNew)
    }

    deinit {
        try? self.client.syncShutdown()
    }

    func getFromJSON<T: Decodable>(url: String, type: T.Type) async throws -> T {
        let request = HTTPClientRequest(url: url)
        let response = try await self.client.execute(request, timeout: .seconds(30))
        print("HTTP head", response)

        // if defined, the content-length headers announces the size of the body
        let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)

        var receivedBytes = 0
        // asynchronously iterates over all body fragments
        // this loop will automatically propagate backpressure correctly
        for try await buffer in response.body {
            // for this example, we are just interested in the size of the fragment
            receivedBytes += buffer.readableBytes
            
            if let expectedBytes = expectedBytes {
                // if the body size is known, we calculate a progress indicator
                let progress = Double(receivedBytes) / Double(expectedBytes)
                print("progress: \(Int(progress * 100))%")
            }
        }

        print("did receive \(receivedBytes) bytes")

        if let expectedBytes = expectedBytes, receivedBytes != expectedBytes {
            throw Error(message: "Only received \(receivedBytes), but expected \(expectedBytes)")
        }
    }
}
