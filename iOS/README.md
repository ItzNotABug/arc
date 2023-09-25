# **`AppwriteRemoteConfig`** for iOS 🚀

## Getting Started 🛠️
Just copy the entire directory structure `io/appwrite/rc` along with all its files into your project.

Make sure you have the `appwrite sdk` added to your project either via `Xcode with Swift Package Manager` or `Package.swift`
1. `Xcode with Swift Package Manager` -
   1. Select File > Add Packages
   2. In the dialog that appears, enter the Appwrite Swift SDK package URL in the search field.
   3. Once found, select `sdk-for-apple`.
   4. On the right, select your version rules and ensure your desired target is selected in the Add to Project field.
   5. Now click add package and you're done!

2. `Package.swift` -
   Add the package to your Package.swift dependencies:
   ```swift
       dependencies: [
        .package(url: "git@github.com:appwrite/sdk-for-apple.git", from: "4.0.1"),
       ],
    ```
   Then add it to your target:
    ```swift
        targets: [
            .target(
                name: "YourAppTarget",
                dependencies: [
                    .product(name: "", package: "sdk-for-apple")
                ]
            ),
    ```

## API
```swift
// Initialize your Appwrite client.
let client =  // Your appwrite client ...

// Obtain an instance of AppwriteRemoteConfig.
let remoteConfig = AppwriteRemoteConfig.shared

// Configure the client.
remoteConfig.setClient(client)

// Define the database & collection identifiers.
// Defaults: databaseId = `remote_config`, collectionId = `release`
remoteConfig.setDatabaseAndCollectionIds(databaseId, collectionId)

// Specify the identifiers for key & value attributes.
// Defaults: keyAttribute = `key`, valueAttribute = `value`
remoteConfig.setKeyAndValueAttributeIds(keyAttribute, valueAttribute)

// Set caching duration (e.g., 3 hours).
remoteConfig.setCacheLimit(hours: 3)

// Provide default configurations. Useful for initial runs or offline scenarios without any cache.
remoteConfig.setDefaults(["betaFeatsActive": false, "cdnUrl": "https://cdn.speedy.app/"])

// Realtime updates: If using an existing `Realtime` instance:
// remoteConfig.addOnConfigUpdateListener(realtime, callback)
subscription = remoteConfig.addOnConfigUpdateListener() { key, value in
    logDebug("\(key): \(value)")
    return true; // True indicates changes should be immediately persisted to disk.
}

// Fetch configurations & activate them.
remoteConfig.fetchAndActivate((sourceType) {
    // Possible sourceType values: `cache`, `network`, `defaults`, `failure(Error)`
    logDebug("Configurations activated from: \(source.type)");
    logDebug(remoteConfig.getCurrentConfigs())
});

// Access configurations.
int integerValue = remoteConfig.getInt(intKey)          // Defaults to 0 if key is absent.
String stringValue = remoteConfig.getString(stringKey) // Defaults to "" if key is absent.
bool booleanValue = remoteConfig.getBool(boolKey)      // Interprets "t", "true", "y", "yes", "1", "enable", "enabled", "on", "active" as true; defaults to false otherwise.
```
