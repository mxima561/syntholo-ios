#if DEBUG
import Foundation

enum DebugCurriculumFixture: String, CaseIterable, Sendable {
    case fresh
    case saved
    case savedToFresh = "saved-to-fresh"
    case offlineNoCache = "offline-no-cache"
    case incompatibleWithFallback = "incompatible-with-fallback"
    case incompatibleWithoutFallback = "incompatible-without-fallback"
    case empty
    case malformed
    case failOnceRetry = "fail-once-retry"
    case loading

    var launchArgument: String {
        "--curriculum-fixture=\(rawValue)"
    }
}

enum DebugCurriculumFixtureSelectionError: Error, Equatable {
    case unknown(String)
    case multiple([String])
}

enum DebugCurriculumFixtures {
    static func selection(
        arguments: [String]
    ) throws -> DebugCurriculumFixture {
        let prefix = "--curriculum-fixture="
        let selectors = arguments.filter {
            $0.hasPrefix("--curriculum-fixture")
        }
        guard selectors.count <= 1 else {
            throw DebugCurriculumFixtureSelectionError.multiple(selectors)
        }
        guard let selector = selectors.first else {
            return .fresh
        }
        guard selector.hasPrefix(prefix),
              let fixture = DebugCurriculumFixture(
                  rawValue: String(selector.dropFirst(prefix.count))
              ) else {
            throw DebugCurriculumFixtureSelectionError.unknown(selector)
        }
        return fixture
    }

    static func repository(arguments: [String]) -> any CurriculumRepository {
        do {
            return try repository(
                fixture: selection(arguments: arguments),
                transitionDelayNanoseconds: 6_000_000_000
            )
        } catch {
            preconditionFailure(
                "Invalid DEBUG curriculum fixture contract: \(error)"
            )
        }
    }

    static func repository(
        fixture: DebugCurriculumFixture,
        transitionDelayNanoseconds: UInt64
    ) throws -> any CurriculumRepository {
        let snapshot = try snapshot()
        let requiredSchema = CurriculumSchema.currentVersion + 1

        switch fixture {
        case .fresh:
            return DebugEventSequenceCurriculumRepository(
                locale: snapshot.locale,
                events: [.fresh(snapshot)],
                transitionDelayNanoseconds: transitionDelayNanoseconds
            )
        case .saved:
            return DebugEventSequenceCurriculumRepository(
                locale: snapshot.locale,
                events: [
                    .saved(snapshot),
                    .unavailable(
                        error: .networkUnavailable,
                        saved: snapshot
                    ),
                ],
                transitionDelayNanoseconds: 0
            )
        case .savedToFresh:
            return DebugEventSequenceCurriculumRepository(
                locale: snapshot.locale,
                events: [.saved(snapshot), .fresh(snapshot)],
                transitionDelayNanoseconds: transitionDelayNanoseconds
            )
        case .offlineNoCache:
            return DebugEventSequenceCurriculumRepository(
                locale: snapshot.locale,
                events: [
                    .unavailable(
                        error: .networkUnavailable,
                        saved: nil
                    ),
                ],
                transitionDelayNanoseconds: 0
            )
        case .incompatibleWithFallback:
            return DebugEventSequenceCurriculumRepository(
                locale: snapshot.locale,
                events: [
                    .updateRequired(
                        requiredSchema: requiredSchema,
                        saved: snapshot
                    ),
                ],
                transitionDelayNanoseconds: 0
            )
        case .incompatibleWithoutFallback:
            return DebugEventSequenceCurriculumRepository(
                locale: snapshot.locale,
                events: [
                    .updateRequired(
                        requiredSchema: requiredSchema,
                        saved: nil
                    ),
                ],
                transitionDelayNanoseconds: 0
            )
        case .empty:
            return DebugEventSequenceCurriculumRepository(
                locale: snapshot.locale,
                events: [.empty],
                transitionDelayNanoseconds: 0
            )
        case .malformed:
            return DebugEventSequenceCurriculumRepository(
                locale: snapshot.locale,
                events: [
                    .unavailable(
                        error: .malformedDocument(
                            path: "debug-fixture/catalog"
                        ),
                        saved: nil
                    ),
                ],
                transitionDelayNanoseconds: 0
            )
        case .failOnceRetry:
            return DebugFailOnceCurriculumRepository(snapshot: snapshot)
        case .loading:
            return DebugLoadingCurriculumRepository()
        }
    }

