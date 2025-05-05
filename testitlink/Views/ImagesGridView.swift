import SwiftUI

struct ImagesGridView: View {
    @StateObject private var presenter = ImagesPresenter()
    @State private var selectedImageIndex: Int? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                if presenter.isLoading && presenter.imageURLs.isEmpty {
                    ProgressView("Загрузка...")
                } else if let error = presenter.error {
                    VStack(spacing: 16) {
                        Text("Ошибка")
                            .font(.title)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Повторить") {
                            presenter.retryLoadImagesFile()
                        }
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else if presenter.imageURLs.isEmpty {
                    Text("Нет доступных изображений")
                        .font(.title)
                } else {
                    AdaptiveGrid(
                        items: presenter.imageURLs.indices.map { ImageWithIndex(id: presenter.imageURLs[$0].id, index: $0) },
                        spacing: 8, 
                        cellWidth: 120 
                    ) { item in
                        ThumbnailView(
                            imageURL: presenter.imageURLs[item.index], 
                            size: CGSize(width: 120, height: 120)
                        )
                        .onTapGesture {
                            selectedImageIndex = item.index
                        }
                    }
                    .background(
                        NavigationLink(
                            destination: ImageDetailView(
                                presenter: ImageDetailPresenter(
                                    imageURLs: presenter.imageURLs,
                                    initialIndex: selectedImageIndex ?? 0
                                )
                            ),
                            isActive: Binding(
                                get: { selectedImageIndex != nil },
                                set: { if !$0 { selectedImageIndex = nil } }
                            )
                        ) {
                            EmptyView()
                        }
                        .hidden()
                    )
                }
            }
            .navigationTitle("Галерея")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presenter.refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(presenter.isLoading)
                }
            }
            .refreshable {
                await refreshData()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            presenter.loadImagesFile()
        }
    }
    
    private func refreshData() async {
        await withCheckedContinuation { continuation in
            presenter.refreshData()
            continuation.resume()
        }
    }
}

struct ImageWithIndex: Identifiable {
    let id: UUID
    let index: Int
} 