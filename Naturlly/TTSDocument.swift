     import UIKit

     class TTSDocument: UIDocument {
         var text: String = ""
         var sections: [DocumentSection] = [] // Assuming DocumentSection is defined elsewhere
         var audioData: Data? // Optional, for synthesized audio
         
         override func contents(forType typeName: String) throws -> Any {
             // Serialize document data (e.g., to JSON)
             let data: [String: Any] = [
                 "text": text,
                 "sections": sections.map { ["title": $0.title, "startOffset": $0.startOffset, "endOffset": $0.endOffset] }, // Adjust based on your model
                 "audioData": audioData?.base64EncodedString() ?? ""
             ]
             return try JSONSerialization.data(withJSONObject: data, options: [])
         }
         
         override func load(fromContents contents: Any, ofType typeName: String?) throws {
             guard let data = contents as? Data else { throw NSError(domain: "TTS", code: 1, userInfo: nil) }
             let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
             self.text = json?["text"] as? String ?? ""
             // Load sections and audio similarly
             if let sectionsData = json?["sections"] as? [[String: Any]] {
                 self.sections = sectionsData.compactMap { dict in
                     if let title = dict["title"] as? String,
                        let startOffset = dict["startOffset"] as? Int,
                        let endOffset = dict["endOffset"] as? Int {
                         return DocumentSection(title: title, startOffset: startOffset, endOffset: endOffset)
                     }
                     return nil
                 }
             }
             if let audioString = json?["audioData"] as? String, !audioString.isEmpty {
                 self.audioData = Data(base64Encoded: audioString)
             }
         }
     }
