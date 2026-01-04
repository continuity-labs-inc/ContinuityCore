//
//  ContinuityCore.swift
//  ContinuityCore
//
//  Shared data structures for cross-app pattern visibility.
//  This is the foundation layer that enables AYA to query across
//  all Continuity Labs apps.
//
//  CANONICAL SOURCE: This Swift Package is the single source of truth.
//  All apps should import this package, not maintain their own copies.
//

import Foundation

// MARK: - Entity Type (Master List)

/// The canonical set of entity types across all Continuity Labs apps.
/// Not every app uses every type, but all apps recognize all types.
///
/// Organized by category:
/// - People & Groups: person, group
/// - Things & Places: object, place
/// - Time & Action: event, task, routine
/// - Meaning & Direction: concept, idea, goal, aspiration, project
/// - Structure: card (cross-reference to another ContinuityRecord)
///
public enum EntityType: String, Codable, Sendable, CaseIterable {
    
    // MARK: People & Groups
    
    /// A person mentioned or involved
    case person
    
    /// A group of people (family, team, community)
    case group
    
    // MARK: Things & Places
    
    /// A physical object (primarily MagikBox)
    case object
    
    /// A location
    case place
    
    // MARK: Time & Action
    
    /// A calendar event
    case event
    
    /// A discrete doable thing
    case task
    
    /// A recurring activity or habit
    case routine
    
    // MARK: Meaning & Direction
    
    /// A theme, topic, or abstract concept
    case concept
    
    /// A freeform thought, not yet actionable
    case idea
    
    /// An achievable endpoint
    case goal
    
    /// A goal-from-value (direction, not destination)
    case aspiration
    
    /// A work or personal project
    case project
    
    // MARK: Structure
    
    /// Reference to another ContinuityRecord (for synthesis, links)
    case card
}

// MARK: - Entity Reference

/// A reference to an entity that appears in a record.
/// Entities are the "nouns" that connect experiences across apps.
public struct EntityReference: Codable, Sendable, Identifiable, Hashable {
    
    /// The type of entity being referenced
    public let type: EntityType
    
    /// A stable identifier for the entity (e.g., "john-doe", "work-stress", UUID string)
    public let identifier: String
    
    /// Human-readable name for display
    public let displayName: String
    
    public var id: String { "\(type.rawValue):\(identifier)" }
    
    public init(type: EntityType, identifier: String, displayName: String) {
        self.type = type
        self.identifier = identifier
        self.displayName = displayName
    }
}

// MARK: - Continuity Record

/// A single record in the ContinuityCore system.
/// This is the atomic unit that flows between apps.
public struct ContinuityRecord: Codable, Sendable, Identifiable {
    
    /// Unique identifier for this record
    public let id: UUID
    
    /// When the record was created
    public let createdAt: Date
    
    /// Which app created this record (e.g., "thresh", "pops", "clearwater")
    public let sourceApp: String
    
    /// Entities referenced in this record
    public let entities: [EntityReference]
    
    /// App-specific payload data (JSON encoded)
    /// Each app defines its own payload structure
    public let payload: Data
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceApp: String,
        entities: [EntityReference],
        payload: Data
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceApp = sourceApp
        self.entities = entities
        self.payload = payload
    }
}

// MARK: - Continuity Record Store

/// Manages persistence and querying of ContinuityRecords.
/// Stores in shared App Group container for cross-app access.
public final class ContinuityRecordStore: @unchecked Sendable {
    
    public static let shared = ContinuityRecordStore()
    
    /// The canonical App Group identifier for all Continuity Labs apps
    public static let appGroupIdentifier = "group.continuitylabs.suite"
    
    private static let recordsFileName = "continuity_records.json"
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.continuitylabs.continuitycore", attributes: .concurrent)
    
