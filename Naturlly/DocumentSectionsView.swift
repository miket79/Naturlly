//
//  DocumentSectionsView.swift
//  Naturlly TTS
//
//  View to display and navigate document sections/index
//

import SwiftUI

struct DocumentSectionsView: View {
    let document: Document
    @Binding var selectedSection: DocumentSection?
    @Binding var text: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if document.sections.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        Text("No hay secciones disponibles")
                            .font(.headline)
                        Text("Este documento no tiene un índice definido")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    Section {
                        Button(action: {
                            selectedSection = nil
                            text = document.text
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text("Documento completo")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(document.characterCount) caracteres")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    } header: {
                        Text("Todo el documento")
                    }
                    
                    Section {
                        ForEach(Array(document.sections.enumerated()), id: \.element.id) { index, section in
                            Button(action: {
                                selectedSection = section
                                text = document.getSectionText(section)
                                dismiss()
                            }) {
                                SectionRowView(section: section, index: index + 1)
                            }
                            .foregroundColor(.primary)
                        }
                    } header: {
                        Text("Secciones (\(document.sections.count))")
                    }
                }
            }
            .navigationTitle("Índice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SectionRowView: View {
    let section: DocumentSection
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(index).")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.bold)
                    .frame(width: 30, alignment: .leading)
                
                Text(section.title)
                    .font(.subheadline)
                    .lineLimit(2)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Label("\(section.characterCount)", systemImage: "textformat.size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let minutes = max(1, section.characterCount / 750) // ~150 palabras/min, 5 chars/palabra
                Label("~\(minutes) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let sampleSections = [
        DocumentSection(title: "Introducción", startOffset: 0, endOffset: 1000),
        DocumentSection(title: "Capítulo 1: El Comienzo", startOffset: 1000, endOffset: 5000),
        DocumentSection(title: "Capítulo 2: Desarrollo", startOffset: 5000, endOffset: 10000)
    ]
    
    let sampleDoc = Document(
        id: UUID(),
        name: "Ejemplo.pdf",
        type: .pdf,
        fileURL: URL(fileURLWithPath: "/tmp/test.pdf"),
        text: String(repeating: "Sample text ", count: 1000),
        pageCount: 10,
        createdAt: Date(),
        sections: sampleSections
    )
    
    return DocumentSectionsView(
        document: sampleDoc,
        selectedSection: .constant(nil),
        text: .constant("")
    )
}
