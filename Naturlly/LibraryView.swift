import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                Text("Biblioteca")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Aquí verás tus documentos importados en próximas versiones.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryView()
}
