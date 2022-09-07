import CLibArchive
import Foundation

// The code in this file consists mainly of a Swift port of the "Complete Extractor" example included in the libarchive
// documentation: https://github.com/libarchive/libarchive/wiki/Examples#a-complete-extractor

struct ExtractError: Error {
    let message: String?

    init(archive: OpaquePointer?) {
        self.message = archive_error_string(archive).map { err in
            String(cString: err)
        }
    }

    init(message: String) {
        self.message = message
    }
}

/// Write the data from the given readArchive into the writeArchive.
func copyData(readArchive: OpaquePointer?, writeArchive: OpaquePointer?) throws {
    var r = 0
    var buff: UnsafeRawPointer? = nil
    var size = 0
    var offset: Int64 = 0

    while true {
        r = Int(archive_read_data_block(readArchive, &buff, &size, &offset))
        if r == ARCHIVE_EOF {
            return
        }
        guard r == ARCHIVE_OK else {
            throw ExtractError(archive: readArchive)
        }
        r = Int(archive_write_data_block(writeArchive, buff, size, offset));
        guard r == ARCHIVE_OK else {
            throw ExtractError(archive: writeArchive)
        }
    }
}

/// Extract the archive at the provided path. The name of each file included in the archive will be passed to
/// the provided closure which will return the path the file will be written to.
///
/// This uses libarchive under the hood, so a wide variety of archive formats are supported (e.g. .tar.gz).
internal func extractArchive(atPath archivePath: URL, transform: (String) -> URL) throws {
    var flags = Int32(0);
    flags = ARCHIVE_EXTRACT_TIME;
    flags |= ARCHIVE_EXTRACT_PERM;
    flags |= ARCHIVE_EXTRACT_ACL;
    flags |= ARCHIVE_EXTRACT_FFLAGS;

    let a = archive_read_new();
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);

    let ext = archive_write_disk_new();
    archive_write_disk_set_options(ext, flags);
    archive_write_disk_set_standard_lookup(ext);

    defer {
        archive_read_close(a);
        archive_read_free(a);
        archive_write_close(ext);
        archive_write_free(ext);
    }

    if archive_read_open_filename(a, archivePath.path, 10240) != 0 {
        throw ExtractError(message: "Failed to open \"\(archivePath.path)\"")
    }

    while true {
        var r = Int32(0);
        var entry: OpaquePointer? = nil
        r = archive_read_next_header(a, &entry);
        if r == ARCHIVE_EOF {
            break;
        }
        guard r == ARCHIVE_OK else {
            throw ExtractError(archive: a)
        }

        let currentPath = String(cString: archive_entry_pathname(entry))
        archive_entry_set_pathname(entry, transform(currentPath).path)
        r = archive_write_header(ext, entry);
        guard r == ARCHIVE_OK else {
            throw ExtractError(archive: ext)
        }

        if archive_entry_size(entry) > 0 {
            try copyData(readArchive: a, writeArchive: ext)
        }

        r = archive_write_finish_entry(ext);
        guard r == ARCHIVE_OK else {
            throw ExtractError(archive: ext)
        }
    }
}
