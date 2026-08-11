//
//  DocumentPresentationView.swift
//  Naturlly TTS
//
//  Beautiful presentation view for documents with full index/table of contents
//

import SwiftUI

// Cleans text by removing URLs, page footers/headers, and excessive whitespace
fileprivate func cleanedText(from text: String) -> String {
    var result = text
    
    // Si el texto está vacío, devolver vacío
    guard !result.isEmpty else { return "" }

    // Normalize newlines
    result = result.replacingOccurrences(of: "\r\n", with: "\n")
    result = result.replacingOccurrences(of: "\r", with: "\n")
    
    // Remove soft hyphen
    result = result.replacingOccurrences(of: "\u{00AD}", with: "")

    // Remove URLs completas (http/https y www.)
    if let urlRegex = try? NSRegularExpression(pattern: "(https?://|www\\.)\\S+", options: [.caseInsensitive]) {
        result = urlRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "")
    }
    
    // Remove page markers (Página X, Page X, etc.) - más específico
    let pagePatterns = [
        "\\bP[aá]gina\\s+\\d+\\b",
        "\\bPage\\s+\\d+\\b",
        "\\bP[aá]g\\.?\\s+\\d+\\b"
    ]
    
    for pattern in pagePatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "")
        }
    }

    // Join hyphenated line breaks
    result = result.replacingOccurrences(of: "-\n", with: "")
    
    // Replace newlines with spaces for continuous reading
    result = result.replacingOccurrences(of: "\n", with: " ")

    // Collapse multiple spaces
    while result.contains("  ") {
        result = result.replacingOccurrences(of: "  ", with: " ")
    }

    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Main Document Presentation View
struct DocumentPresentationView: View {
    let document: Document
    @Binding var selectedText: String
    @Environment(\.dismiss) var dismiss
    var lastReadSectionIndex: Int? = nil
    var onSectionSelected: ((DocumentSection, Int) -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.1)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Document Header
                        DocumentHeaderView(document: document)
                        
                        // Table of Contents
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundColor(.blue)
                                Text(String(localized: "presentation.index"))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            if document.hasSections {
                                // Section List
                                LazyVStack(spacing: 8) {
                                    ForEach(document.sections.indices, id: \.self) { index in
                                        let section = document.sections[index]
                                        PresentationSectionRowView(
                                            section: section,
                                            sectionNumber: index + 1,
                                            document: document,
                                            isLastRead: lastReadSectionIndex == index
                                        )
                                        .onTapGesture {
                                            selectSection(section)
                                        }
                                    }
                                }
                            } else {
                                // No sections detected
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)
                                    
                                    Text(String(localized: "presentation.no_index"))
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(String(localized: "presentation.no_index_desc"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        selectedText = cleanedText(from: document.text)
                                        dismiss()
                                    }) {
                                        Label("Leer documento completo", systemImage: "book.fill")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.blue)
                                            .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                }
                                .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle(String(localized: "presentation.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedText = cleanedText(from: document.text)
                        dismiss()
                    }) {
                        Label("Todo", systemImage: "doc.text.fill")
                    }
                }
            }
            .tint(.cyan)
        }
    }
    
    // Helper to select a section and dismiss
    private func selectSection(_ section: DocumentSection) {
        let rawText = document.getSectionText(section)
        let cleaned = cleanedText(from: rawText)
        
        print("DEBUG - Section selected: \(section.title)")
        print("DEBUG - Raw text length: \(rawText.count)")
        print("DEBUG - Cleaned text length: \(cleaned.count)")
        print("DEBUG - First 100 chars: \(String(cleaned.prefix(100)))")
        
        selectedText = cleaned
        
        // Notificar la sección seleccionada para activar reproducción continua
        if let index = document.sections.firstIndex(where: { $0.id == section.id }) {
            onSectionSelected?(section, index)
        }
        
        dismiss()
    }
}

// MARK: - Document Header View
struct DocumentHeaderView: View {
    let document: Document
    
    var body: some View {
        VStack(spacing: 16) {
            // Document cover art
            DocumentCoverView(document: document, size: CGSize(width: 150, height: 180))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
            
            // Document Title
            Text(document.name)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Document Stats
            HStack(spacing: 24) {
                if let pageCount = document.pageCount {
                    StatBadge(icon: "doc.plaintext", value: "\(pageCount)", label: "páginas")
                }
                
                StatBadge(icon: "textformat.size", value: formatNumber(document.characterCount), label: "caracteres")
                
                if document.hasSections {
                    StatBadge(icon: "list.bullet", value: "\(document.sections.count)", label: "secciones")
                }
            }
            
            // Reading Time Estimate
            ReadingTimeView(characterCount: document.characterCount)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding()
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number > 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Reading Time View
struct ReadingTimeView: View {
    let characterCount: Int
    
    private var estimatedMinutes: Int {
        // Average reading speed: ~1000 characters per minute
        return characterCount / 1000
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .foregroundColor(.orange)
            
            if estimatedMinutes < 60 {
                Text(String(format: String(localized: "presentation.est_time_min"), estimatedMinutes))
            } else {
                let hours = estimatedMinutes / 60
                let minutes = estimatedMinutes % 60
                Text(String(format: String(localized: "presentation.est_time_hm"), hours, minutes))
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Presentation Document Section Row View
struct PresentationSectionRowView: View {
    let section: DocumentSection
    let sectionNumber: Int
    let document: Document
    var isLastRead: Bool = false
    
    var sectionText: String {
        document.getSectionText(section)
    }
    
    var cleanedSectionText: String { cleanedText(from: sectionText) }
    
    var characterCount: Int {
        cleanedSectionText.count
    }
    
    var estimatedMinutes: Int {
        characterCount / 1000
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Section Number Badge
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text("\(sectionNumber)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Section Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(section.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    if isLastRead {
                        Spacer()
                        Text(String(localized: "presentation.last_read"))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                
                HStack(spacing: 12) {
                    Label("\(formatCharacterCount(characterCount))", systemImage: "textformat.size")
                        .font(.caption)
                    
                    if estimatedMinutes > 0 {
                        Label("\(estimatedMinutes)m", systemImage: "clock")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Arrow Icon
            Image(systemName: "chevron.right")
                .foregroundColor(.blue)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
        .scaleEffect(1.0)
        
        .contentShape(Rectangle())
    }
    
    private func formatCharacterCount(_ count: Int) -> String {
        if count > 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - Section Reader View
struct SectionReaderView: View {
    let document: Document
    let section: DocumentSection
    let onSelectSection: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var sectionText: String {
        document.getSectionText(section)
    }
    
    var cleanedSectionText: String { cleanedText(from: sectionText) }
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Section Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Label("\(cleanedSectionText.count) caracteres", systemImage: "textformat.size")
                            
                            Spacer()
                            
                            let minutes = cleanedSectionText.count / 1000
                            Label("\(minutes) min", systemImage: "clock")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Section Text Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "presentation.preview"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(String(cleanedSectionText.prefix(500)) + (cleanedSectionText.count > 500 ? "..." : ""))
                            .font(.body)
                            .lineSpacing(6)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                    .cornerRadius(12)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            onSelectSection(cleanedSectionText)
                        }) {
                            HStack {
                                Image(systemName: "speaker.wave.3.fill")
                                Text(String(localized: "presentation.convert_audio"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        Button(action: {
                            onSelectSection(cleanedSectionText)
                        }) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                Text(String(localized: "presentation.full_text"))
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
        }
        .navigationTitle(String(localized: "presentation.section_nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Volver") {
                    dismiss()
                }
            }
        }
    }
}
