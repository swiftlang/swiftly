import Foundation

extension Servers {
    public static func productionURL() throws -> URL {
        try Server1.url()
    }

    public static func productionDownloadURL() throws -> URL {
        try Server2.url()
    }
}
