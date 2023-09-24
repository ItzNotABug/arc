package io.appwrite.rc

import android.content.Context
import android.util.Log
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import io.appwrite.Client
import io.appwrite.Query
import io.appwrite.extensions.toJson
import io.appwrite.models.RealtimeSubscription
import io.appwrite.rc.callback.ConfigUpdateListener
import io.appwrite.rc.types.SourceType
import io.appwrite.services.Databases
import io.appwrite.services.Realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File

/**
 * `AppwriteRemoteConfig` is a utility class designed to fetch, cache, and manage remote
 * configuration settings from `appwrite`.
 *
 * It provides functionalities similar to Firebase's RemoteConfig, allowing the app
 * to fetch configurations from an appwrite collection, cache them locally, or apply
 * default configurations when necessary.
 *
 * Use the [AppwriteRemoteConfig.getInstance] method to access the methods.
 */
class AppwriteRemoteConfig private constructor(context: Context) {
    // Appwrite
    // Client to get Databases!
    private lateinit var client: Client

    // Collection Id of the documents
    private var collectionId = "release"

    // Database Id of the collection
    private var databaseId = "remote_config"

    /// Default attribute name for `key`
    private var keyAttribute = "key"

    /// Default attribute name for `value`
    private var valueAttribute = "value"


    private var cacheLimitInHours: Int = 24
    private var configs: Map<String, Any> = emptyMap()
    private var defaults: Map<String, Any> = emptyMap()
    private var lastFetchedTime: Long = System.currentTimeMillis()
    private val lastFetchedTimeKey = "appwriteRemoteConfigLastFetchTime"

    // Files & Directories
    private val remoteConfigDirectory by lazy { File(context.filesDir, "remoteConfigs") }
    private val remoteConfigFile by lazy { File(remoteConfigDirectory, "appwrite_rc_network.json") }

    // Preferences
    private val sharedPreferences by lazy {
        context.getSharedPreferences("appwrite_rc", Context.MODE_PRIVATE)
    }

    // Coroutine Scopes
    private var coroutineScope: CoroutineScope

    init {
        ensureLocalStoreExists()
        lastFetchedTime = sharedPreferences.getLong(lastFetchedTimeKey, System.currentTimeMillis())

        // set the CoroutineScope if available.
        coroutineScope = if (context is LifecycleOwner) context.lifecycleScope
        else CoroutineScope(SupervisorJob())
    }

    /**
     * Sets the default configurations to be used when fetched configurations are not available.
     *
     * @param defaults A map containing the default configurations.
     */
    fun setDefaults(defaults: Map<String, Any>) {
        this.defaults = defaults
    }

    /**
     * Set the appwrite `Client` for creating `Databases` instance & fetching the documents.
     *
     * @param client The appwrite `Client`.
     */
    fun setClient(client: Client) {
        this.client = client
    }

    /**
     * Set the `databaseId` & `collectionId` of your remote config documents.
     *
     * @param databaseId The database identifier, Default is 'remote_config'.
     * @param collectionId The collection identifier, Default is 'release'.
     */
    fun setDatabaseAndCollectionIds(databaseId: String, collectionId: String) {
        this.databaseId = databaseId
        this.collectionId = collectionId
    }

    /**
     * Set the `keyAttribute` & `valueAttribute` to use while extracting the data from documents.
     *
     * @param keyAttribute The key attribute identifier, Default is 'key'.
     * @param valueAttribute The value attribute identifier, Default is 'value'.
     */
    fun setKeyAndValueAttributeIds(keyAttribute: String, valueAttribute: String) {
        this.keyAttribute = keyAttribute
        this.valueAttribute = valueAttribute
    }

    /**
     * Configures the maximum duration for which fetched configurations are considered valid.
     *
     * @param hours The cache limit in hours. Passing `0` will always attempt a fresh fetch.
     */
    fun setCacheLimit(hours: Int) {
        this.cacheLimitInHours = hours
    }

