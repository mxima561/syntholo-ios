import Observation

enum CurriculumFreshness: Equatable, Hashable, Sendable {
    case saved
    case fresh
}

enum CurriculumStoreState: Equatable, Sendable {
    case loading
    case ready(CurriculumSnapshot, freshness: CurriculumFreshness)
    case empty
    case updateRequired(
        requiredVersion: Int,
        fallbackSnapshot: CurriculumSnapshot?
    )
    case unavailable(retryable: Bool)
}

@MainActor
@Observable
final class CurriculumStore {
    private(set) var state: CurriculumStoreState
    private(set) var locale: CurriculumLocale
    private(set) var isLoadActive: Bool

    @ObservationIgnored
    private var repository: any CurriculumRepository
    @ObservationIgnored
    private var loadTask: Task<Void, Never>?
    @ObservationIgnored
    private var loadGeneration: UInt64
    @ObservationIgnored
    private var didRequestInitialLoad: Bool
    @ObservationIgnored
    private var retainedSnapshots: [
        CurriculumCatalogVersionID: CurriculumSnapshot
    ]
    @ObservationIgnored
    private var retainedCatalogOrder: [CurriculumCatalogVersionID]
    @ObservationIgnored
    private var pinnedCatalogVersionIDs: Set<CurriculumCatalogVersionID>

    init(
        repository: any CurriculumRepository,
        locale: CurriculumLocale
    ) {
        self.repository = repository
        self.locale = locale
        state = .loading
        isLoadActive = false
        loadTask = nil
        loadGeneration = 0
        didRequestInitialLoad = false
        retainedSnapshots = [:]
        retainedCatalogOrder = []
        pinnedCatalogVersionIDs = []
    }

    deinit {
        loadTask?.cancel()
    }

    func load() {
        guard !didRequestInitialLoad, !isLoadActive else {
            return
        }
        didRequestInitialLoad = true
        beginLoad()
    }

    func retry() {
        guard !isLoadActive else {
            return
        }
        didRequestInitialLoad = true
        beginLoad()
    }

    func refresh() {
        didRequestInitialLoad = true
        cancelActiveLoadForReplacement()
        beginLoad()
    }

    /// The caller resets its Learn path before changing locale because routed
    /// snapshot pins are scoped to one locale.
    func replaceLocale(_ locale: CurriculumLocale) {
        guard locale != self.locale else {
            return
        }
        cancelActiveLoadForReplacement()
        self.locale = locale
        resetRetainedSnapshots()
        state = .loading
        didRequestInitialLoad = true
        beginLoad()
    }

    /// The caller resets its Learn path before replacing the repository because
    /// routed snapshot pins never cross environment or project boundaries.
    func replaceRepository(
        _ repository: any CurriculumRepository,
        locale: CurriculumLocale
    ) {
        cancelActiveLoadForReplacement()
        self.repository = repository
        self.locale = locale
        resetRetainedSnapshots()
        state = .loading
        didRequestInitialLoad = true
        beginLoad()
    }

    func snapshot(
        for catalogVersionID: CurriculumCatalogVersionID
    ) -> CurriculumSnapshot? {
        retainedSnapshots[catalogVersionID]
    }

    func setPinnedCatalogVersionIDs(
        _ catalogVersionIDs: Set<CurriculumCatalogVersionID>
    ) {
        pinnedCatalogVersionIDs = catalogVersionIDs
        pruneRetainedSnapshots()
    }

    private func beginLoad() {
        if displayedSnapshot == nil {
            state = .loading
        }
        if !isLoadActive {
            isLoadActive = true
        }

        loadGeneration &+= 1
        let generation = loadGeneration
        let repository = repository
        let locale = locale

        loadTask = Task { [weak self] in
            for await event in repository.load(locale: locale) {
                guard !Task.isCancelled,
                      let self,
                      self.loadGeneration == generation else {
                    break
                }
                if self.receive(event) {
                    break
                }
            }

            guard let self, self.loadGeneration == generation else {
                return
            }
            self.loadTask = nil
            if self.isLoadActive {
                self.isLoadActive = false
            }
        }
    }

    private func receive(_ event: CurriculumLoadEvent) -> Bool {
        switch event {
        case let .saved(snapshot):
            retain(snapshot)
            state = .ready(snapshot, freshness: .saved)
            return false

        case let .fresh(snapshot):
            retain(snapshot)
            state = .ready(snapshot, freshness: .fresh)
            return true

        case .empty:
            state = .empty
            return true

        case let .updateRequired(requiredSchema, saved):
            let fallback = saved ?? displayedSnapshot
            if let fallback {
                retain(fallback)
            }
            state = .updateRequired(
                requiredVersion: requiredSchema,
                fallbackSnapshot: fallback
            )
            return true

        case let .unavailable(_, saved):
            if let fallback = saved ?? displayedSnapshot {
                retain(fallback)
                state = .ready(fallback, freshness: .saved)
            } else {
                state = .unavailable(retryable: true)
            }
            return true
        }
    }

    private var displayedSnapshot: CurriculumSnapshot? {
        switch state {
        case let .ready(snapshot, _):
            snapshot
        case let .updateRequired(_, fallbackSnapshot):
            fallbackSnapshot
        case .loading, .empty, .unavailable:
            nil
        }
    }

    private func retain(_ snapshot: CurriculumSnapshot) {
        let catalogVersionID = snapshot.catalogVersion.catalogVersionID
        retainedCatalogOrder.removeAll { $0 == catalogVersionID }
        retainedCatalogOrder.append(catalogVersionID)
        retainedSnapshots[catalogVersionID] = snapshot

        pruneRetainedSnapshots()
    }

    private func pruneRetainedSnapshots() {
        let keepIDs = Set(retainedCatalogOrder.suffix(2))
            .union(pinnedCatalogVersionIDs)
        let removedIDs = retainedCatalogOrder.filter { !keepIDs.contains($0) }
        retainedCatalogOrder.removeAll { !keepIDs.contains($0) }
        for removedID in removedIDs {
            retainedSnapshots.removeValue(forKey: removedID)
        }
    }

    private func resetRetainedSnapshots() {
        pinnedCatalogVersionIDs.removeAll(keepingCapacity: true)
        retainedSnapshots.removeAll(keepingCapacity: true)
        retainedCatalogOrder.removeAll(keepingCapacity: true)
    }

    private func cancelActiveLoadForReplacement() {
        loadGeneration &+= 1
        let task = loadTask
        loadTask = nil
        task?.cancel()
    }
}
