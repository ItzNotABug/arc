//
//  AppwriteRemoteConfig.swift
//
//  Created by Darshan Pandya (@itznotabug) on 06/09/23.
//

import Appwrite
import Foundation

/// `AppwriteRemoteConfig` is a utility class designed to fetch, cache, and manage remote configuration settings from `appwrite`.
///
/// It provides functionalities similar to **Firebase's RemoteConfig**,
/// allowing the app to fetch configurations from an appwrite collection, cache them locally, or apply default configurations when necessary.
///
/// Use the shared singleton instance `AppwriteRemoteConfig.shared` to access the methods.
public class AppwriteRemoteConfig {
    
    // MARK: - Constants
    
    private let DEFAULT_INT_VALUE = 0
    private let DEFAULT_STRING_VALUE = ""
    private let DEFAULT_BOOL_VALUE = false
    
    // MARK: - Appwrite
    /// Client to get Databases!
    private var client: Client!
    
    /// Collection Id of the documents
    private var collectionId = "release"
    
    /// Database Id of the collection
    private var databaseId = "remote_config"
    
    /// Default attribute name for `key`
    private var keyAttribute = "key"
    
    /// Default attribute name for `value`
    private var valueAttribute = "value"
    
    // logging tag
    private let tag = "AppwriteRemoteConfig"
    
    // MARK: - Singleton
    
    static let shared = AppwriteRemoteConfig()
    
    // MARK: - Properties
    
    private var lastFetchedTime: Date!
    private var cacheLimitInHours: Int = 24
    private var configs: [String: Any] = [:]
    private var defaults: [String: Any] = [:]
    
