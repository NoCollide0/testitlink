import Foundation

struct ImageURL: Identifiable, Equatable, Hashable {
    let id = UUID()
    let urlString: String
    
    var url: URL? {
        URL(string: urlString)
    }
    
    var isValid: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    var isImageURL: Bool {
        guard isValid else { return false }
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "tiff", "bmp"]
        let fileExtension = urlString.components(separatedBy: ".").last?.lowercased() ?? ""
        return imageExtensions.contains(fileExtension) || urlString.contains("images")
    }
    
    static func == (lhs: ImageURL, rhs: ImageURL) -> Bool {
        lhs.urlString == rhs.urlString
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(urlString)
    }
} 