import CryptoKit
import Foundation

enum CurriculumCanonicalJSONError: Error, Equatable, Sendable {
    case invalidString
    case nonObjectContentDocument
    case unsupportedJSONValue
}

indirect enum CanonicalJSONValue: Codable, Equatable, Hashable, Sendable {
    case null
    case boolean(Bool)
    case integer(Int)
    case string(String)
    case array([CanonicalJSONValue])
    case object([String: CanonicalJSONValue])

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(
            keyedBy: CanonicalJSONCodingKey.self
        ) {
            var values: [String: CanonicalJSONValue] = [:]
            values.reserveCapacity(container.allKeys.count)
            for key in container.allKeys {
                values[key.stringValue] = try container.decode(
                    CanonicalJSONValue.self,
                    forKey: key
                )
            }
            self = .object(values)
            return
        }

        if var container = try? decoder.unkeyedContainer() {
            var values: [CanonicalJSONValue] = []
            values.reserveCapacity(container.count ?? 0)
            while !container.isAtEnd {
                values.append(try container.decode(CanonicalJSONValue.self))
            }
            self = .array(values)
            return
        }

        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Only integer JSON values are supported."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .boolean(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .integer(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case let .object(values):
            var container = encoder.container(
                keyedBy: CanonicalJSONCodingKey.self
            )
            for (key, value) in values {
                try container.encode(
                    value,
                    forKey: CanonicalJSONCodingKey(stringValue: key)
                )
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .null:
            hasher.combine(0)
        case let .boolean(value):
            hasher.combine(1)
            hasher.combine(value)
        case let .integer(value):
            hasher.combine(2)
            hasher.combine(value)
        case let .string(value):
            hasher.combine(3)
            hasher.combine(value)
        case let .array(values):
            hasher.combine(4)
            hasher.combine(values)
        case let .object(values):
            hasher.combine(5)
            for key in values.keys.sorted(by: Self.utf16Precedes) {
                hasher.combine(key)
                hasher.combine(values[key])
            }
        }
    }

    private static func utf16Precedes(_ left: String, _ right: String) -> Bool {
        left.utf16.lexicographicallyPrecedes(right.utf16)
    }
}

enum CurriculumCanonicalJSON {
    static func canonicalString(_ value: CanonicalJSONValue) throws -> String {
        var result = ""
        try append(value, to: &result)
        return result
    }

    static func canonicalBytes(_ value: CanonicalJSONValue) throws -> Data {
        Data(try canonicalString(value).utf8)
    }

    static func canonicalBytes<Value: Encodable>(
        _ value: Value
    ) throws -> Data {
        try canonicalBytes(canonicalValue(value))
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func contentDigest<Value: Encodable>(
        _ document: Value
    ) throws -> CurriculumDigest {
        try digest(
            contentDocumentValue(
                document,
                removing: ["contentDigest", "publishedAt"]
            )
        )
    }

    static func contentDocumentBytes<Value: Encodable>(
        _ document: Value
    ) throws -> Data {
        try canonicalBytes(
            contentDocumentValue(document, removing: ["publishedAt"])
        )
    }

    static func payloadDigest<Value: Encodable>(
        _ payload: Value
    ) throws -> CurriculumDigest {
        try digest(canonicalValue(payload))
    }

    private static func canonicalValue<Value: Encodable>(
        _ value: Value
    ) throws -> CanonicalJSONValue {
        let encoded = try JSONEncoder().encode(value)
        var preflight = StrictCurriculumJSONPreflight(data: encoded)
        try preflight.validate()
        return try JSONDecoder().decode(CanonicalJSONValue.self, from: encoded)
    }

    private static func contentDocumentValue<Value: Encodable>(
        _ document: Value,
        removing keys: Set<String>
    ) throws -> CanonicalJSONValue {
        let value = try canonicalValue(document)
        guard case var .object(properties) = value else {
            throw CurriculumCanonicalJSONError.nonObjectContentDocument
        }
        for key in keys {
            properties.removeValue(forKey: key)
        }
        return .object(properties)
    }

    private static func digest(
        _ value: CanonicalJSONValue
    ) throws -> CurriculumDigest {
        try CurriculumDigest(sha256Hex(canonicalBytes(value)))
    }

    private static func append(
        _ value: CanonicalJSONValue,
        to result: inout String
    ) throws {
        switch value {
        case .null:
            result.append("null")
        case let .boolean(value):
            result.append(value ? "true" : "false")
        case let .integer(value):
            result.append(String(value))
        case let .string(value):
            try appendEscaped(value, to: &result)
        case let .array(values):
            result.append("[")
            for (index, element) in values.enumerated() {
                if index > 0 {
                    result.append(",")
                }
                try append(element, to: &result)
            }
            result.append("]")
        case let .object(properties):
            result.append("{")
            let keys = properties.keys.sorted(by: utf16Precedes)
            for (index, key) in keys.enumerated() {
                if index > 0 {
                    result.append(",")
                }
                try appendEscaped(key, to: &result)
                result.append(":")
                guard let property = properties[key] else {
                    throw CurriculumCanonicalJSONError.unsupportedJSONValue
                }
                try append(property, to: &result)
            }
            result.append("}")
        }
    }

    private static func appendEscaped(
        _ value: String,
        to result: inout String
    ) throws {
        try validate(value)
        result.append("\"")
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x08:
                result.append("\\b")
            case 0x09:
                result.append("\\t")
            case 0x0A:
                result.append("\\n")
            case 0x0C:
                result.append("\\f")
            case 0x0D:
                result.append("\\r")
            case 0x22:
                result.append("\\\"")
            case 0x5C:
                result.append("\\\\")
            case 0x00 ... 0x1F:
                result.append("\\u")
                let hexadecimal = String(scalar.value, radix: 16)
                result.append(String(repeating: "0", count: 4 - hexadecimal.count))
                result.append(hexadecimal)
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        result.append("\"")
    }

    private static func validate(_ value: String) throws {
        let normalized = value.precomposedStringWithCanonicalMapping
        guard value.utf8.elementsEqual(normalized.utf8) else {
            throw CurriculumCanonicalJSONError.invalidString
        }
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x00 ... 0x08,
                    0x0B,
                    0x0C,
                    0x0E ... 0x1F,
                    0x7F:
                throw CurriculumCanonicalJSONError.invalidString
            default:
                continue
            }
        }
    }

    private static func utf16Precedes(_ left: String, _ right: String) -> Bool {
        left.utf16.lexicographicallyPrecedes(right.utf16)
    }
}

private struct CanonicalJSONCodingKey: CodingKey, Hashable {
    let stringValue: String

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int? {
        nil
    }

    init?(intValue: Int) {
        nil
    }
}
