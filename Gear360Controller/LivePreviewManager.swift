import Foundation
import UIKit
import Combine

/// Conecta al endpoint MJPEG de la cámara y publica frames como UIImage.
///
/// delegateQueue: .main garantiza que todos los callbacks del delegate
/// corran en el main thread, haciendo seguras las mutaciones de @Published
/// sin DispatchQueue.main.async adicional.
final class LivePreviewManager: NSObject, ObservableObject {

    @Published var currentFrame: UIImage?
    @Published var isStreaming = false

    private var streamSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private var buffer = Data()
    private var isStopping = false

    // MARK: - Control

    /// Llamar desde el main thread (ej: .task en SwiftUI).
    func start(using service: Gear360Service) {
        guard !isStreaming else { return }
        isStreaming = true
        isStopping  = false
        buffer.removeAll()

        Task { @MainActor in
            do {
                let request = try await service.makeLivePreviewRequest()

                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest  = 0
                config.timeoutIntervalForResource = 0

                streamSession = URLSession(
                    configuration: config,
                    delegate: self,
                    delegateQueue: .main        // callbacks en main thread
                )
                dataTask = streamSession?.dataTask(with: request)
                dataTask?.resume()
            } catch {
                isStreaming = false
            }
        }
    }

    func stop() {
        isStopping = true
        dataTask?.cancel()
        dataTask = nil
        streamSession?.invalidateAndCancel()
        streamSession = nil
        buffer.removeAll()
        isStreaming = false
    }

    // MARK: - Parser MJPEG

    private func parseFrames() {
        let soi = Data([0xFF, 0xD8])   // JPEG Start of Image
        let eoi = Data([0xFF, 0xD9])   // JPEG End of Image

        while true {
            guard let start = buffer.range(of: soi) else { break }
            guard let end   = buffer.range(of: eoi, in: start.upperBound..<buffer.endIndex) else { break }

            let frameData = Data(buffer[start.lowerBound..<end.upperBound])

            if let image = UIImage(data: frameData) {
                currentFrame = image   // directo, ya estamos en main thread
            }

            buffer = Data(buffer[end.upperBound...])
        }

        // Evitar crecimiento ilimitado si llegan datos sin EOI
        if buffer.count > 500_000 { buffer.removeAll() }
    }
}

// MARK: - URLSessionDataDelegate

extension LivePreviewManager: URLSessionDataDelegate {

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        // Corre en main thread (delegateQueue: .main)
        buffer.append(data)
        parseFrames()
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard !isStopping else { return }
        isStreaming = false
    }
}
