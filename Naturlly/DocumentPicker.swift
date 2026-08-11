//
//  DocumentPicker.swift
//  Naturlly TTS
//
//  SwiftUI wrapper for UIDocumentPickerViewController
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var documents: [Document]
    @Binding var isPresented: Bool
    @Binding var errorMessage: String?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = {
            var t = [UTType.pdf]
            if let epub = UTType(filenameExtension: "epub") {
                t.append(epub)
            }
            return t
        }()
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: types,
            asCopy: true
        )
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                // Start accessing security-scoped resource if needed (iOS may not require it for copies)
                let needsAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if needsAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                do {
                    let document: Document
                    
                    // Determine file type and extract text
                    if url.pathExtension.lowercased() == "pdf" {
                        document = try PDFDocumentReader.createDocumentWithSections(from: url)
                    } else if url.pathExtension.lowercased() == "epub" {
                        document = try EPUBReader.createDocumentWithSections(from: url)
                    } else {
                        parent.errorMessage = "Tipo de archivo no soportado: \(url.pathExtension)"
                        continue
                    }
                    
                    // Add to documents list
                    DispatchQueue.main.async {
                        self.parent.documents.append(document)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        self.parent.errorMessage = "Error al procesar \(url.lastPathComponent): \(error.localizedDescription)"
                    }
                }
            }
            
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}
