import Foundation
import Network
import Combine


final class ConnectivityService: ObservableObject {
    static let shared = ConnectivityService()

    @Published private(set) var isOnline: Bool = true

    private let transitionSubject = PassthroughSubject<Bool, Never>()
    var onTransition: AnyPublisher<Bool, Never> {
        transitionSubject.eraseToAnyPublisher()
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityService")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let nowOnline = path.status == .satisfied
            DispatchQueue.main.async {
                let changed = self.isOnline != nowOnline
                self.isOnline = nowOnline
                if changed {
                    #if DEBUG
                    print("[Connectivity] transition → \(nowOnline ? "online" : "offline")")
                    #endif
                    self.transitionSubject.send(nowOnline)
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
