import Foundation
import Combine

class NetworkService: NetworkServiceProtocol {
    private let urlSession: URLSession
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    func downloadFile(from urlString: String) -> AnyPublisher<String, Error> {
        guard let url = URL(string: urlString) else {
            return Fail(error: NSError(domain: "Invalid URL", code: -1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        
        return urlSession.dataTaskPublisher(for: url)
            .tryMap { data, response -> String in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "Invalid response", code: -2, userInfo: nil)
                }
                
                guard let content = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "Invalid data encoding", code: -3, userInfo: nil)
                }
                
                return content
            }
            .eraseToAnyPublisher()
    }
}

//Мониторинг сетевого подключения
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected = false
    private(set) var connectionType: ConnectionType = .unknown
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            self?.getConnectionType(path)
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .connectivityStatusChanged,
                    object: nil
                )
            }
        }
        monitor.start(queue: queue)
    }
    
    func getConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
}

extension Notification.Name {
    static let connectivityStatusChanged = Notification.Name("connectivityStatusChanged")
}

protocol NetworkServiceProtocol {
    func downloadFile(from urlString: String) -> AnyPublisher<String, Error>
} 
