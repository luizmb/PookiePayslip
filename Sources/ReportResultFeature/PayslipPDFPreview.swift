import AppDomain
import PookieStyle
import SwiftUI

/// A full-screen preview of the rendered payslip PDF, shown before the user shares it.
/// Uses PDFKit's `PDFView` (an Apple system framework — no third-party dependency) so the
/// in-memory PDF `Data` can be displayed without writing a temp file to disk.
struct PayslipPDFPreview: View {
    let shareable: PDFShareable
    let title: String
    let shareLabel: String
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onClose)
                            .font(.pookie(15, weight: .semibold))
                            .foregroundStyle(Color.pookieAccent)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: shareable,
                            preview: SharePreview(shareLabel, icon: Image(systemName: "doc.fill"))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.pookie(15, weight: .semibold))
                                .foregroundStyle(Color.pookieAccent)
                        }
                    }
                }
        }
    }

    @ViewBuilder private var content: some View {
        #if canImport(PDFKit) && canImport(UIKit)
        PDFDocumentView(data: shareable.data)
            .background(Color.pookieBg)
            .ignoresSafeArea(edges: .bottom)
        #else
        // Platforms without PDFKit/UIKit can still share the file.
        ShareLink(
            item: shareable,
            preview: SharePreview(shareLabel, icon: Image(systemName: "doc.fill"))
        ) {
            Text("Share PDF").font(.pookie(15, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pookieBg)
        #endif
    }
}

#if canImport(PDFKit) && canImport(UIKit)
import PDFKit
import UIKit

/// Bridges PDFKit's `PDFView` into SwiftUI so the payslip `Data` can be previewed inline.
private struct PDFDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.backgroundColor = .clear
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
#endif