    /**
     * Fetches the remote configurations and activates them.
     *
     * @param callback A callback with a `SourceType` parameter indicating
     * the data source or error if any.
     *
     * @see SourceType
     */
    @JvmOverloads
    fun fetchAndActivate(callback: ((SourceType) -> Unit)? = null) {
        coroutineScope.launch {
            val result = withContext(Dispatchers.IO) { fetch() }
            callback?.invoke(result)
        }
    }

    /**
     * Subscribe for real-time updates on a remote config document.
     *
     * @param realtime An optional instance of the `Realtime` class.
     * If not provided, a new instance will be created internally.
     *
     * @param callback A callback that is triggered upon receiving an update.
     * The callback is passed a `Pair<String, String>` representing the updated config.
     *
     * @return [RealtimeSubscription] A `subscription` object which can be used to stop the
     * subscription. Call `subscription.close()`.
     */
    @JvmOverloads
    fun addOnConfigUpdateListener(
        realtime: Realtime? = null,
        callback: ConfigUpdateListener,
    ): RealtimeSubscription {
        val realtimeInstance = realtime ?: Realtime(client)
        val channel = "databases.$databaseId.collections.$collectionId.documents"
        val subscription = realtimeInstance.subscribe(channel) { result ->
            // first element contains the full event, atleast on 1.4x
            val event = result.events.first()

            val payload = JSONObject(result.payload.toJson())
            if (payload.has(keyAttribute) && payload.has(valueAttribute)) {
                val key = payload.get(keyAttribute).toString()
                val value = payload.get(valueAttribute).toString()

                if (event.contains("delete")) {
                    coroutineScope.launch(Dispatchers.IO) {
                        configs = configs.toMutableMap().apply {
                            this.remove(key); saveToDisk(this)
                            Log.d(tag, "Removed `$key` from configs!")
                        }
                    }
                } else {
                    // update or create a new key, value pair!
                    if (callback.onConfigUpdate(key to value)) {
                        Log.d(tag, "Saving updated configs to disk...")

                        coroutineScope.launch(Dispatchers.IO) {
                            configs = configs.toMutableMap().apply {
                                this[key] = value; saveToDisk(this)
                                Log.d(tag, "Updated configs successfully saved to disk!")
                            }
                        }
                    }
                }
            } else {
                Log.d(tag, "No payload or invalid payload received in the realtime update!")
            }
        }

        return subscription
    }

    /**
     * Returns the current configurations being used by the `AppwriteRemoteConfig`.
     *
     * @return [Map] specifically `<String, Any>` containing the active configurations,
     * which could be fetched, saved from disk, or default configurations.
     */
    fun getCurrentConfigs(): Map<String, Any> {
        return configs
    }

    /**
     * Retrieves a configuration value as a string.
     *
     * @param key The key for the configuration value.
     * @return [String] The configuration value as a string, or an empty string if not found.
     */
    fun getString(key: String): String {
        return get(key) ?: DEFAULT_STRING_VALUE
    }

    /**
     * Retrieves a configuration value as an integer.
     *
     * @param key The key for the configuration value.
     * @return [Int] The configuration value as an integer, or `0` if not found or if the conversion fails.
     */
    fun getInt(key: String): Int {
        return get(key)?.toIntOrNull() ?: DEFAULT_INT_VALUE
    }

    /**
     *  Retrieves a configuration value as a boolean.
     *
     * @param key The key for the configuration value.
     * @return [Boolean] The configuration value as a boolean.
     * It checks for common truthy string values to determine the boolean representation.
     */
    fun getBool(key: String): Boolean {
        val value = get(key) ?: return DEFAULT_BOOL_VALUE
        val truthyStrings = setOf("t", "true", "y", "yes", "1", "enable", "enabled", "on", "active")
        return truthyStrings.contains(value.lowercase())
    }

    // Gets a config value for the given key.
    private fun get(key: String): String? {
        val value = configs[key] ?: defaults[key] ?: return null
        return value.toString()
    }

