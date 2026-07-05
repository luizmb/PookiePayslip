import Foundation
import UniformTypeIdentifiers

#if canImport(CoreTransferable)
import CoreTransferable

/// A type-safe zip wrapper for `ShareLink`. Carries `.zip` UTType so the system shows the correct
/// icon and AirDrop/Files receive it as a `.zip` archive (a full backup of the app's data files).
public struct ZipShareable: Transferable, Sendable, Equatable {
    public let data: Data
    public let filename: String

    public init(data: Data, filename: String = "PookiePayslip-backup.zip") {
        self.data = data
        self.filename = filename
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .zip) { $0.data }
            .suggestedFileName { $0.filename }
    }
}
#endif
