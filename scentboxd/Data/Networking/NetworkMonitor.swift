//
//  NetworkMonitor.swift
//  scentboxd
//

import Foundation
import Network
import Combine

@Observable
@MainActor
class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool = true {
        didSet { connectionSubject.send(isConnected) }
    }

    /// Combine subject for subscribers that need reactive pipelines.
    let connectionSubject = PassthroughSubject<Bool, Never>()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "de.scentboxd.NetworkMonitor")
    
    private init() {
        let monitor = self.monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
