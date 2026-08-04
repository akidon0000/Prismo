import Ignite

@MainActor
func run() async throws {
    var site = PrismoSite()
    try await site.publish()
}

try await run()