    static func snapshot() throws -> CurriculumSnapshot {
        guard let data = Data(
            base64Encoded: encodedSnapshot,
            options: [.ignoreUnknownCharacters]
        ) else {
            throw DebugCurriculumFixtureDataError.invalidBase64
        }
        let snapshot = try CurriculumJSONCodec.decodeSnapshot(from: data)
        try CurriculumValidator.validate(snapshot)
        return snapshot
    }

    private static let encodedSnapshot = """
ewogICJsb2NhbGUiOiAiZW4tVVMiLAogICJjYXRhbG9nUG9pbnRlcklEIjogImVuLXVzIiwKICAi
Y2F0YWxvZ1ZlcnNpb24iOiB7CiAgICAiY2F0YWxvZ1ZlcnNpb25JRCI6ICJjYXRhbG9nLS1lbi11
cy0tdjEiLAogICAgInZlcnNpb24iOiAxLAogICAgImxvY2FsZSI6ICJlbi1VUyIsCiAgICAicHVi
bGljYXRpb25TdGF0ZSI6ICJwdWJsaXNoZWQiLAogICAgInNjaGVtYVZlcnNpb24iOiAxLAogICAg
Im1pbmltdW1DbGllbnRTY2hlbWFWZXJzaW9uIjogMSwKICAgICJwcm9ncmFtRW50cmllcyI6IFsK
ICAgICAgewogICAgICAgICJwcm9ncmFtUG9pbnRlcklEIjogImFpLWZvdW5kYXRpb25zLS1lbi11
cyIsCiAgICAgICAgInByb2dyYW1WZXJzaW9uSUQiOiAiYWktZm91bmRhdGlvbnMtLWVuLXVzLS12
MSIKICAgICAgfQogICAgXSwKICAgICJjb250ZW50RGlnZXN0IjogIjA5ZWUzYmRlODk2NmNmNTdl
OGMwNmMxMWU3MGM4MTg2NjFhMzBiMTM0NGJlZTA4MDQ0ZGNmZmNkYTE0NWFjMGYiLAogICAgInB1
Ymxpc2hlZEF0IjogewogICAgICAic2Vjb25kcyI6IDE4MDAwMDAwMDAsCiAgICAgICJuYW5vc2Vj
b25kcyI6IDEyMzQ1Njc4OQogICAgfQogIH0sCiAgInByb2dyYW1WZXJzaW9ucyI6IFsKICAgIHsK
ICAgICAgInByb2dyYW1WZXJzaW9uSUQiOiAiYWktZm91bmRhdGlvbnMtLWVuLXVzLS12MSIsCiAg
ICAgICJwcm9ncmFtSUQiOiAiYWktZm91bmRhdGlvbnMiLAogICAgICAidmVyc2lvbiI6IDEsCiAg
ICAgICJsb2NhbGUiOiAiZW4tVVMiLAogICAgICAicHVibGljYXRpb25TdGF0ZSI6ICJwdWJsaXNo
ZWQiLAogICAgICAidGl0bGUiOiAiU1lOVEhFVElDLUNPTlRSQUNULUZJWFRVUkUtTkVWRVItUFVC
TElTSCIsCiAgICAgICJwcm9taXNlIjogIlN5bnRoZXRpYyBwbGFjZWhvbGRlciBwcm9ncmFtIHVz
ZWQgb25seSB0byB2YWxpZGF0ZSB0aGUgY3VycmljdWx1bSBjb250cmFjdC4iLAogICAgICAiY2F0
YWxvZ1N0YXRlIjogImF2YWlsYWJsZSIsCiAgICAgICJzY2hlbWFWZXJzaW9uIjogMSwKICAgICAg
Im1pbmltdW1DbGllbnRTY2hlbWFWZXJzaW9uIjogMSwKICAgICAgIm1vZHVsZVZlcnNpb25JRHMi
OiBbCiAgICAgICAgInN5bnRoZXRpYy1tb2R1bGUtLWVuLXVzLS12MSIKICAgICAgXSwKICAgICAg
ImZpcnN0TGVzc29uVmVyc2lvbklEIjogInN5bnRoZXRpYy1sZXNzb24tLWVuLXVzLS12MSIsCiAg
ICAgICJjb250ZW50RGlnZXN0IjogIjdkYTY3Nzc1YzU5MjA3ZjQyNmZkMjk1YzNlMzIyNjQ0ZWIz
YjM5YjIzNDIyYWVmNjg1ODg3MWMwMTE4MWMxNzAiLAogICAgICAicHVibGlzaGVkQXQiOiB7CiAg
ICAgICAgInNlY29uZHMiOiAxODAwMDAwMDAwLAogICAgICAgICJuYW5vc2Vjb25kcyI6IDEyMzQ1
Njc4OQogICAgICB9CiAgICB9CiAgXSwKICAibW9kdWxlVmVyc2lvbnMiOiBbCiAgICB7CiAgICAg
ICJtb2R1bGVWZXJzaW9uSUQiOiAic3ludGhldGljLW1vZHVsZS0tZW4tdXMtLXYxIiwKICAgICAg
Im1vZHVsZUlEIjogInN5bnRoZXRpYy1tb2R1bGUiLAogICAgICAicHJvZ3JhbUlEIjogImFpLWZv
dW5kYXRpb25zIiwKICAgICAgInZlcnNpb24iOiAxLAogICAgICAibG9jYWxlIjogImVuLVVTIiwK
ICAgICAgInB1YmxpY2F0aW9uU3RhdGUiOiAicHVibGlzaGVkIiwKICAgICAgInRpdGxlIjogIlN5
bnRoZXRpYyBjb250cmFjdCBtb2R1bGUiLAogICAgICAic3VtbWFyeSI6ICJTeW50aGV0aWMgcGxh
Y2Vob2xkZXIgbW9kdWxlIHVzZWQgb25seSBmb3IgZ3JhcGggdmFsaWRhdGlvbi4iLAogICAgICAi
c2NoZW1hVmVyc2lvbiI6IDEsCiAgICAgICJtaW5pbXVtQ2xpZW50U2NoZW1hVmVyc2lvbiI6IDEs
CiAgICAgICJsZXNzb25WZXJzaW9uSURzIjogWwogICAgICAgICJzeW50aGV0aWMtbGVzc29uLS1l
bi11cy0tdjEiCiAgICAgIF0sCiAgICAgICJjb250ZW50RGlnZXN0IjogImZiMTIwNjk0NmIxMTQ2
MDc3YWU1N2VmOTU4ZDU2ZTNjMWM0YWVmZmY4YmFlY2UxYTA0YWY3ZjY4MDJiNTk4YzYiLAogICAg
ICAicHVibGlzaGVkQXQiOiB7CiAgICAgICAgInNlY29uZHMiOiAxODAwMDAwMDAwLAogICAgICAg
ICJuYW5vc2Vjb25kcyI6IDEyMzQ1Njc4OQogICAgICB9CiAgICB9CiAgXSwKICAibGVzc29uVmVy
c2lvbnMiOiBbCiAgICB7CiAgICAgICJsZXNzb25WZXJzaW9uSUQiOiAic3ludGhldGljLWxlc3Nv
bi0tZW4tdXMtLXYxIiwKICAgICAgImxlc3NvbklEIjogInN5bnRoZXRpYy1sZXNzb24iLAogICAg
ICAicHJvZ3JhbUlEIjogImFpLWZvdW5kYXRpb25zIiwKICAgICAgIm1vZHVsZUlEIjogInN5bnRo
ZXRpYy1tb2R1bGUiLAogICAgICAidmVyc2lvbiI6IDEsCiAgICAgICJsb2NhbGUiOiAiZW4tVVMi
LAogICAgICAicHVibGljYXRpb25TdGF0ZSI6ICJwdWJsaXNoZWQiLAogICAgICAidGl0bGUiOiAi
U3ludGhldGljIGNvbnRyYWN0IGxlc3NvbiIsCiAgICAgICJvYmplY3RpdmUiOiAiVmFsaWRhdGUg
YSBzeW50aGV0aWMgcGxhY2Vob2xkZXIgZ3JhcGggd2l0aG91dCBzdXBwbHlpbmcgZWRpdG9yaWFs
IGN1cnJpY3VsdW0uIiwKICAgICAgImV4cGVjdGVkRHVyYXRpb25NaW51dGVzIjogMSwKICAgICAg
InByZXJlcXVpc2l0ZUxlc3NvbklEcyI6IFtdLAogICAgICAiY29tcGxldGlvblJ1bGUiOiB7CiAg
ICAgICAgImtpbmQiOiAicmVxdWlyZWRCbG9ja3NDb3JyZWN0IiwKICAgICAgICAicmVxdWlyZWRC
bG9ja0lEcyI6IFsKICAgICAgICAgICJzeW50aGV0aWMtcXVlc3Rpb24iCiAgICAgICAgXSwKICAg
ICAgICAibWluaW11bUNvcnJlY3RDb3VudCI6IDEsCiAgICAgICAgImFsbG93c1JldmlzaW9uIjog
dHJ1ZQogICAgICB9LAogICAgICAiYmxvY2tzIjogWwogICAgICAgIHsKICAgICAgICAgICJibG9j
a0lEIjogInN5bnRoZXRpYy1jb25jZXB0IiwKICAgICAgICAgICJ0eXBlIjogImNvbmNlcHRUZXh0
IiwKICAgICAgICAgICJvcmRlciI6IDAsCiAgICAgICAgICAiaGVhZGluZyI6ICJTeW50aGV0aWMg
cGxhY2Vob2xkZXIgY29uY2VwdCIsCiAgICAgICAgICAiYm9keSI6ICJTeW50aGV0aWMgcGxhY2Vo
b2xkZXIgdGV4dCBmb3IgY29udHJhY3QgdmFsaWRhdGlvbiBvbmx5LiBJdCBjb250YWlucyBubyBs
ZWFybmVyLWZhY2luZyBjdXJyaWN1bHVtIGNvbnRlbnQuIgogICAgICAgIH0sCiAgICAgICAgewog
ICAgICAgICAgImJsb2NrSUQiOiAic3ludGhldGljLWRpYWdyYW0tYmxvY2siLAogICAgICAgICAg
InR5cGUiOiAic3RpbGxEaWFncmFtIiwKICAgICAgICAgICJvcmRlciI6IDEsCiAgICAgICAgICAi
dGl0bGUiOiAiU3ludGhldGljIHBsYWNlaG9sZGVyIGRpYWdyYW0iLAogICAgICAgICAgImFzc2V0
VmVyc2lvbklEIjogInN5bnRoZXRpYy1kaWFncmFtLS1lbi11cy0tdjEiCiAgICAgICAgfSwKICAg
ICAgICB7CiAgICAgICAgICAiYmxvY2tJRCI6ICJzeW50aGV0aWMtcXVlc3Rpb24iLAogICAgICAg
ICAgInR5cGUiOiAic2luZ2xlQW5zd2VyUXVlc3Rpb24iLAogICAgICAgICAgIm9yZGVyIjogMiwK
ICAgICAgICAgICJwcm9tcHQiOiAiV2hpY2ggc3ludGhldGljIG9wdGlvbiBpcyB0aGUgZml4dHVy
ZSdzIGRldGVybWluaXN0aWMgY29udHJhY3Qgc2VudGluZWw/IiwKICAgICAgICAgICJvcHRpb25z
IjogWwogICAgICAgICAgICB7CiAgICAgICAgICAgICAgIm9wdGlvbklEIjogInN5bnRoZXRpYy1v
cHRpb24tYSIsCiAgICAgICAgICAgICAgInRleHQiOiAiU3ludGhldGljIG9wdGlvbiBBIgogICAg
ICAgICAgICB9LAogICAgICAgICAgICB7CiAgICAgICAgICAgICAgIm9wdGlvbklEIjogInN5bnRo
ZXRpYy1vcHRpb24tYiIsCiAgICAgICAgICAgICAgInRleHQiOiAiU3ludGhldGljIG9wdGlvbiBC
IgogICAgICAgICAgICB9CiAgICAgICAgICBdCiAgICAgICAgfQogICAgICBdLAogICAgICAicnVi
cmljVmVyc2lvbklEIjogInN5bnRoZXRpYy1ydWJyaWMtLWVuLXVzLS12MSIsCiAgICAgICJhc3Nl
dFZlcnNpb25JRHMiOiBbCiAgICAgICAgInN5bnRoZXRpYy1kaWFncmFtLS1lbi11cy0tdjEiCiAg
ICAgIF0sCiAgICAgICJzY2hlbWFWZXJzaW9uIjogMSwKICAgICAgIm1pbmltdW1DbGllbnRTY2hl
bWFWZXJzaW9uIjogMSwKICAgICAgImNvbnRlbnREaWdlc3QiOiAiMWRjYzVjMjRmY2MwMWZlNDE5
MTI3NTBlZmZkOTI1MmZmOTU2ZTdlMzk2YzJjMjc3NGI1MjIzY2FiODdjZmJiOCIsCiAgICAgICJw
dWJsaXNoZWRBdCI6IHsKICAgICAgICAic2Vjb25kcyI6IDE4MDAwMDAwMDAsCiAgICAgICAgIm5h
bm9zZWNvbmRzIjogMTIzNDU2Nzg5CiAgICAgIH0KICAgIH0KICBdLAogICJydWJyaWNWZXJzaW9u
cyI6IFsKICAgIHsKICAgICAgInJ1YnJpY1ZlcnNpb25JRCI6ICJzeW50aGV0aWMtcnVicmljLS1l
bi11cy0tdjEiLAogICAgICAicnVicmljSUQiOiAic3ludGhldGljLXJ1YnJpYyIsCiAgICAgICJ2
ZXJzaW9uIjogMSwKICAgICAgImxvY2FsZSI6ICJlbi1VUyIsCiAgICAgICJwdWJsaWNhdGlvblN0
YXRlIjogInB1Ymxpc2hlZCIsCiAgICAgICJraW5kIjogImRldGVybWluaXN0aWMiLAogICAgICAi
Y3JpdGVyaWEiOiBbCiAgICAgICAgewogICAgICAgICAgImNyaXRlcmlvbklEIjogInN5bnRoZXRp
Yy1jb3JyZWN0bmVzcyIsCiAgICAgICAgICAidGl0bGUiOiAiU3ludGhldGljIGNvbnRyYWN0IGNv
cnJlY3RuZXNzIiwKICAgICAgICAgICJkZXNjcmlwdGlvbiI6ICJTeW50aGV0aWMgcGxhY2Vob2xk
ZXIgY3JpdGVyaW9uIHVzZWQgb25seSB0byB2YWxpZGF0ZSBkZXRlcm1pbmlzdGljIHNjb3Jpbmcg
cmVmZXJlbmNlcy4iLAogICAgICAgICAgIm1heFNjb3JlIjogMQogICAgICAgIH0KICAgICAgXSwK
ICAgICAgImNsaWVudFNjb3JpbmdDb250cmFjdCI6IHsKICAgICAgICAia2luZCI6ICJzaW5nbGVB
bnN3ZXIiLAogICAgICAgICJxdWVzdGlvbkJsb2NrSUQiOiAic3ludGhldGljLXF1ZXN0aW9uIiwK
ICAgICAgICAiY29ycmVjdE9wdGlvbklEIjogInN5bnRoZXRpYy1vcHRpb24tYSIsCiAgICAgICAg
ImNvcnJlY3RGZWVkYmFjayI6ICJTeW50aGV0aWMgY29ycmVjdC1mZWVkYmFjayBwbGFjZWhvbGRl
ci4iLAogICAgICAgICJpbmNvcnJlY3RGZWVkYmFjayI6ICJTeW50aGV0aWMgaW5jb3JyZWN0LWZl
ZWRiYWNrIHBsYWNlaG9sZGVyLiIKICAgICAgfSwKICAgICAgImV2YWx1YXRpb25Db250cmFjdFZl
cnNpb25JRCI6ICJzeW50aGV0aWMtZXZhbHVhdGlvbi0tZW4tdXMtLXYxIiwKICAgICAgInNjaGVt
YVZlcnNpb24iOiAxLAogICAgICAibWluaW11bUNsaWVudFNjaGVtYVZlcnNpb24iOiAxLAogICAg
ICAiY29udGVudERpZ2VzdCI6ICI5NTVkNWZmYmFiOTZlNzI3NGY2NGI5YjhiMjJmYjgzNTM2MTg1
MTk3NWQ5YzkxNmIwYTIzMjVkY2ExZjQ4MTlkIiwKICAgICAgInB1Ymxpc2hlZEF0IjogewogICAg
ICAgICJzZWNvbmRzIjogMTgwMDAwMDAwMCwKICAgICAgICAibmFub3NlY29uZHMiOiAxMjM0NTY3
ODkKICAgICAgfQogICAgfQogIF0sCiAgImFzc2V0VmVyc2lvbnMiOiBbCiAgICB7CiAgICAgICJh
c3NldFZlcnNpb25JRCI6ICJzeW50aGV0aWMtZGlhZ3JhbS0tZW4tdXMtLXYxIiwKICAgICAgImFz
c2V0SUQiOiAic3ludGhldGljLWRpYWdyYW0iLAogICAgICAidmVyc2lvbiI6IDEsCiAgICAgICJs
b2NhbGUiOiAiZW4tVVMiLAogICAgICAicHVibGljYXRpb25TdGF0ZSI6ICJwdWJsaXNoZWQiLAog
ICAgICAia2luZCI6ICJkaWFncmFtRGF0YSIsCiAgICAgICJtaW1lVHlwZSI6ICJhcHBsaWNhdGlv
bi92bmQuc3ludGhvbG8uZGlhZ3JhbStqc29uIiwKICAgICAgInBheWxvYWQiOiB7CiAgICAgICAg
Im5vZGVzIjogWwogICAgICAgICAgewogICAgICAgICAgICAibm9kZUlEIjogInN5bnRoZXRpYy1u
b2RlLWEiLAogICAgICAgICAgICAibGFiZWwiOiAiU3ludGhldGljIGlucHV0IiwKICAgICAgICAg
ICAgImVtcGhhc2lzIjogIm5vcm1hbCIKICAgICAgICAgIH0sCiAgICAgICAgICB7CiAgICAgICAg
ICAgICJub2RlSUQiOiAic3ludGhldGljLW5vZGUtYiIsCiAgICAgICAgICAgICJsYWJlbCI6ICJT
eW50aGV0aWMgb3V0cHV0IiwKICAgICAgICAgICAgImVtcGhhc2lzIjogImFjY2VudCIKICAgICAg
ICAgIH0KICAgICAgICBdLAogICAgICAgICJjb25uZWN0b3JzIjogWwogICAgICAgICAgewogICAg
ICAgICAgICAiY29ubmVjdG9ySUQiOiAic3ludGhldGljLWNvbm5lY3RvciIsCiAgICAgICAgICAg
ICJmcm9tTm9kZUlEIjogInN5bnRoZXRpYy1ub2RlLWEiLAogICAgICAgICAgICAidG9Ob2RlSUQi
OiAic3ludGhldGljLW5vZGUtYiIsCiAgICAgICAgICAgICJsYWJlbCI6IG51bGwKICAgICAgICAg
IH0KICAgICAgICBdCiAgICAgIH0sCiAgICAgICJhY2Nlc3NpYmlsaXR5RGVzY3JpcHRpb24iOiAi
U3ludGhldGljIGRpYWdyYW0gd2l0aCBhIHBsYWNlaG9sZGVyIGlucHV0IGNvbm5lY3RlZCB0byBh
IHBsYWNlaG9sZGVyIG91dHB1dC4iLAogICAgICAicmlnaHRzIjogewogICAgICAgICJvcmlnaW4i
OiAib3JpZ2luYWwiLAogICAgICAgICJjcmVhdG9yIjogIlN5bnRob2xvIHN5bnRoZXRpYyB0ZXN0
IGZpeHR1cmUiLAogICAgICAgICJzb3VyY2VVUkwiOiBudWxsLAogICAgICAgICJsaWNlbnNlIjog
bnVsbAogICAgICB9LAogICAgICAic2NoZW1hVmVyc2lvbiI6IDEsCiAgICAgICJtaW5pbXVtQ2xp
ZW50U2NoZW1hVmVyc2lvbiI6IDEsCiAgICAgICJieXRlQ291bnQiOiAyOTIsCiAgICAgICJwYXls
b2FkRGlnZXN0IjogIjY5Yjk1M2U4MzdiMmExNzIxZWExNTg4ODRmZWZjMjE2MmE2NWE2MzQ5N2U5
MzczMTc0M2NlYWU1ZjFkNzgwMTgiLAogICAgICAiY29udGVudERpZ2VzdCI6ICI4ZWIzZjZkZmUy
NDBlN2JlNjkxYTc0YzQ4ZGU1NzI1MTkyODRlMjliYWNlMWFlNjAxMjU3YmMwMTQwZDAwNTE1IiwK
ICAgICAgInB1Ymxpc2hlZEF0IjogewogICAgICAgICJzZWNvbmRzIjogMTgwMDAwMDAwMCwKICAg
ICAgICAibmFub3NlY29uZHMiOiAxMjM0NTY3ODkKICAgICAgfQogICAgfQogIF0KfQo=
"""
}

