//
//  PDFDocumentReader.swift
//  Naturlly TTS
//
//  Service to extract text from PDF files
//

import Foundation
import PDFKit

class PDFDocumentReader {
    
    private static func normalizeLineBreaks(_ input: String) -> String {
        var text = input.replacingOccurrences(of: "\r\n", with: "\n")
                        .replacingOccurrences(of: "\r", with: "\n")

        // 1) Unir palabras cortadas por guión al final de línea: "ejem-\nplo" -> "ejemplo"
        text = text.replacingOccurrences(of: "-\n", with: "")

        // 2) Preservar dobles saltos (párrafos) con un marcador temporal
        let paragraphToken = "⟦PARA⟧"
        text = text.replacingOccurrences(of: "\n\n", with: paragraphToken)

        // 3) Colapsar saltos múltiples a doble (por si vienen 3+)
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        text = text.replacingOccurrences(of: "\n\n", with: paragraphToken)

        // 4) Reemplazar los saltos de línea simples (fin de renglón) por espacio
        text = text.replacingOccurrences(of: "\n", with: " ")

        // 5) Restaurar los párrafos como dobles saltos
        text = text.replacingOccurrences(of: paragraphToken, with: "\n\n")

        // 6) Limpiar espacios extra
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    enum PDFError: LocalizedError {
        case invalidPDF
        case noText
        case readError
        
        var errorDescription: String? {
            switch self {
            case .invalidPDF:
                return "El archivo PDF no es válido"
            case .noText:
                return "No se pudo extraer texto del PDF"
            case .readError:
                return "Error al leer el archivo PDF"
            }
        }
    }
    
    // Ensure the selected file is copied into our sandbox for reliable access on device
    private static func ensureLocalCopy(of url: URL) throws -> URL {
        let fm = FileManager.default
        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let importsDir = docsDir.appendingPathComponent("Imports", isDirectory: true)
        if !fm.fileExists(atPath: importsDir.path) {
            try fm.createDirectory(at: importsDir, withIntermediateDirectories: true)
        }
        let destURL = importsDir.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")
        // Copy the file into our sandbox (unique name avoids collisions)
        try fm.copyItem(at: url, to: destURL)
        return destURL
    }
    
    static func extractText(from url: URL) throws -> (text: String, pageCount: Int) {
        // Load PDF document
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFError.invalidPDF
        }
        
        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw PDFError.noText
        }
        
        var fullText = ""
        
        // Extract text from each page
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            guard let pageTextRaw = page.string else {
                continue
            }
            
            let pageText = normalizeLineBreaks(pageTextRaw)
            fullText += pageText + "\n\n"
        }
        
        // Remove excessive whitespace
        fullText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fallback: try the document-wide string if per-page extraction yielded nothing
        if fullText.isEmpty, let docString = pdfDocument.string {
            let normalized = normalizeLineBreaks(docString)
            if !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fullText = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        guard !fullText.isEmpty else {
            throw PDFError.noText
        }
        
        return (fullText, pageCount)
    }
    

    static func extractTextWithPages(from url: URL) throws -> (text: String, pages: [String], pageCount: Int) {
        // Load PDF document
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PDFError.invalidPDF
        }
        
        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw PDFError.noText
        }
        
        var fullText = ""
        var pages: [String] = []
        
        // Extract text from each page individually
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            guard let pageTextRaw = page.string else {
                continue
            }
            
            let cleanPageText = normalizeLineBreaks(pageTextRaw)
            if !cleanPageText.isEmpty {
                pages.append(cleanPageText)
                fullText += cleanPageText + "\n\n"
            }
        }
        
        // Remove excessive whitespace from full text
        fullText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fallback: if no per-page text, try the document-wide string
        if fullText.isEmpty, pages.isEmpty, let docString = pdfDocument.string {
            let normalized = normalizeLineBreaks(docString)
            let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                fullText = trimmed
                pages = [trimmed]
            }
        }
        
        guard !fullText.isEmpty else {
            throw PDFError.noText
        }
        
        return (fullText, pages, pageCount)
    }
    
    static func generateSectionsFromPages(pages: [String], fullText: String) -> [DocumentSection] {
        var sections: [DocumentSection] = []
        var currentOffset = 0
        
        for (index, pageText) in pages.enumerated() {
            let pageNumber = index + 1
            let textLength = pageText.count
            let endOffset = currentOffset + textLength
            
            // Get preview text (first 50 characters)
            let previewLength = min(50, pageText.count)
            let preview = String(pageText.prefix(previewLength))
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let title = "Página \(pageNumber): \(preview)..."
            
            let section = DocumentSection(
                title: title,
                startOffset: currentOffset,
                endOffset: endOffset
            )
            
            sections.append(section)
            
            // Add 2 for the "\n\n" separator between pages
            currentOffset = endOffset + 2
        }
        
        return sections
    }

    static func createDocument(from url: URL) throws -> Document {
        let localURL = try ensureLocalCopy(of: url)
        let (text, pageCount) = try extractText(from: localURL)
        
        return Document(
            id: UUID(),
            name: url.lastPathComponent,
            type: .pdf,
            fileURL: localURL,
            text: text,
            pageCount: pageCount,
            createdAt: Date(),
            sections: []
        )
    }
    
    // Generate sections from PDF text
    static func generateSections(from text: String, pageCount: Int) -> [DocumentSection] {
        var sections: [DocumentSection] = []
        let maxSectionSize = 5000
        
        var currentOffset = 0
        var sectionNumber = 1
        
        while currentOffset < text.count {
            let remainingText = text.count - currentOffset
            let sectionSize = min(maxSectionSize, remainingText)
            
            // Try to find a good break point (end of sentence)
            var endOffset = currentOffset + sectionSize
            if endOffset < text.count {
                let searchStart = max(currentOffset, endOffset - 200)
                let searchText = String(text.dropFirst(searchStart).prefix(endOffset - searchStart))
                
                if let lastPeriod = searchText.lastIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) {
                    endOffset = searchStart + searchText.distance(from: searchText.startIndex, to: lastPeriod) + 1
                }
            }
            
            let sectionText = String(text.dropFirst(currentOffset).prefix(endOffset - currentOffset))
            let preview = sectionText.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines)
            
            sections.append(DocumentSection(
                title: "Sección \(sectionNumber): \(preview)...",
                startOffset: currentOffset,
                endOffset: endOffset
            ))
            
            currentOffset = endOffset
            sectionNumber += 1
        }
        
        return sections
    }
}

// Update createDocument to include sections
extension PDFDocumentReader {
    static func createDocumentWithSections(from url: URL) throws -> Document {
        let localURL = try ensureLocalCopy(of: url)
        let (text, pages, pageCount) = try extractTextWithPages(from: localURL)
        let sections = generateSectionsFromPages(pages: pages, fullText: text)
        
        return Document(
            id: UUID(),
            name: url.lastPathComponent,
            type: .pdf,
            fileURL: localURL,
            text: text,
            pageCount: pageCount,
            createdAt: Date(),
            sections: sections
        )
    }
}

