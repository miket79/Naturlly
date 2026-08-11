//
//  Document.swift
//  Naturlly TTS
//
//  Model for imported documents (PDF/EPUB) with sections
//

import Foundation

struct DocumentSection: Identifiable, Codable, Hashable, Equatable {
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

struct Document: Identifiable, Codable, Equatable {
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
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, fileURLString, text, pageCount, createdAt, sections
    }
    
    init(id: UUID = UUID(), name: String, type: DocumentType, fileURL: URL, text: String, pageCount: Int?, createdAt: Date, sections: [DocumentSection]) {
        self.id = id
        self.name = name
        self.type = type
        self.fileURL = fileURL
        self.text = text
        self.pageCount = pageCount
        self.createdAt = createdAt
        self.sections = sections
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(DocumentType.self, forKey: .type)
        let fileURLString = try container.decode(String.self, forKey: .fileURLString)
        fileURL = URL(fileURLWithPath: fileURLString)
        text = try container.decode(String.self, forKey: .text)
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sections = try container.decode([DocumentSection].self, forKey: .sections)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(fileURL.path, forKey: .fileURLString)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(pageCount, forKey: .pageCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(sections, forKey: .sections)
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

extension Document {
    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }
}
