import Foundation
import Combine
import SwiftUI

class ImageDetailPresenter: ImageDetailPresenterProtocol {
    @Published var currentImageIndex: Int
    @Published var isNavBarVisible: Bool = true
    @Published var scale: CGFloat = 1.0
    @Published var lastScaleValue: CGFloat = 1.0
    
    private let imageService: ImageServiceProtocol
    
    let imageURLs: [ImageURL]
    
    private var subscriptions = Set<AnyCancellable>()
    
    init(imageURLs: [ImageURL], initialIndex: Int, imageService: ImageServiceProtocol = ImageService()) {
        self.imageURLs = imageURLs
        self.currentImageIndex = initialIndex
        self.imageService = imageService
    }
    
    func shareImage() {
        guard currentImageIndex >= 0 && currentImageIndex < imageURLs.count else { return }
    }
    
    func openInBrowser() {
        guard currentImageIndex >= 0 && currentImageIndex < imageURLs.count,
              let url = imageURLs[currentImageIndex].url else { return }
        
        UIApplication.shared.open(url)
    }
    
    func nextImage() {
        guard !imageURLs.isEmpty else { return }
        
        currentImageIndex = (currentImageIndex + 1) % imageURLs.count
        resetZoom()
    }
    
    func previousImage() {
        guard !imageURLs.isEmpty else { return }
        
        currentImageIndex = (currentImageIndex - 1 + imageURLs.count) % imageURLs.count
        resetZoom()
    }
    
    func toggleNavBar() {
        isNavBarVisible.toggle()
    }
    
    private func resetZoom() {
        scale = 1.0
        lastScaleValue = 1.0
    }
}

protocol ImageDetailPresenterProtocol: ObservableObject {
    var currentImageIndex: Int { get set }
    var imageURLs: [ImageURL] { get }
    var isNavBarVisible: Bool { get set }
    var scale: CGFloat { get set }
    var lastScaleValue: CGFloat { get set }
    
    func shareImage()
    func openInBrowser()
    func nextImage()
    func previousImage()
} 