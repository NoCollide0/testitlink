import Foundation
import SwiftUI
import Combine
import CryptoKit

class ImageService: ImageServiceProtocol {
    private let urlSession: URLSession
    private let imageCache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        setupCache()
    }
    
    private func setupCache() {
        imageCache.countLimit = 100
        thumbnailCache.countLimit = 200
        
        createCacheDirectories()
    }
    
    private func createCacheDirectories() {
        let cacheDirectory = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let imageDirectory = cacheDirectory?.appendingPathComponent("images")
        let thumbnailDirectory = cacheDirectory?.appendingPathComponent("thumbnails")
        
        try? fileManager.createDirectory(at: imageDirectory!, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailDirectory!, withIntermediateDirectories: true)
    }
    
    func loadImage(from urlString: String) -> AnyPublisher<UIImage?, Error> {
        let cacheKey = NSString(string: urlString)
        
        //Проверяем кэш в памяти
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return Just(cachedImage)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        //Проверяем кэш на диске
        if let diskCachedImage = loadImageFromDisk(with: urlString) {
            imageCache.setObject(diskCachedImage, forKey: cacheKey)
            return Just(diskCachedImage)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        //Загружаем из сети
        guard let url = URL(string: urlString) else {
            return Fail(error: NSError(domain: "Invalid URL", code: -1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        
        return urlSession.dataTaskPublisher(for: url)
            .tryMap { [weak self] data, response -> UIImage? in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "Invalid response", code: -2, userInfo: nil)
                }
                
                guard let image = UIImage(data: data) else {
                    throw NSError(domain: "Invalid image data", code: -3, userInfo: nil)
                }
                
                //Сохраняем в кэше
                self?.imageCache.setObject(image, forKey: cacheKey)
                self?.saveImageToDisk(image, with: urlString)
                
                return image
            }
            .eraseToAnyPublisher()
    }
    
    func loadThumbnail(from urlString: String, size: CGSize) -> AnyPublisher<UIImage?, Error> {
        let thumbnailKey = NSString(string: "\(urlString)_\(Int(size.width))x\(Int(size.height))")
        
        //Проверяем кэш в памяти
        if let cachedThumbnail = thumbnailCache.object(forKey: thumbnailKey) {
            return Just(cachedThumbnail)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        //Проверяем кэш на диске
        if let diskCachedThumbnail = loadThumbnailFromDisk(with: urlString, size: size) {
            thumbnailCache.setObject(diskCachedThumbnail, forKey: thumbnailKey)
            return Just(diskCachedThumbnail)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        //Загружаем изображение и создаем миниатюру
        return loadImage(from: urlString)
            .compactMap { [weak self] image -> UIImage? in
                guard let image = image else { return nil }
                
                let thumbnail = self?.createThumbnail(from: image, size: size)
                
                if let thumbnail = thumbnail {
                    self?.thumbnailCache.setObject(thumbnail, forKey: thumbnailKey)
                    self?.saveThumbnailToDisk(thumbnail, with: urlString, size: size)
                }
                
                return thumbnail
            }
            .eraseToAnyPublisher()
    }
    
    private func createThumbnail(from image: UIImage, size: CGSize) -> UIImage {
        //Сохраняем пропорции оригинального изображения
        let originalSize = image.size
        var scaledSize = size
        
        let widthRatio = size.width / originalSize.width
        let heightRatio = size.height / originalSize.height
        let scale = max(widthRatio, heightRatio)
        
        scaledSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        if originalSize.width < size.width && originalSize.height < size.height {
            return image
        }
        
        //Создаем миниатюру
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        return renderer.image { context in
            let origin = CGPoint(
                x: (scaledSize.width - originalSize.width * scale) / 2,
                y: (scaledSize.height - originalSize.height * scale) / 2
            )
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
    
    private func saveImageToDisk(_ image: UIImage, with urlString: String) {
        guard let cacheDirectory = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return }
        
        let imageDirectory = cacheDirectory.appendingPathComponent("images")
        let fileURL = imageDirectory.appendingPathComponent(urlString.md5())
        
        guard let data = image.jpegData(compressionQuality: 1.0) else { return }
        
        try? data.write(to: fileURL)
    }
    
    private func saveThumbnailToDisk(_ thumbnail: UIImage, with urlString: String, size: CGSize) {
        guard let cacheDirectory = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return }
        
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails")
        let fileName = "\(urlString.md5())_\(Int(size.width))x\(Int(size.height))"
        let fileURL = thumbnailDirectory.appendingPathComponent(fileName)
        
        guard let data = thumbnail.jpegData(compressionQuality: 0.8) else { return }
        
        try? data.write(to: fileURL)
    }
    
    private func loadImageFromDisk(with urlString: String) -> UIImage? {
        guard let cacheDirectory = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return nil }
        
        let imageDirectory = cacheDirectory.appendingPathComponent("images")
        let fileURL = imageDirectory.appendingPathComponent(urlString.md5())
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    private func loadThumbnailFromDisk(with urlString: String, size: CGSize) -> UIImage? {
        guard let cacheDirectory = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return nil }
        
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails")
        let fileName = "\(urlString.md5())_\(Int(size.width))x\(Int(size.height))"
        let fileURL = thumbnailDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    func clearCache() {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        
        guard let cacheDirectory = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return }
        
        let imageDirectory = cacheDirectory.appendingPathComponent("images")
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails")
        
        try? fileManager.removeItem(at: imageDirectory)
        try? fileManager.removeItem(at: thumbnailDirectory)
        
        createCacheDirectories()
    }
}

extension String {
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

protocol ImageServiceProtocol {
    func loadImage(from urlString: String) -> AnyPublisher<UIImage?, Error>
    func loadThumbnail(from urlString: String, size: CGSize) -> AnyPublisher<UIImage?, Error>
    func clearCache()
} 