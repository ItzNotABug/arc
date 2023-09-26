# **`AppwriteRemoteConfig`** for Android 🚀

## Getting Started 🛠️
Just copy the entire directory structure `io/appwrite/rc` along with all its files into your project.

Make sure you have the `appwrite sdk` added to your `build.gradle`.
```groovy
implementation("io.appwrite:sdk-for-android:4.0.0")
```

## API
1. Kotlin

```kotlin
// Initialize your Appwrite client.
val client =  // Your appwrite client ...

// Obtain an instance of AppwriteRemoteConfig.
val remoteConfig = AppwriteRemoteConfig.getInstance(this@MainActivity)

// Configure the client.
remoteConfig.setClient(client)

// Define the database & collection identifiers.
// Defaults: databaseId = `remote_config`, collectionId = `release`
remoteConfig.setDatabaseAndCollectionIds(databaseId, collectionId)

// Specify the identifiers for key & value attributes.
// Defaults: keyAttribute = `key`, valueAttribute = `value`
remoteConfig.setKeyAndValueAttributeIds(keyAttribute, valueAttribute)

// Set caching duration (e.g., 3 hours).
remoteConfig.setCacheLimit(3)

// Provide default configurations, ideal for initial runs or offline scenarios without cache.
remoteConfig.setDefaults(mapOf("betaFeatsActive" to false, "cdnUrl" to "https://cdn.speedy.app/"))

// Realtime updates: 
// If already using an instance of `Realtime` then do:
// remoteConfig.addOnConfigUpdateListener(realtime, callback)
val subscription = remoteConfig.addOnConfigUpdateListener(callback = object : ConfigUpdateListener {
    override fun onConfigUpdate(updatedConfig: Pair<String, Any>): Boolean {
        logDebug(updatedConfig.toString())
        return true // True indicates changes should be immediately persisted to disk.
    }
})

// Fetch and activate configurations.
remoteConfig.fetchAndActivate { sourceType ->
    // sourceType can be `CACHE`, `NETWORK`, `DEFAULTS`, `FAILURE(Exception)`
    logDebug("Configurations activated from: ${source.type}")
    logDebug(remoteConfig.getCurrentConfigs().toString())
}

// Access configurations.
val integerValue = remoteConfig.getInt(intKey) // Returns 0 if key is absent.
val stringValue = remoteConfig.getString(stringKey) // Returns "" if key is absent.
val booleanValue = remoteConfig.getBool(boolKey) // Interprets "t", "true", "y", "yes", "1", "enable", "enabled", "on", "active" as true; defaults to false otherwise.
```

2. Java

```java
// Initialize your Appwrite client.
Client client =  // Your appwrite client ...

// Obtain an instance of AppwriteRemoteConfig.
AppwriteRemoteConfig remoteConfig = AppwriteRemoteConfig.getInstance(MainActivity.this);

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

// Provide default configurations, ideal for initial runs or offline scenarios without cache.
Map<String, Object> defaults = new HashMap<>();
defaults.put("betaFeatsActive", false);
defaults.put("cdnUrl", "https://cdn.speedy.app/");
remoteConfig.setDefaults(defaults);

// Realtime updates:
// If already using an instance of `Realtime` then do:
// remoteConfig.addOnConfigUpdateListener(realtime, callback)
RealtimeSubscription subscription = remoteConfig.addOnConfigUpdateListener(updatedConfig -> {
    logDebug(updatedConfig.getFirst() + ": " + updatedConfig.getSecond());
    return true; // True indicates changes should be immediately persisted to disk.
});

// Fetch and activate configurations.
remoteConfig.fetchAndActivate((SourceType sourceType) -> {
    // sourceType can be `CACHE`, `NETWORK`, `DEFAULTS`, `FAILURE(Exception)`
    logDebug("Configurations activated from: " + sourceType.getType());
    logDebug(remoteConfig.getCurrentConfigs().toString());
    if (sourceType instanceof SourceType.FAILURE) {
        String message = ((SourceType.FAILURE) sourceType).getException().getMessage();
        logError(message);
    }
    return null;
});

// Access configurations.
int integerValue = remoteConfig.getInt(intKey); // Returns 0 if key is absent.
String stringValue = remoteConfig.getString(stringKey); // Returns "" if key is absent.
boolean booleanValue = remoteConfig.getBool(boolKey); // Interprets "t", "true", "y", "yes", "1", "enable", "enabled", "on", "active" as true; defaults to false otherwise.
```