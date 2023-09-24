package io.appwrite.rc.types

/**
 * Represents the source of the configuration values fetched.
 */
sealed class SourceType(val type: String) {
    /** Configuration values were sourced from the cache. */
    object CACHE : SourceType("cache")

    /** Configuration values were sourced from a network request. */
    object NETWORK : SourceType("network")

    /** Configuration values were sourced from the app's default values. */
    object DEFAULTS : SourceType("defaults")

    /** An error occurred while attempting to fetch configuration values. */
    class FAILURE(val exception: Exception) : SourceType("failure")
}