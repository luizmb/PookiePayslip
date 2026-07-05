import Foundation

public enum ReadingError: Error, Sendable {
    case fileNotFound(filename: String)
    case permissionDenied(filename: String)
    case ioError(filename: String, underlying: any Error & Sendable)
}

public enum SavingError: Error, Sendable {
    case permissionDenied(filename: String)
    case diskFull
    case ioError(filename: String, underlying: any Error & Sendable)
}

public enum LoadError: Error, Sendable {
    case reading(ReadingError)
    case decoding(DecodingError)
}

public enum PersistError: Error, Sendable {
    case encoding(EncodingError)
    case saving(SavingError)
}

public enum RenderError: Error, Sendable {
    case renderingFailed(String)
}

public enum ExportError: Error, Sendable {
    case noData
    case ioError(underlying: any Error & Sendable)
}
