import Foundation

// MARK: - JSONValue: valor JSON flexible para parámetros OSC

enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil()                                   { self = .null;     return }
        if let v = try? c.decode(Bool.self)                { self = .bool(v);  return }
        if let v = try? c.decode(Int.self)                 { self = .int(v);   return }
        if let v = try? c.decode(Double.self)              { self = .double(v);return }
        if let v = try? c.decode(String.self)              { self = .string(v);return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v);return }
        if let v = try? c.decode([JSONValue].self)         { self = .array(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Tipo JSON no soportado")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v):  try c.encode(v)
        case .null:          try c.encodeNil()
        }
    }

    var stringValue: String? {
        guard case .string(let v) = self else { return nil }
        return v
    }
}

// MARK: - Camera Info (/osc/info)

struct CameraInfo: Decodable {
    let manufacturer: String
    let model: String
    let serialNumber: String
    let firmwareVersion: String
    let supportedApis: [String]

    enum CodingKeys: String, CodingKey {
        case manufacturer, model, serialNumber, firmwareVersion
        case supportedApis = "api"
    }
}

// MARK: - Estado de la cámara (/osc/state)

struct CameraStateResponse: Decodable {
    let fingerprint: String
    let state: Payload

    struct Payload: Decodable {
        let batteryLevel: Double?
        let storageUri: String?
        let captureStatus: String?
        let recordableTime: Int?
        let capturedPictures: Int?
    }
}

// MARK: - Comando OSC

struct OSCCommandRequest: Encodable {
    let name: String
    let parameters: [String: JSONValue]?
}

struct OSCCommandResponse: Decodable {
    let name: String
    let state: CommandState
    let id: String?
    let results: [String: JSONValue]?
    let error: OSCError?

    enum CommandState: String, Decodable {
        case done, inProgress, error
    }
}

struct OSCError: Decodable {
    let code: String
    let message: String
}

// MARK: - Modo de lente (Samsung-específico)

enum LensMode: String, CaseIterable, Identifiable {
    case dual  = "Dual"
    case front = "Front"
    case rear  = "Rear"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dual:  return "360° Dual"
        case .front: return "Front Only"
        case .rear:  return "Rear Only"
        }
    }
}