private enum DebugCurriculumFixtureDataError: Error {
    case invalidBase64
}

private struct DebugLoadingCurriculumRepository:
    CurriculumRepository,
    Sendable
{
    func load(
        locale _: CurriculumLocale
    ) -> AsyncStream<CurriculumLoadEvent> {
        AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in }
        }
    }
}

private struct DebugEventSequenceCurriculumRepository:
    CurriculumRepository,
    Sendable
{
    let locale: CurriculumLocale
    let events: [CurriculumLoadEvent]
    let transitionDelayNanoseconds: UInt64

    func load(
        locale requestedLocale: CurriculumLocale
    ) -> AsyncStream<CurriculumLoadEvent> {
        guard requestedLocale == locale else {
            return AsyncStream { continuation in
                continuation.yield(.empty)
                continuation.finish()
            }
        }

        return AsyncStream { continuation in
            let task = Task {
                defer { continuation.finish() }
                for (index, event) in events.enumerated() {
                    guard !Task.isCancelled else {
                        return
                    }
                    if index > 0, transitionDelayNanoseconds > 0 {
                        do {
                            try await Task.sleep(
                                nanoseconds: transitionDelayNanoseconds
                            )
                        } catch {
                            return
                        }
                    }
                    guard !Task.isCancelled else {
                        return
                    }
                    continuation.yield(event)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

private actor DebugFailOnceCurriculumRepositoryState {
    private var didFail = false

    func nextEvent(
        snapshot: CurriculumSnapshot
    ) -> CurriculumLoadEvent {
        if !didFail {
            didFail = true
            return .unavailable(
                error: .networkUnavailable,
                saved: nil
            )
        }
        return .fresh(snapshot)
    }
}

private struct DebugFailOnceCurriculumRepository:
    CurriculumRepository,
    Sendable
{
    let snapshot: CurriculumSnapshot
    private let state = DebugFailOnceCurriculumRepositoryState()

    func load(
        locale: CurriculumLocale
    ) -> AsyncStream<CurriculumLoadEvent> {
        guard locale == snapshot.locale else {
            return AsyncStream { continuation in
                continuation.yield(.empty)
                continuation.finish()
            }
        }

        return AsyncStream { continuation in
            let task = Task {
                let event = await state.nextEvent(snapshot: snapshot)
                guard !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                continuation.yield(event)
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
#endif
