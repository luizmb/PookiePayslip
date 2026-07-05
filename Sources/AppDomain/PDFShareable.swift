import Foundation
import UniformTypeIdentifiers

#if canImport(CoreTransferable)
import CoreTransferable

/// A type-safe PDF wrapper for `ShareLink`. Carries `.pdf` UTType so the system
/// shows the correct icon and AirDrop/Files receive it as a `.pdf` file.
public struct PDFShareable: Transferable, Sendable, Equatable {
    public let data: Data
    public let filename: String

    public init(data: Data, filename: String = "payslip.pdf") {
        self.data = data
        self.filename = filename
    }

    // Shares a real `.pdf` file on disk rather than raw `Data`. `DataRepresentation`
    // fails to propagate the UTType to several share targets (AirDrop, Files, Mail),
    // which then treat the payload as generic binary; a file with a `.pdf` extension is
    // identified correctly everywhere. The temp file is written lazily, only when the
    // system actually resolves a share destination.
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { shareable in
            let url = URL.temporaryDirectory.appending(path: shareable.filename)
            try shareable.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        .suggestedFileName { $0.filename }
    }
}
#endif
