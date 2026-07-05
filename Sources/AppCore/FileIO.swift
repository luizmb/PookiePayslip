import AppDomain
import Foundation
import ReactiveConcurrency

// FileIO is internal to AppCore — only World exposes its closures.
// IO is described as a `Publisher` (lazy, Combine-like): the error travels in the typed
// failure channel, never thrown to the caller. Nothing runs until the Store subscribes.
struct FileIO {
    var read:  @Sendable (String) -> Publisher<Data, ReadingError>
    var write: @Sendable (Data, String) -> Publisher<Void, SavingError>
    var exportZip: @Sendable () -> Publisher<Data, ExportError>   // zips the whole data directory
}

// Zips a directory into an in-memory `.zip` using NSFileCoordinator's `.forUploading` option
// (Foundation-only, no dependency) and returns the archive bytes.
private func zipDirectory(_ dir: URL) -> Result<Data, ExportError> {
    let coordinator = NSFileCoordinator()
    var coordinationError: NSError?
    var payload: Result<Data, ExportError> = .failure(.noData)
    coordinator.coordinate(readingItemAt: dir, options: [.forUploading], error: &coordinationError) { zipURL in
        payload = Result { try Data(contentsOf: zipURL) }.mapError { ExportError.ioError(underlying: $0) }
    }
    if let coordinationError { return .failure(.ioError(underlying: coordinationError)) }
    return payload
}

extension FileIO {
    static let live: FileIO = {
        let dir: URL = {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appending(path: "PookiePayslip", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }()

        return FileIO(
            read: { filename in
                Publisher.future {
                    let url = dir.appending(path: filename)
                    do {
                        return Result<Data, ReadingError>.success(try Data(contentsOf: url))
                    } catch let e as CocoaError where e.code == .fileNoSuchFile || e.code == .fileReadNoSuchFile {
                        return .failure(.fileNotFound(filename: filename))
                    } catch {
                        return .failure(.ioError(filename: filename, underlying: error))
                    }
                }
            },
            write: { data, filename in
                Publisher.future {
                    let url = dir.appending(path: filename)
                    do {
                        try data.write(to: url, options: .atomic)
                        return Result<Void, SavingError>.success(())
                    } catch {
                        return .failure(.ioError(filename: filename, underlying: error))
                    }
                }
            },
            exportZip: { Publisher.future { zipDirectory(dir) } }
        )
    }()

    // In-memory store for tests and previews — backed by an actor for Swift 6 async safety.
    // The actor already returns a `Result`, so the Result-returning `future` form fits directly.
    static func mock(initial: [String: Data] = [:]) -> FileIO {
        let storage = MockStorage(initial)
        return FileIO(
            read:  { filename in Publisher.future { await storage.read(filename) } },
            write: { data, filename in Publisher.future { await storage.write(data, filename) } },
            exportZip: { .just(Data("mock-zip".utf8)) }
        )
    }
}

private actor MockStorage {
    var files: [String: Data]
    init(_ initial: [String: Data]) { files = initial }

    func read(_ filename: String) -> Result<Data, ReadingError> {
        guard let data = files[filename] else { return .failure(.fileNotFound(filename: filename)) }
        return .success(data)
    }

    func write(_ data: Data, _ filename: String) -> Result<Void, SavingError> {
        files[filename] = data
        return .success(())
    }
}
