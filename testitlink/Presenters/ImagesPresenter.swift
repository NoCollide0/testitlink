import Foundation
import Combine
import SwiftUI

class ImagesPresenter: ImagesPresenterProtocol {
    @Published var imageURLs: [ImageURL] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private let networkService: NetworkServiceProtocol
    private let imageService: ImageServiceProtocol
    private let imagesFileURL = "https://it-link.ru/test/images.txt"
    
    private var subscriptions = Set<AnyCancellable>()
    
    init(networkService: NetworkServiceProtocol = NetworkService(),
         imageService: ImageServiceProtocol = ImageService()) {
        self.networkService = networkService
        self.imageService = imageService
        
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        NotificationCenter.default.publisher(for: .connectivityStatusChanged)
            .sink { [weak self] _ in
                let isConnected = NetworkMonitor.shared.isConnected
                if isConnected {
                    if self?.imageURLs.isEmpty ?? true || self?.error != nil {
                        self?.loadImagesFile()
                    }
                }
            }
            .store(in: &subscriptions)
    }
    
    func loadImagesFile() {
        guard !isLoading else { return }
        guard NetworkMonitor.shared.isConnected else {
            error = "Нет подключения к интернету. Пожалуйста, проверьте соединение."
            return
        }
        
        isLoading = true
        error = nil
        
        networkService.downloadFile(from: imagesFileURL)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = "Не удалось загрузить файл: \(err.localizedDescription)"
                }
            }, receiveValue: { [weak self] content in
                self?.parseImagesFile(content)
            })
            .store(in: &subscriptions)
    }
    
    func retryLoadImagesFile() {
        loadImagesFile()
    }
    
    private func parseImagesFile(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        let urls = lines.compactMap { line -> ImageURL? in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { return nil }
            
            let imageURL = ImageURL(urlString: trimmedLine)
            return imageURL.isValid ? imageURL : nil
        }
        
        imageURLs = urls
    }
    
    func refreshData() {
        imageURLs = []
        loadImagesFile()
    }
}

protocol ImagesPresenterProtocol: ObservableObject {
    var imageURLs: [ImageURL] { get }
    var isLoading: Bool { get }
    var error: String? { get }
    
    func loadImagesFile()
    func retryLoadImagesFile()
    func refreshData()
}

class ImageViewModel: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let imageService: ImageServiceProtocol
    private var cancellable: AnyCancellable?
    
    init(imageService: ImageServiceProtocol = ImageService()) {
        self.imageService = imageService
    }
    
    func loadImage(from urlString: String) {
        isLoading = true
        error = nil
        
        cancellable = imageService.loadImage(from: urlString)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = err
                }
            }, receiveValue: { [weak self] image in
                self?.image = image
            })
    }
    
    func loadThumbnail(from urlString: String, size: CGSize) {
        isLoading = true
        error = nil
        
        cancellable = imageService.loadThumbnail(from: urlString, size: size)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = err
                }
            }, receiveValue: { [weak self] image in
                self?.image = image
            })
    }
    
    func cancel() {
        cancellable?.cancel()
    }
} 
 