    private var containerURL: URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
    }
    
    private var storeURL: URL {
        guard let containerURL = containerURL else {
            // Fallback to Application Support if App Group unavailable
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent(Self.recordsFileName)
        }
        return containerURL.appendingPathComponent(Self.recordsFileName)
    }
    
    public init() {}
    
    // MARK: - Save
    
    /// Saves a single record
    public func save(_ record: ContinuityRecord) throws {
        try save([record])
    }
    
    /// Saves multiple records (merges with existing)
    public func save(_ records: [ContinuityRecord]) throws {
        try queue.sync(flags: .barrier) {
            var existing = (try? loadAll()) ?? []
            
            // Merge: update existing records, add new ones
            for record in records {
                if let index = existing.firstIndex(where: { $0.id == record.id }) {
                    existing[index] = record
                } else {
                    existing.append(record)
                }
            }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(existing)
            try data.write(to: storeURL, options: .atomic)
        }
    }
    
    /// Alias for save (backwards compatibility)
    public func write(record: ContinuityRecord) throws {
        try save(record)
    }
    
    /// Alias for save (backwards compatibility)
    public func write(records: [ContinuityRecord]) throws {
        try save(records)
    }
    
    // MARK: - Fetch
    
    /// Loads all records
    public func loadAll() throws -> [ContinuityRecord] {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: storeURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([ContinuityRecord].self, from: data)
    }
    
    /// Alias for loadAll (backwards compatibility)
    public func readAll() throws -> [ContinuityRecord] {
        try loadAll()
    }
    
    /// Fetches records from a specific app
    public func fetch(from sourceApp: String) throws -> [ContinuityRecord] {
        try loadAll().filter { $0.sourceApp == sourceApp }
    }
    
    /// Fetches records involving a specific entity identifier
    public func fetch(involving entityIdentifier: String) throws -> [ContinuityRecord] {
        try loadAll().filter { record in
            record.entities.contains { $0.identifier == entityIdentifier }
        }
    }
    
    /// Fetches records involving a specific entity type
    public func fetch(entityType: EntityType) throws -> [ContinuityRecord] {
        try loadAll().filter { record in
            record.entities.contains { $0.type == entityType }
        }
    }
    
    /// Fetches records created within a date range
    public func fetch(from startDate: Date, to endDate: Date) throws -> [ContinuityRecord] {
        try loadAll().filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
    }
    
    /// Query by entity identifier (backwards compatibility alias)
    public func records(forEntityIdentifier identifier: String) throws -> [ContinuityRecord] {
        try fetch(involving: identifier)
    }
    
    /// Query by entity type (backwards compatibility alias)
    public func records(forEntityType type: EntityType) throws -> [ContinuityRecord] {
        try fetch(entityType: type)
    }
    
    /// Query by entity identifier (backwards compatibility alias)
    public func records(byEntityIdentifier identifier: String) throws -> [ContinuityRecord] {
        try fetch(involving: identifier)
    }
    
    /// Query by entity type (backwards compatibility alias)
    public func records(byEntityType type: EntityType) throws -> [ContinuityRecord] {
        try fetch(entityType: type)
    }
    
    /// Query by source app (backwards compatibility alias)
    public func records(bySourceApp sourceApp: String) throws -> [ContinuityRecord] {
        try fetch(from: sourceApp)
    }
    
    // MARK: - Delete
    
    /// Deletes a record by ID
    public func delete(id: UUID) throws {
        try queue.sync(flags: .barrier) {
            var existing = (try? loadAll()) ?? []
            existing.removeAll { $0.id == id }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(existing)
            try data.write(to: storeURL, options: .atomic)
        }
    }
    
    /// Alias for delete (backwards compatibility)
    public func delete(recordWithID id: UUID) throws {
        try delete(id: id)
    }
    
    /// Deletes all records from a specific app
    public func deleteAll(from sourceApp: String) throws {
        try queue.sync(flags: .barrier) {
            var existing = (try? loadAll()) ?? []
            existing.removeAll { $0.sourceApp == sourceApp }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(existing)
            try data.write(to: storeURL, options: .atomic)
        }
    }
    
    /// Deletes all records
    public func deleteAll() throws {
        try queue.sync(flags: .barrier) {
            let encoder = JSONEncoder()
            let data = try encoder.encode([ContinuityRecord]())
            try data.write(to: storeURL, options: .atomic)
        }
    }
    
    // MARK: - Stats
    
    /// Returns count of records by source app
    public func recordCounts() throws -> [String: Int] {
        let records = try loadAll()
        var counts: [String: Int] = [:]
        for record in records {
            counts[record.sourceApp, default: 0] += 1
        }
        return counts
    }
    
    /// Returns all unique entity identifiers across all records
    public func allEntityIdentifiers() throws -> Set<String> {
        let records = try loadAll()
        var identifiers: Set<String> = []
        for record in records {
            for entity in record.entities {
                identifiers.insert(entity.identifier)
            }
        }
        return identifiers
    }
}

// MARK: - Errors

public enum ContinuityStoreError: Error, LocalizedError {
    case appGroupUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "App Group container '\(ContinuityRecordStore.appGroupIdentifier)' is not available. Ensure the App Group capability is configured."
        }
    }
}
