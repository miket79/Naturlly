//
//  DocumentSectionsView.swift
//  Naturlly TTS
//
//  Selector mínimo de secciones de un documento.
//

import SwiftUI

struct DocumentSectionsMinimalView: View {
    let document: Document
    @Binding var selectedSection: DocumentSection?
    @Binding var text: String
    var onSectionSelected: (_ section: DocumentSection?, _ index: Int?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "sections.full_doc_section")) {
                    Button {
                        selectedSection = nil
                        text = document.text
                        onSectionSelected(nil, nil)
                    } label: {
                        HStack {
                            Image(systemName: "doc.richtext")
                            Text(String(localized: "sections.read_all"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(String(localized: "sections.sections_header")) {
                    ForEach(Array(document.sections.enumerated()), id: \.offset) { (index, section) in
                        Button {
                            selectedSection = section
                            text = document.getSectionText(section)
                            onSectionSelected(section, index)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text(String(format: String(localized: "sections.char_count"), section.characterCount))
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
    return DocumentSectionsMinimalView(document: doc, selectedSection: .constant(nil), text: .constant("")) { _, _ in }
}

