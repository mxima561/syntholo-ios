import Foundation

enum CurriculumSchema {
    static let currentVersion = 1
}

enum CurriculumIdentifierError: Error, Equatable, Hashable, Sendable {
    case invalidStableID
    case invalidLocale
    case invalidLocaleToken
    case invalidVersion
    case invalidProgramPointerID
    case invalidVersionID
    case invalidCatalogVersionID
    case invalidDigest
}

struct CurriculumStableID: Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) throws {
        guard CurriculumIdentifierValidation.isStableID(rawValue) else {
            throw CurriculumIdentifierError.invalidStableID
        }
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a canonical curriculum stable ID."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CurriculumLocale: Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    var token: CurriculumLocaleToken {
        CurriculumLocaleToken(
            validated: rawValue.lowercased(),
            localeRawValue: rawValue
        )
    }

    init(_ rawValue: String) throws {
        let canonical = try CurriculumIdentifierValidation.canonicalLocale(rawValue)
        guard canonical == rawValue else {
            throw CurriculumIdentifierError.invalidLocale
        }
        self.rawValue = canonical
    }

    init(requesting rawValue: String) throws {
        self.rawValue = try CurriculumIdentifierValidation.canonicalLocale(rawValue)
    }

    fileprivate init(validated rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a canonical BCP 47 curriculum locale."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CurriculumLocaleToken: Codable, Equatable, Hashable, Sendable {
    let rawValue: String
    private let localeRawValue: String

    var locale: CurriculumLocale {
        CurriculumLocale(validated: localeRawValue)
    }

    init(_ rawValue: String) throws {
        let locale: CurriculumLocale
        do {
            locale = try CurriculumLocale(requesting: rawValue)
        } catch {
            throw CurriculumIdentifierError.invalidLocaleToken
        }
        guard locale.token.rawValue == rawValue else {
            throw CurriculumIdentifierError.invalidLocaleToken
        }
        self.rawValue = rawValue
        localeRawValue = locale.rawValue
    }

    fileprivate init(validated rawValue: String, localeRawValue: String) {
        self.rawValue = rawValue
        self.localeRawValue = localeRawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a canonical lowercase curriculum locale token."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CurriculumVersion: Codable, Equatable, Hashable, Sendable {
    static let maximum = 2_147_483_647

    let rawValue: Int

    init(_ rawValue: Int) throws {
        guard (1...Self.maximum).contains(rawValue) else {
            throw CurriculumIdentifierError.invalidVersion
        }
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a positive curriculum version within schema-v1 bounds."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CurriculumProgramPointerID: Codable, Equatable, Hashable, Sendable {
    let rawValue: String
    let stableIDToken: String
    let locale: CurriculumLocale

    init(stableID: CurriculumStableID, locale: CurriculumLocale) {
        stableIDToken = stableID.rawValue
        self.locale = locale
        rawValue = "\(stableID.rawValue)--\(locale.token.rawValue)"
    }

    init(_ rawValue: String) throws {
        guard rawValue.utf8.count <= 101 else {
            throw CurriculumIdentifierError.invalidProgramPointerID
        }
        let components = rawValue.components(separatedBy: "--")
        guard components.count == 2 else {
            throw CurriculumIdentifierError.invalidProgramPointerID
        }
        do {
            guard CurriculumIdentifierValidation.isKebabToken(components[0]) else {
                throw CurriculumIdentifierError.invalidProgramPointerID
            }
            let localeToken = try CurriculumLocaleToken(components[1])
            stableIDToken = components[0]
            locale = localeToken.locale
            self.rawValue = rawValue
        } catch {
            throw CurriculumIdentifierError.invalidProgramPointerID
        }
        guard self.rawValue == "\(stableIDToken)--\(locale.token.rawValue)" else {
            throw CurriculumIdentifierError.invalidProgramPointerID
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a derived curriculum program pointer ID."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CurriculumVersionID: Codable, Equatable, Hashable, Sendable {
    let rawValue: String
    let stableIDToken: String
    let locale: CurriculumLocale
    let version: CurriculumVersion

    init(
        stableID: CurriculumStableID,
        locale: CurriculumLocale,
        version: CurriculumVersion
    ) {
        stableIDToken = stableID.rawValue
        self.locale = locale
        self.version = version
        rawValue = "\(stableID.rawValue)--\(locale.token.rawValue)--v\(version.rawValue)"
    }

    init(_ rawValue: String) throws {
        guard rawValue.utf8.count <= 114 else {
            throw CurriculumIdentifierError.invalidVersionID
        }
        let components = rawValue.components(separatedBy: "--")
        guard components.count == 3,
              components[2].first == "v" else {
            throw CurriculumIdentifierError.invalidVersionID
        }
        let versionText = String(components[2].dropFirst())
        guard CurriculumIdentifierValidation.isCanonicalVersionText(versionText),
              let integer = Int(versionText) else {
            throw CurriculumIdentifierError.invalidVersionID
        }
        do {
            guard CurriculumIdentifierValidation.isKebabToken(components[0]) else {
                throw CurriculumIdentifierError.invalidVersionID
            }
            let localeToken = try CurriculumLocaleToken(components[1])
            let version = try CurriculumVersion(integer)
            stableIDToken = components[0]
            locale = localeToken.locale
            self.version = version
            self.rawValue = rawValue
        } catch {
            throw CurriculumIdentifierError.invalidVersionID
        }
        let expected =
            "\(stableIDToken)--\(locale.token.rawValue)--v\(version.rawValue)"
        guard self.rawValue == expected else {
            throw CurriculumIdentifierError.invalidVersionID
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a derived curriculum version ID."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CurriculumCatalogVersionID: Codable, Equatable, Hashable, Sendable {
    let rawValue: String
    let locale: CurriculumLocale
    let version: CurriculumVersion

    init(locale: CurriculumLocale, version: CurriculumVersion) {
        self.locale = locale
        self.version = version
        rawValue = "catalog--\(locale.token.rawValue)--v\(version.rawValue)"
    }

    init(_ rawValue: String) throws {
        guard rawValue.utf8.count <= 114 else {
            throw CurriculumIdentifierError.invalidCatalogVersionID
        }
        let components = rawValue.components(separatedBy: "--")
        guard components.count == 3,
              components[0] == "catalog",
              components[2].first == "v" else {
            throw CurriculumIdentifierError.invalidCatalogVersionID
        }
        let versionText = String(components[2].dropFirst())
        guard CurriculumIdentifierValidation.isCanonicalVersionText(versionText),
              let integer = Int(versionText) else {
            throw CurriculumIdentifierError.invalidCatalogVersionID
        }
        do {
            let localeToken = try CurriculumLocaleToken(components[1])
            let version = try CurriculumVersion(integer)
            self.init(locale: localeToken.locale, version: version)
        } catch {
            throw CurriculumIdentifierError.invalidCatalogVersionID
        }
        guard self.rawValue == rawValue else {
            throw CurriculumIdentifierError.invalidCatalogVersionID
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a derived curriculum catalog version ID."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CurriculumDigest: Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) throws {
        guard rawValue.utf8.count == 64,
              rawValue.utf8.allSatisfy(CurriculumIdentifierValidation.isLowerHex) else {
            throw CurriculumIdentifierError.invalidDigest
        }
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a lowercase SHA-256 curriculum digest."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

private enum CurriculumIdentifierValidation {
    static func isStableID(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        return (3...64).contains(bytes.count) && isKebabToken(value)
    }

    static func isKebabToken(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard !bytes.isEmpty,
              bytes.first != CharacterByte.hyphen,
              bytes.last != CharacterByte.hyphen else {
            return false
        }

        var previousWasHyphen = false
        for byte in bytes {
            if byte == CharacterByte.hyphen {
                guard !previousWasHyphen else { return false }
                previousWasHyphen = true
            } else {
                guard isLowerASCIIAlpha(byte) || isASCIIDigit(byte) else {
                    return false
                }
                previousWasHyphen = false
            }
        }
        return true
    }

    static func canonicalLocale(_ value: String) throws -> String {
        guard !value.isEmpty,
              value.utf8.count <= 35,
              !value.contains("_"),
              value.unicodeScalars.allSatisfy({ $0.isASCII }) else {
            throw CurriculumIdentifierError.invalidLocale
        }

        let subtags = value.split(separator: "-", omittingEmptySubsequences: false)
            .map(String.init)
        guard !subtags.isEmpty,
              subtags.allSatisfy({ !$0.isEmpty && isASCIIAlphanumeric($0) }) else {
            throw CurriculumIdentifierError.invalidLocale
        }

        if subtags[0].lowercased() == "x" {
            guard subtags.count > 1,
                  subtags.dropFirst().allSatisfy({
                      (1...8).contains($0.utf8.count)
                  }) else {
                throw CurriculumIdentifierError.invalidLocale
            }
            return subtags.map { $0.lowercased() }.joined(separator: "-")
        }

        guard (2...8).contains(subtags[0].utf8.count),
              isASCIIAlpha(subtags[0]) else {
            throw CurriculumIdentifierError.invalidLocale
        }

        var result = [subtags[0].lowercased()]
        var index = 1

        if subtags[0].utf8.count <= 3 {
            var extlangCount = 0
            while index < subtags.count,
                  extlangCount < 3,
                  subtags[index].utf8.count == 3,
                  isASCIIAlpha(subtags[index]) {
                result.append(subtags[index].lowercased())
                index += 1
                extlangCount += 1
            }
        }

        if index < subtags.count,
           subtags[index].utf8.count == 4,
           isASCIIAlpha(subtags[index]) {
            let lowercased = subtags[index].lowercased()
            result.append(lowercased.prefix(1).uppercased() + lowercased.dropFirst())
            index += 1
        }

        if index < subtags.count {
            let candidate = subtags[index]
            if candidate.utf8.count == 2, isASCIIAlpha(candidate) {
                result.append(candidate.uppercased())
                index += 1
            } else if candidate.utf8.count == 3, isASCIIDigits(candidate) {
                result.append(candidate)
                index += 1
            }
        }

        var variants = Set<String>()
        while index < subtags.count, isVariant(subtags[index]) {
            let variant = subtags[index].lowercased()
            guard variants.insert(variant).inserted else {
                throw CurriculumIdentifierError.invalidLocale
            }
            result.append(variant)
            index += 1
        }

        var extensionSingletons = Set<String>()
        while index < subtags.count,
              subtags[index].utf8.count == 1,
              subtags[index].lowercased() != "x" {
            let singleton = subtags[index].lowercased()
            guard !extensionSingletons.contains(singleton) else {
                throw CurriculumIdentifierError.invalidLocale
            }
            extensionSingletons.insert(singleton)
            result.append(singleton)
            index += 1

            let extensionStart = index
            while index < subtags.count,
                  (2...8).contains(subtags[index].utf8.count) {
                result.append(subtags[index].lowercased())
                index += 1
            }
            guard index > extensionStart else {
                throw CurriculumIdentifierError.invalidLocale
            }
        }

        if index < subtags.count, subtags[index].lowercased() == "x" {
            result.append("x")
            index += 1
            let privateUseStart = index
            while index < subtags.count,
                  (1...8).contains(subtags[index].utf8.count) {
                result.append(subtags[index].lowercased())
                index += 1
            }
            guard index > privateUseStart else {
                throw CurriculumIdentifierError.invalidLocale
            }
        }

        guard index == subtags.count else {
            throw CurriculumIdentifierError.invalidLocale
        }

        let canonical = result.joined(separator: "-")
        guard canonical.utf8.count <= 35 else {
            throw CurriculumIdentifierError.invalidLocale
        }
        return canonical
    }

    static func isCanonicalVersionText(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.utf8.count <= 10,
              value.utf8.allSatisfy(isASCIIDigit),
              value.first != "0" else {
            return false
        }
        return true
    }

    static func isLowerHex(_ byte: UInt8) -> Bool {
        isASCIIDigit(byte) || (CharacterByte.lowercaseA...CharacterByte.lowercaseF).contains(byte)
    }

    private static func isVariant(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        return (5...8).contains(bytes.count) ||
            (bytes.count == 4 && bytes.first.map(isASCIIDigit) == true)
    }

    private static func isASCIIAlphanumeric(_ value: String) -> Bool {
        value.utf8.allSatisfy { byte in
            isASCIIAlpha(byte) || isASCIIDigit(byte)
        }
    }

    private static func isASCIIAlpha(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy(isASCIIAlpha)
    }

    private static func isASCIIDigits(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy(isASCIIDigit)
    }

    private static func isASCIIAlpha(_ byte: UInt8) -> Bool {
        isLowerASCIIAlpha(byte) ||
            (CharacterByte.uppercaseA...CharacterByte.uppercaseZ).contains(byte)
    }

    private static func isLowerASCIIAlpha(_ byte: UInt8) -> Bool {
        (CharacterByte.lowercaseA...CharacterByte.lowercaseZ).contains(byte)
    }

    private static func isASCIIDigit(_ byte: UInt8) -> Bool {
        (CharacterByte.zero...CharacterByte.nine).contains(byte)
    }

    private enum CharacterByte {
        static let hyphen = UInt8(ascii: "-")
        static let zero = UInt8(ascii: "0")
        static let nine = UInt8(ascii: "9")
        static let lowercaseA = UInt8(ascii: "a")
        static let lowercaseF = UInt8(ascii: "f")
        static let lowercaseZ = UInt8(ascii: "z")
        static let uppercaseA = UInt8(ascii: "A")
        static let uppercaseZ = UInt8(ascii: "Z")
    }
}