    private let lastFetchedTimeKey = "appwriteRemoteConfigLastFetchTime"
    private var fetchedConfigURL: URL { cacheDirectory.appendingPathComponent("appwrite_rc_network.json") }
    private var cacheDirectory: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("remoteConfigs") }
    
    // MARK: - Initializers
    
    private init() {
        /// Use `SecureDefaults` library if you want encryption
        if let savedDate = UserDefaults.standard.object(forKey: lastFetchedTimeKey) as? Date {
            lastFetchedTime = savedDate
        } else {
            lastFetchedTime = Date()
        }
        
        Task { ensureLocalStoreExists() }
    }
    
    // MARK: - Public Functions
    
    /// Sets the default configurations to be used when fetched configurations are not available.
    /// - Parameter configs: A dictionary containing the default configurations.
    public func setDefaults(_ configs: [String: Any]) {
        self.defaults = configs
    }
    
    /// Set the appwrite `Client` for creating `Databases` instance & fetching the documents
    /// - Parameter client: The appwrite `Client`.
    public func setClient(_ client: Client) {
        self.client = client
    }
    
    /// Set the `databaseId` & `collectionId` of your remote config documents
    /// - Parameters:
    ///   - databaseId: The database identifier, Default is 'remote\_config'.
    ///   - collectionId: The collection identifier, Default is 'release'.
    public func setDatabaseAndCollectionIds(_ databaseId: String, _ collectionId: String) {
        self.databaseId = databaseId
        self.collectionId = collectionId
    }
    
    /// Set the `keyAttribute` & `valueAttribute` to use while extracting the data from documents.
    /// - Parameters:
    ///   - keyAttribute: The key attribute identifier, Default is 'key'.
    ///   - valueAttribute: The value attribute identifier, Default is 'value'.
    public func setKeyAndValueAttributeIds(_ keyAttribute: String, _ valueAttribute: String) {
        self.keyAttribute = keyAttribute
        self.valueAttribute = valueAttribute
    }
    
    /// Configures the maximum duration for which fetched configurations are considered valid.
    /// - Parameter hours: The cache limit in hours. Passing `0` will always attempt a fresh fetch.
    public func setCacheLimit(hours: Int) {
        self.cacheLimitInHours = hours
    }
    
    /// Fetches the remote configurations and activates them.
    /// - Parameter callback: A completion handler with a `SourceType` parameter indicating the data source or error if any.
    public func fetchAndActivate(_ callback: ((SourceType) -> Void)? = nil) {
        Task {
            let result = await fetch()
            callback?(result)
        }
    }
    
    // MARK: - Realtime Updates
    
    /// Subscribes for real-time updates on a remote config documents.
    /// - Parameters:
    ///   - realtime: An optional instance of the `Realtime` class. If not provided, a new instance will be created internally.
    ///   - callback: A callback that is triggered upon receiving an update. The callback is passed a dictionary (`[String: Any]`) representing the updated config. If you return true from callback, the new or updated configs are saved to disk.
    /// - Returns: A `RealtimeSubscription` object which can be used to stop the subscription. Call `subscription.close()`.
    public func addOnConfigUpdateListener(_ realtime: Realtime? = nil, _ callback: @escaping (String, Any) -> Bool) -> RealtimeSubscription {
        let realtimeInstance = realtime ?? Realtime(client)
        let channel = "databases.\(databaseId).collections.\(collectionId).documents"
        let subscription = realtimeInstance.subscribe(channel: channel) { result in
            /// first element contains the full event, atleast on 1.4x
            guard let event = result.events?.first else {
                print("\(self.tag): No events received in the realtime update!")
                return
            }
            
            if let usablePayload = result.payload,
               let key = usablePayload[self.keyAttribute] as? String,
               let value = usablePayload[self.valueAttribute] {
                
                if event.contains("delete") {
                    Task {
                        self.configs.removeValue(forKey: key)
                        self.saveToDisk(self.configs)
                        print("\(self.tag): Removed `\(key)` from configs!")
                    }
                }
                else {
                    if callback(key, value) {
                        print("\(self.tag): Saving updated configs to disk...")
                        
                        Task {
                            var newConfigs: [String: Any] = self.configs
                            newConfigs.updateValue(value, forKey: key)
                            
                            /// update and save
                            self.configs = newConfigs
                            self.saveToDisk(self.configs)
                        }
                        print("\(self.tag): Updated configs successfully saved to disk!")
                    }
                }
            } else {
                print("\(self.tag): No payload or invalid payload received in the realtime update!")
            }
        }
        
        return subscription
    }
    
    // MARK: - Config Accessors
    
    /// Returns the current configurations being used by the `AppwriteRemoteConfig`.
    /// - Returns: A dictionary containing the active configurations, which could be fetched configurations, saved configurations from disk, or default configurations.
    public func getCurrentConfigs() -> [String: Any] {
        return configs
    }
    
    /// Retrieves a configuration value as a string.
    /// - Parameter key: The key for the configuration value.
    /// - Returns: The configuration value as a string, or an empty string if not found.
    public func getString(key: String) -> String {
        return get(key: key) ?? DEFAULT_STRING_VALUE
    }
    
    
    /// Retrieves a configuration value as an integer.
    ///
    /// - Parameter key: The key for the configuration value.
    /// - Returns: The configuration value as an integer, or `0` if not found or if the conversion fails.
    public func getInt(key: String) -> Int {
        if let value = get(key: key), let intValue = Int(value) {
            return intValue
        }
        return DEFAULT_INT_VALUE
    }
    
    /// Retrieves a configuration value as a boolean.
    ///
    /// - Parameter key: The key for the configuration value.
    /// - Returns: The configuration value as a boolean. It checks for common truthy string values to determine the boolean representation.
    public func getBool(key: String) -> Bool {
        if let value = get(key: key) {
            let truthyStrings = ["t", "true", "y", "yes", "1", "enable", "enabled", "on", "active"]
            return truthyStrings.contains(value.lowercased())
        }
        return DEFAULT_BOOL_VALUE
    }
    
    // MARK: - Private Functions
    
    /// Gets a config value for the given key.
    private func get(key: String) -> String? {
        guard let value = configs[key] ?? defaults[key] else {
            return nil
        }
        
        return String(describing: value)
    }
    
    /// Ensures the necessary directory and file exist.
    private func ensureLocalStoreExists() {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            if !FileManager.default.fileExists(atPath: fetchedConfigURL.path) {
                FileManager.default.createFile(atPath: fetchedConfigURL.path, contents: nil, attributes: nil)
            }
        } catch {
            print("\(tag): Failed to create directory or file - \(error)")
        }
    }
    
    /// Fetches configs from the server.
    private func fetch() async -> SourceType {
        
        // Check if the cache is still valid
        if isCacheValid(), let savedConfigs = loadSavedConfigs() {
            configs = savedConfigs
            return .cache
        }
        
        let databases = Databases(client)
        
        let maxItemsPerPage = 25
        var documentMappings: [String: String] = [:]
        var documentsQuery = [Query.limit(maxItemsPerPage)]
        
        do {
            while true {
                let documentsList = try await databases.listDocuments(databaseId: databaseId, collectionId: collectionId, queries: documentsQuery)
                let documents = documentsList.documents
                
                if (documents.isEmpty) { break }
                
                for document in documents {
                    let key = String(describing: document.data[keyAttribute]!)
                    let value = String(describing: document.data[valueAttribute]!)
                    documentMappings[key] = value
                }
                
                if (documents.count < maxItemsPerPage) { break }
                
                let lastId = documents[documents.count - 1].id
                documentsQuery = [Query.limit(maxItemsPerPage), Query.cursorAfter(lastId)]
            }
            
            if documentMappings.isEmpty {
                print("\(tag): No documents exist for RemoteConfig!")
                
                if let savedConfigs = loadSavedConfigs() {
                    configs = savedConfigs; return .cache
                } else { configs = defaults; return .defaults }
            }
            
            configs = documentMappings
            saveToDisk(documentMappings)
            return .network
        }
        
        catch {
            configs = loadSavedConfigs() ?? defaults
            return .failure(error)
        }
    }
    
    /// Determines if we should use cached configs.
    private func isCacheValid() -> Bool {
        return Date().timeIntervalSince(lastFetchedTime) <= Double(cacheLimitInHours * 3600)
    }
    
    /// Saves configs to disk.
    private func saveToDisk(_ configs: [String: Any]) {
        let stringifiedConfigs = stringify(from: configs)
        if let data = try? JSONEncoder().encode(stringifiedConfigs) {
            if let _ = try? data.write(to: fetchedConfigURL) {
                UserDefaults.standard.setValue(Date(), forKey: lastFetchedTimeKey)
            } else {
                print("\(tag): Failed to save the fetched configs to file!")
            }
        } else {
            print("\(tag): Failed to encode the fetched configs for saving!")
        }
    }
    
    /// Converts a dictionary with keys of type `String` and values of any type into a dictionary with both keys and values of type `String`.
    private func stringify(from configs: [String: Any]) -> [String: String] {
        var stringifiedConfig: [String: String] = [:]
        
        for (key, value) in configs {
            stringifiedConfig[key] = "\(value)"
        }
        
        return stringifiedConfig
    }
    
    /// Loads configs from disk if they exist.
    private func loadSavedConfigs() -> [String: String]? {
        do {
            let data = try Data(contentsOf: fetchedConfigURL)
            let json = try JSONDecoder().decode([String: String].self, from: data)
            return json
        } catch {
            print("\(tag): Failed to load saved configs - \(error)")
            return nil
        }
    }
}
