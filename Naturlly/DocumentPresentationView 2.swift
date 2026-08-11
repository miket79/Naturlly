//
//  DocumentPresentationView.swift
//  Naturlly TTS
//
//  Vista para presentar un documento con secciones, pensada para modo lectura.
//

import SwiftUI

struct DocumentSectionsListView: View {
    let document: Document
    @Binding var selectedText: String
    var lastReadSectionIndex: Int?
    var onSectionSelected: (_ section: DocumentSection, _ index: Int) -> Void

    var body: some View {
        List {
            if let idx = lastReadSectionIndex, idx < document.sections.count {
                Section {
                    Button {
                        let section = document.sections[idx]
                        onSectionSelected(section, idx)
                    } label: {
                        Label("Continuar en sección \(idx + 1)", systemImage: "play.circle.fill")
                    }
                }
            }

            Section("Secciones") {
                ForEach(Array(document.sections.enumerated()), id: \.offset) { (index, section) in
                    Button {
                        onSectionSelected(section, index)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text("\(section.characterCount) caracteres")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let doc = Document(
        id: UUID(),
        name: "Demo.pdf",
        type: .pdf,
        fileURL: URL(fileURLWithPath: "/tmp/demo.pdf"),
        text: "Texto de prueba",
        pageCount: 10,
        createdAt: Date(),
        sections: [DocumentSection(title: "Sección 1", startOffset: 0, endOffset: 12)]
    )
    return DocumentSectionsListView(document: doc, selectedText: .constant(""), lastReadSectionIndex: 0) { _, _ in }
}
