//
//  LibraryView.swift
//  Naturlly TTS
//
//  Vista mínima de biblioteca para listar, seleccionar y borrar documentos.
//

import SwiftUI

struct LibraryView: View {
    @Binding var documents: [Document]
    @Binding var selectedDocument: Document?
    @Binding var text: String
    @Binding var selectedSection: DocumentSection?
    @Binding var showSections: Bool

    @State private var showDeleteAlert = false
    @State private var docToDelete: Document?

    var body: some View {
        NavigationStack {
            List {
                if documents.isEmpty {
                    ContentUnavailableView(String(localized: "library.empty"), systemImage: "books.vertical", description: Text(String(localized: "library.empty_desc")))
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(documents) { doc in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: doc.type.icon)
                                    .foregroundColor(.blue)
                                Text(doc.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                Spacer()
                            }
                            Text(String(format: String(localized: "library.doc_stats"), doc.wordCount, doc.pageCount ?? 0))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDocument = doc
                            text = doc.text
                            if doc.hasSections { showSections = true }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                docToDelete = doc
                                showDeleteAlert = true
                            } label: {
                                Label(String(localized: "btn.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "library.nav_title"))
            .alert(String(localized: "library.delete_alert_title"), isPresented: $showDeleteAlert, presenting: docToDelete) { doc in
                Button(String(localized: "btn.delete"), role: .destructive) {
                    delete(doc)
                }
                Button(String(localized: "btn.cancel"), role: .cancel) {}
            } message: { doc in
                Text(String(format: String(localized: "library.delete_confirm"), doc.name))
            }
        }
    }

    private func delete(_ doc: Document) {
        if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
            documents.remove(at: idx)
        }
        if selectedDocument?.id == doc.id {
            selectedDocument = nil
            text = ""
            selectedSection = nil
            showSections = false
        }
        // Opcional: borrar archivo del sandbox
        try? FileManager.default.removeItem(at: doc.fileURL)
    }
}

#Preview {
    LibraryView(documents: .constant([]), selectedDocument: .constant(nil), text: .constant(""), selectedSection: .constant(nil), showSections: .constant(false))
}
