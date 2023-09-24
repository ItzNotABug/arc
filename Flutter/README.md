# **`AppwriteRemoteConfig`** for Flutter 🚀

## Getting Started 🛠️
Just copy the entire directory structure `io/appwrite/rc` along with all its files into your project.

Make sure you have the `appwrite sdk` added to your `pubspec.yaml`.
```yaml
dependencies:
  appwrite: ^11.0.0
```

## API
```dart
// Initialize your Appwrite client.
final client = // Your appwrite client ...

// Obtain an instance of AppwriteRemoteConfig.
final remoteConfig = await AppwriteRemoteConfig.instance;

// Configure the client.
remoteConfig.setClient(client);

// Define the database & collection identifiers.
// Defaults: databaseId = `remote_config`, collectionId = `release`
remoteConfig.setDatabaseAndCollectionIds(databaseId, collectionId);

// Specify the identifiers for key & value attributes.
// Defaults: keyAttribute = `key`, valueAttribute = `value`
remoteConfig.setKeyAndValueAttributeIds(keyAttribute, valueAttribute);

// Set caching duration (e.g., 3 hours).
remoteConfig.setCacheLimit(3);

// Provide default configurations. Useful for initial runs or offline scenarios without any cache.
remoteConfig.setDefaults({"betaFeatsActive": false, "cdnUrl": "https://cdn.speedy.app/"});

// Realtime updates: If using an existing `Realtime` instance:
// remoteConfig.addOnConfigUpdateListener(realtime, callback)
RealtimeSubscription subscription = remoteConfig.addOnConfigUpdateListener(callback: (key, value) {
    logDebug("$key: $value");
    return true;
});

// Fetch configurations & activate them.
remoteConfig.fetchAndActivate((sourceType) {
    // Possible sourceType values: `cache`, `network`, `defaults`, `failure(Error)`
    logDebug("Configurations activated from: ${source.type}");
    logDebug(remoteConfig.getCurrentConfigs());
});

// Access configurations.
int integerValue = remoteConfig.getInt(intKey);          // Defaults to 0 if key is absent.
String stringValue = remoteConfig.getString(stringKey); // Defaults to "" if key is absent.
bool booleanValue = remoteConfig.getBool(boolKey);      // Interprets "t", "true", "y", "yes", "1", "enable", "enabled", "on", "active" as true; defaults to false otherwise.
```