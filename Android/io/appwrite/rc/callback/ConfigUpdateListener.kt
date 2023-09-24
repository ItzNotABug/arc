package io.appwrite.rc.callback

/**
 * A listener interface for receiving configuration update events.
 *
 * Implementations of this interface can be registered to be notified when a configuration
 * update occurs, providing the updated configuration key-value pair.
 */
interface ConfigUpdateListener {

    /**
     * Called when a configuration is updated.
     *
     * @param updatedConfig A pair representing the updated configuration.
     * The first value of the pair is the configuration key, and the second value is the value.
     *
     * @return `true` to persist the latest change to disk, false otherwise.
     */
    fun onConfigUpdate(updatedConfig: Pair<String, Any>): Boolean
}