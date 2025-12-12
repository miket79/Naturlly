//
//  EPUBReader.swift
//  Naturlly TTS
//
//  Service to extract text from EPUB files
//

import Foundation

class EPUBReader {
    
    enum EPUBError: LocalizedError {
        case invalidEPUB
        case noText
        case readError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidEPUB:
                return "El archivo EPUB no es válido"
            case .noText:
                return "No se pudo extraer texto del EPUB"
            case .readError(let message):
                return "Error al leer EPUB: \(message)"
            }
        }
    }
    
    // Ensure the selected EPUB is copied into our sandbox for reliable access on device
    private static func ensureLocalCopy(of url: URL) throws -> URL {
        let fm = FileManager.default
        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let importsDir = docsDir.appendingPathComponent("Imports", isDirectory: true)
        if !fm.fileExists(atPath: importsDir.path) {
            try fm.createDirectory(at: importsDir, withIntermediateDirectories: true)
        }
        let destURL = importsDir.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")
        try fm.copyItem(at: url, to: destURL)
        return destURL
    }
    
    static func extractText(from url: URL) throws -> String {
        // Create temporary directory for extraction
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            #if os(macOS)
            // Use unzip command on macOS
            let process = Foundation.Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", url.path, "-d", tempDir.path]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    // Successfully extracted, now read HTML files
                    let text = try readExtractedEPUB(from: tempDir)
                    try? fileManager.removeItem(at: tempDir)
                    return text
                }
            } catch {
                // If running unzip fails, fall through to manual reading below
            }
            #endif
            
            // Fallback for non-macOS platforms or if unzip failed
            let text = try readEPUBManually(from: url)
            try? fileManager.removeItem(at: tempDir)
            return text
            
        } catch let error as EPUBError {
            throw error
        } catch {
            throw EPUBError.readError(error.localizedDescription)
        }
    }
    
    // Read already extracted EPUB
    private static func readExtractedEPUB(from directory: URL) throws -> String {
        let fileManager = FileManager.default
        var fullText = ""
        
        // Find all HTML/XHTML files
        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                let fileName = fileURL.lastPathComponent.lowercased()
                
                if (fileName.hasSuffix(".html") || fileName.hasSuffix(".xhtml") || fileName.hasSuffix(".htm")) &&
                   !fileName.contains("nav.") && !fileName.contains("toc.") {
                    
                    if let htmlString = try? String(contentsOf: fileURL, encoding: .utf8) {
                        let cleanText = stripHTMLTags(from: htmlString)
                        if !cleanText.isEmpty {
                            fullText += cleanText + "\n\n"
                        }
                    }
                }
            }
        }
        
        fullText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !fullText.isEmpty else {
            throw EPUBError.noText
        }
        
        return fullText
    }
    
    // Fallback: Read ZIP manually (simplified version)
    private static func readEPUBManually(from url: URL) throws -> String {
        // EPUB is a ZIP file, we can try to read it as data
        let data = try Data(contentsOf: url)
        
        // Simple approach: convert to string and extract text between tags
        // This is a fallback and may not work perfectly
        if let content = String(data: data, encoding: .utf8) {
            return stripHTMLTags(from: content)
        }
        
        throw EPUBError.noText
    }
    

    
    // Extract text with chapter information
    static func extractTextWithChapters(from url: URL) throws -> (text: String, chapters: [(title: String, text: String)]) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            #if os(macOS)
            let process = Foundation.Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", url.path, "-d", tempDir.path]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    let result = try readExtractedEPUBWithChapters(from: tempDir)
                    try? fileManager.removeItem(at: tempDir)
                    return result
                }
            } catch {
                // Fallback if unzip fails
            }
            #endif
            
            // Fallback: extract full text only
            let text = try readEPUBManually(from: url)
            try? fileManager.removeItem(at: tempDir)
            return (text, [])
            
        } catch let error as EPUBError {
            throw error
        } catch {
            throw EPUBError.readError(error.localizedDescription)
        }
    }
    
    private static func readExtractedEPUBWithChapters(from directory: URL) throws -> (text: String, chapters: [(title: String, text: String)]) {
        let fileManager = FileManager.default
        var chapters: [(title: String, text: String)] = []
        var fullText = ""
        
        // Find all HTML/XHTML files and sort them
        var htmlFiles: [(url: URL, name: String)] = []
        
        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                let fileName = fileURL.lastPathComponent.lowercased()
                
                if (fileName.hasSuffix(".html") || fileName.hasSuffix(".xhtml") || fileName.hasSuffix(".htm")) &&
                    !fileName.contains("nav.") && !fileName.contains("toc.") {
                    htmlFiles.append((url: fileURL, name: fileName))
                }
            }
        }
        
        // Sort files by name to maintain reading order
        htmlFiles.sort { $0.name < $1.name }
        
        // Extract text from each chapter
        for (index, fileInfo) in htmlFiles.enumerated() {
            if let htmlString = try? String(contentsOf: fileInfo.url, encoding: .utf8) {
                let cleanText = stripHTMLTags(from: htmlString)
                
                if !cleanText.isEmpty {
                    // Get chapter title from first line or filename
                    let lines = cleanText.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
                    let firstLine = lines.first.map(String.init) ?? ""
                    let previewLength = min(50, firstLine.count)
                    let preview = String(firstLine.prefix(previewLength))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let chapterTitle = preview.isEmpty ? "Capítulo \(index + 1)" : "Cap. \(index + 1): \(preview)..."
                    
                    chapters.append((title: chapterTitle, text: cleanText))
                    fullText += cleanText + "\n\n"
                }
            }
        }
        
        fullText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !fullText.isEmpty else {
            throw EPUBError.noText
        }
        
        return (fullText, chapters)
    }
    
    static func generateSectionsFromChapters(chapters: [(title: String, text: String)], fullText: String) -> [DocumentSection] {
        var sections: [DocumentSection] = []
        var currentOffset = 0
        
        for chapter in chapters {
            let textLength = chapter.text.count
            let endOffset = currentOffset + textLength
            
            let section = DocumentSection(
                title: chapter.title,
                startOffset: currentOffset,
                endOffset: endOffset
            )
            
            sections.append(section)
            
            // Add 2 for the "\n\n" separator between chapters
            currentOffset = endOffset + 2
        }
        
        return sections
    }
    static func createDocument(from url: URL) throws -> Document {
        let localURL = try ensureLocalCopy(of: url)
        let text = try extractText(from: localURL)
        
        return Document(
            id: UUID(),
            name: url.lastPathComponent,
            type: .epub,
            fileURL: localURL,
            text: text,
            pageCount: nil, // EPUB doesn't have fixed pages
            createdAt: Date(),
            sections: []
        )
    }
    
    // Helper function to strip HTML tags
    private static func stripHTMLTags(from html: String) -> String {
        var result = html
        
        // Remove script and style tags with their content
        result = result.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        
        // Remove HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode HTML entities
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        
        // Clean up whitespace
        result = result.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n[ \\t]+", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "[ \\t]+\n", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func createDocumentWithSections(from url: URL) throws -> Document {
        let localURL = try ensureLocalCopy(of: url)
        let (text, chapters) = try extractTextWithChapters(from: localURL)
        
        // Use chapter-based sections if available, otherwise fall back to text-based
        let sections: [DocumentSection]
        if !chapters.isEmpty {
            sections = generateSectionsFromChapters(chapters: chapters, fullText: text)
        } else {
            sections = generateSections(from: text)
        }
        
        return Document(
            id: UUID(),
            name: url.lastPathComponent,
            type: .epub,
            fileURL: localURL,
            text: text,
            pageCount: nil,
            createdAt: Date(),
            sections: sections
        )
    }
    
    private static func generateSections(from text: String) -> [DocumentSection] {
        return PDFDocumentReader.generateSections(from: text, pageCount: 0)
    }
}

