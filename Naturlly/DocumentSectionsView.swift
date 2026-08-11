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
    var onSectionSelected: ((DocumentSection?, Int?) -> Void)? = nil
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
                            onSectionSelected?(nil, nil)
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
                                onSectionSelected?(section, index)
                                dismiss()
                            }) {
                                EnhancedSectionRowView(section: section, index: index + 1)
                            }
                            .foregroundColor(.primary)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "text.book.closed.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Secciones (\(document.sections.count))")
                        }
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

// MARK: - Enhanced Section Row View
struct EnhancedSectionRowView: View {
    let section: DocumentSection
    let index: Int
    
    private var estimatedMinutes: Int {
        max(1, section.characterCount / 750)
    }
    
    private var formattedCharCount: String {
        if section.characterCount > 1000 {
            return String(format: "%.1fK", Double(section.characterCount) / 1000.0)
        }
        return "\(section.characterCount)"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Number Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Text("\(index)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
            }
            
            // Section Info
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                        Text(formattedCharCount)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("\(estimatedMinutes)m")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
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
    
    DocumentSectionsView(
        document: sampleDoc,
        selectedSection: .constant(nil),
        text: .constant("")
    )
}
