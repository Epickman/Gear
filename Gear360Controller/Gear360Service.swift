import Foundation

actor Gear360Service {
    static let shared = Gear360Service()

    private let baseURL = "http://192.168.43.1"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 10
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    // MARK: - Info y Estado

    func fetchInfo() async throws -> CameraInfo {
        let (data, _) = try await session.data(for: post("/osc/info"))
        return try decode(data)
    }

    func fetchState() async throws -> CameraStateResponse {
        let (data, _) = try await session.data(for: post("/osc/state"))
        return try decode(data)
    }

    // MARK: - Comandos estándar OSC

    func takePicture() async throws -> OSCCommandResponse {
        try await execute(.init(name: "camera.takePicture", parameters: nil))
    }

    func startCapture() async throws -> OSCCommandResponse {
        try await execute(.init(name: "camera.startCapture", parameters: nil))
    }

    func stopCapture() async throws -> OSCCommandResponse {
        try await execute(.init(name: "camera.stopCapture", parameters: nil))
    }

    // MARK: - Modo de lente (Samsung Gear 360 2016 — propietario)
    //
    // Descubierto via PCAP del tráfico de la app oficial:
    // usa camera.setOptions con la key _shootMode (underscore = extensión Samsung).
    // Valores confirmados: "Dual" | "Front" | "Rear"

    func setLensMode(_ mode: LensMode) async throws -> OSCCommandResponse {
        let command = OSCCommandRequest(
            name: "camera.setOptions",
            parameters: [
                "options": .object(["_shootMode": .string(mode.rawValue)])
            ]
        )
        return try await execute(command)
    }

    // MARK: - Request para el preview en vivo

    /// Construye el URLRequest del stream MJPEG.
    /// Pasar a LivePreviewManager — NO usar la session estándar (timeout = 0).
    func makeLivePreviewRequest() throws -> URLRequest {
        let cmd = OSCCommandRequest(name: "camera.getLivePreview", parameters: nil)
        let body = try JSONEncoder().encode(cmd)
        return post("/osc/commands/execute", body: body, timeout: 0)
    }

    // MARK: - Privado

    private func execute(_ command: OSCCommandRequest) async throws -> OSCCommandResponse {
        let body = try JSONEncoder().encode(command)
        let (data, response) = try await session.data(for: post("/osc/commands/execute", body: body))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CameraError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let result: OSCCommandResponse = try decode(data)
        if let err = result.error { throw CameraError.oscError(err) }
        return result
    }

    private func post(_ path: String, body: Data? = nil, timeout: TimeInterval = 10) -> URLRequest {
        var r = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = body
        r.timeoutInterval = timeout
        return r
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Errores

enum CameraError: LocalizedError {
    case httpError(Int)
    case oscError(OSCError)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "HTTP \(code)"
        case .oscError(let err):   return "\(err.code): \(err.message)"
        case .notConnected:        return "Conectate a la red Wi-Fi de la Gear 360 primero"
        }
    }
}