    // Ensures the necessary directory and file exist.
    private fun ensureLocalStoreExists() {
        if (!remoteConfigDirectory.exists()) {
            remoteConfigDirectory.mkdirs()
        } else {
            if (!remoteConfigDirectory.isDirectory) {
                remoteConfigDirectory.delete(); remoteConfigDirectory.mkdirs()
            }
        }

        if (!remoteConfigFile.exists()) {
            remoteConfigFile.createNewFile()
        } else {
            if (!remoteConfigFile.isFile) {
                remoteConfigFile.delete(); remoteConfigFile.createNewFile()
            }
        }
    }

    // Fetches configs from the server.
    private suspend fun fetch(): SourceType {
        val savedConfigs = loadSavedConfigs()
        if (isCacheValid() && savedConfigs.isNotEmpty()) {
            configs = savedConfigs
            return SourceType.CACHE
        }

        val databases = Databases(client)

        val maxItemsPerPage = 25
        var documentsQuery = arrayOf(Query.limit(maxItemsPerPage))
        val documentMappings: MutableMap<String, String> = mutableMapOf()

        try {
            while (true) {
                val documentsList = databases.listDocuments(
                    databaseId, collectionId, queries = documentsQuery.toList()
                )

                val documents = documentsList.documents
                if (documents.isEmpty()) break

                for (document in documents) {
                    val key = document.data[keyAttribute]!!.toString()
                    val value = document.data[valueAttribute]!!.toString()
                    documentMappings[key] = value
                }

                if (documents.size < maxItemsPerPage) break

                val lastId = documents[documents.size - 1].id
                documentsQuery = arrayOf(Query.limit(maxItemsPerPage), Query.cursorAfter(lastId))
            }

            if (documentMappings.isEmpty()) {
                Log.d(tag, "No documents exist for RemoteConfig!")

                val storedConfigs = loadSavedConfigs()
                return if (storedConfigs.isNotEmpty()) {
                    configs = storedConfigs; SourceType.CACHE
                } else {
                    configs = defaults; SourceType.DEFAULTS
                }
            }

            configs = documentMappings
            saveToDisk(documentMappings)
            return SourceType.NETWORK
        } catch (exception: Exception) {
            configs = loadSavedConfigs().ifEmpty { defaults }
            return SourceType.FAILURE(exception)
        }
    }

    // Determines if we should use cached configs.
    private fun isCacheValid(): Boolean {
        val difference = System.currentTimeMillis() - lastFetchedTime
        return difference <= (cacheLimitInHours * 3600 * 1000L)
    }

    // Saves configs to disk.
    private fun saveToDisk(configs: Map<String, Any>) {
        remoteConfigFile.writeText(configs.toJson())
        sharedPreferences.edit().putLong(lastFetchedTimeKey, System.currentTimeMillis()).apply()
    }

    // Loads configs from disk if they exist.
    private fun loadSavedConfigs(): Map<String, String> {
        val dataMappings = mutableMapOf<String, String>()

        val fileContents = remoteConfigFile.readText()
        if (fileContents.isEmpty()) return dataMappings

        val jsonObject = JSONObject(fileContents)
        if (jsonObject.length() == 0) return dataMappings

        for (key in jsonObject.keys()) {
            dataMappings[key] = jsonObject.get(key).toString()
        }

        return dataMappings
    }

    companion object {
        // Constants
        private const val DEFAULT_INT_VALUE = 0
        private const val DEFAULT_STRING_VALUE = ""
        private const val DEFAULT_BOOL_VALUE = false
        private const val tag = "AppwriteRemoteConfig"

        @Volatile
        private var INSTANCE: AppwriteRemoteConfig? = null

        /**
         * Retrieves the singleton instance of [AppwriteRemoteConfig].
         *
         * @param context The context required for initializing [AppwriteRemoteConfig].
         * @return The singleton instance of [AppwriteRemoteConfig].
         */
        @JvmStatic
        fun getInstance(context: Context): AppwriteRemoteConfig {
            return INSTANCE ?: synchronized(this) {
                val instance = AppwriteRemoteConfig(context)
                INSTANCE = instance
                instance
            }
        }
    }
}