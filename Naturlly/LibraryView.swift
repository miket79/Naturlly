import SwiftUI

struct DocumentLibraryView: View {
    @Binding var documents: [Document]
    @Binding var selectedDocument: Document?
    @Binding var text: String
    @Binding var selectedSection: DocumentSection?
    @Binding var showSections: Bool
    
    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No hay documentos")
                            .font(.headline)
                        Text("Importa un PDF o EPUB desde la pestaña TTS.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(documents) { doc in
                            Button {
                                select(doc)
                            } label: {
                                DocumentRow(doc: doc)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(doc)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(doc)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                if doc.hasSections {
                                    Button {
                                        selectedDocument = doc
                                        selectedSection = nil
                                        showSections = true
                                    } label: {
                                        Label("Ver secciones", systemImage: "list.bullet.rectangle")
                                    }
                                }
                            }
                        }
                        .onDelete(perform: delete(at:))
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Biblioteca")
        }
    }
    
    private func select(_ doc: Document) {
        selectedDocument = doc
        selectedSection = nil
        text = doc.text
    }
    
    private func delete(_ doc: Document) {
        if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
            documents.remove(at: idx)
            if selectedDocument?.id == doc.id {
                selectedDocument = nil
                selectedSection = nil
                text = ""
            }
        }
    }
    
    private func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            let doc = documents[index]
            delete(doc)
        }
    }
}

private struct DocumentRow: View {
    let doc: Document
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: doc.type.icon)
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(doc.wordCount) palabras")
                    if let pages = doc.pageCount {
                        Text("• \(pages) páginas")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            if doc.hasSections {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    DocumentLibraryView(
        documents: .constant([
            Document(
                id: UUID(),
                name: "Ejemplo.pdf",
                type: .pdf,
                fileURL: URL(fileURLWithPath: "/tmp/example.pdf"),
                text: "Contenido de ejemplo",
                pageCount: 12,
                createdAt: Date(),
                sections: []
            ),
            Document(
                id: UUID(),
                name: "Libro.epub",
                type: .epub,
                fileURL: URL(fileURLWithPath: "/tmp/book.epub"),
                text: String(repeating: "Texto ", count: 500),
                pageCount: 320,
                createdAt: Date(),
                sections: [
                    DocumentSection(title: "Capítulo 1", startOffset: 0, endOffset: 100)
                ]
            )
        ]),
        selectedDocument: .constant(nil),
        text: .constant(""),
        selectedSection: .constant(nil),
        showSections: .constant(false)
    )
}

