import SwiftUI

struct ThumbnailView: View {
    let imageURL: ImageURL
    let size: CGSize
    
    @StateObject private var viewModel = ImageViewModel()
    @State private var isLoading = false
    @State private var loadError: Error? = nil
    
    var body: some View {
        ZStack {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.width)
                    .clipped()
                    .cornerRadius(8)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(width: size.width, height: size.width)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            } else if viewModel.error != nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                    Text("Ошибка")
                        .font(.caption)
                    Button("Повторить") {
                        loadThumbnail()
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
                .frame(width: size.width, height: size.width)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size.width, height: size.width)
                    .cornerRadius(8)
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }
    
    private func loadThumbnail() {
        guard let urlString = imageURL.url?.absoluteString else { return }
        viewModel.loadThumbnail(from: urlString, size: size)
    }
} 