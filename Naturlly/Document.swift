//
//  Document.swift
//  Naturlly TTS
//
//  Model for imported documents (PDF/EPUB) with sections
//

import Foundation

struct DocumentSection: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let startOffset: Int
    let endOffset: Int
    
    init(id: UUID = UUID(), title: String, startOffset: Int, endOffset: Int) {
        self.id = id
        self.title = title
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
    
    var characterCount: Int {
        endOffset - startOffset
    }
}

struct Document: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: DocumentType
    let fileURL: URL
    let text: String
    let pageCount: Int?
    let createdAt: Date
    var sections: [DocumentSection]
    
    enum DocumentType: String, Codable {
        case pdf = "PDF"
        case epub = "EPUB"
        
        var icon: String {
            switch self {
            case .pdf: return "doc.fill"
            case .epub: return "book.fill"
            }
        }
    }
    
    var characterCount: Int {
        text.count
    }
    
    var wordCount: Int {
        text.split(separator: " ").count
    }
    
    var preview: String {
        String(text.prefix(200)) + (text.count > 200 ? "..." : "")
    }
    
    var hasSections: Bool {
        !sections.isEmpty
    }
    
    func getSectionText(_ section: DocumentSection) -> String {
        let startIndex = text.index(text.startIndex, offsetBy: section.startOffset, limitedBy: text.endIndex) ?? text.startIndex
        let endIndex = text.index(text.startIndex, offsetBy: section.endOffset, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[startIndex..<endIndex])
    }
}

enum DocumentPersistence {
    private static let fileName = "NaturllyDocuments.json"

    private static var storageURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent(fileName)
    }

    static func saveDocuments(_ documents: [Document]) throws {
        let directory = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(documents)
        try data.write(to: storageURL, options: .atomic)
    }

    static func loadDocuments() throws -> [Document] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        return try JSONDecoder().decode([Document].self, from: data)
    }
}
