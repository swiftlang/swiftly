import Foundation

extension Servers {
    public static func productionURL() throws -> URL {
        try Server1.url()
    }
}
