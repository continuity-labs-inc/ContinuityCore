# ContinuityCore

Shared data layer for all Continuity Labs apps. This Swift Package is the **single source of truth** for cross-app data structures and entity extraction.

## What This Is

ContinuityCore enables AYA (the AI perceiver layer) to query patterns across all Continuity Labs apps by providing:

1. **ContinuityRecord** - The atomic unit of data that flows between apps
2. **EntityReference** - References to people, places, concepts, etc. that connect records
3. **EntityType** - Master list of entity types recognized across all apps
4. **ContinuityRecordStore** - Shared storage in App Group container
5. **EntityExtractor** - On-device NLP for extracting entities from text (no API calls)

## Adding to Your App

In Xcode:

1. File → Add Package Dependencies
2. Click "Add Local..."
3. Navigate to `ContinuityLabsGit/ContinuityCore`
4. Add to your app target

Then import:

```swift
import ContinuityCore
```

## App Group Requirement

All apps must have the App Group capability enabled for:

```
group.continuitylabs.suite
```

## Usage

### Creating a ContinuityRecord

```swift
import ContinuityCore

// Extract entities from text
let extracted = EntityExtractor.shared.extract(from: "Had coffee with Sarah today. We talked about work stress.")

// Convert to EntityReferences
let entities = EntityExtractor.shared.toEntityReferences(extracted)

// Create your app-specific payload
let payload = try JSONEncoder().encode(MyPayload(...))

// Create and save the record
let record = ContinuityRecord(
    sourceApp: "myapp",
    entities: entities,
    payload: payload
)

try ContinuityRecordStore.shared.save(record)
```

### Querying Records

```swift
// All records involving a person
let sarahRecords = try ContinuityRecordStore.shared.fetch(involving: "sarah")

// All records from a specific app
let threshRecords = try ContinuityRecordStore.shared.fetch(from: "thresh")

// All records involving places
let placeRecords = try ContinuityRecordStore.shared.fetch(entityType: .place)

// Records in a date range
let recent = try ContinuityRecordStore.shared.fetch(
    from: Date().addingTimeInterval(-86400 * 7),
    to: Date()
)
```

### Entity Types

The master list of entity types:

| Type | Description | Primary Apps |
|------|-------------|--------------|
| `person` | A person mentioned or involved | All |
| `group` | A group of people | Chorus |
| `object` | A physical object | MagikBox |
| `place` | A location | All |
| `event` | A calendar event | POPs |
| `task` | A discrete doable thing | POPs |
| `routine` | A recurring activity | Thresh |
| `concept` | A theme or abstract concept | Thresh, POPs |
| `idea` | A freeform thought | POPs |
| `goal` | An achievable endpoint | POPs |
| `aspiration` | A goal-from-value | POPs |
| `project` | A work or personal project | Thresh, POPs |
| `card` | Reference to another record | All |

## Philosophy

See `ContinuityCore_Vision_Document.md` for the full philosophy behind this architecture.

Key principles:
- **Cards vary, connections persist** - Each app defines its own payload structure, but entities create the web
- **AI perceives, human decides** - The dog metaphor: AYA surfaces patterns, users interpret meaning
- **On-device first** - EntityExtractor uses Apple's NaturalLanguage framework, no API calls
