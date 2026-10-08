public import Domain
public import Foundation
public import SwiftData

public enum CourierStorage {
    public static func makeContainer(isStoredInMemoryOnly: Bool) throws(RepositoryError) -> ModelContainer {
        let schema = Schema(versionedSchema: CourierSchemaV1.self)
        let configuration =
            isStoredInMemoryOnly
            ? ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration("CourierStore", schema: schema)
        return try makeContainer(schema: schema, configuration: configuration)
    }

    public static func makeContainer(storeURL: URL) throws(RepositoryError) -> ModelContainer {
        let schema = Schema(versionedSchema: CourierSchemaV1.self)
        return try makeContainer(schema: schema, configuration: ModelConfiguration(schema: schema, url: storeURL))
    }

    private static func makeContainer(
        schema: Schema,
        configuration: ModelConfiguration
    ) throws(RepositoryError) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            throw .storageFailure(String(describing: error))
        }
    }
}
