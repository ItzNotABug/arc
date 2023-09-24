//
//  SourceType.swift
//  AppwriteRemoteConfig
//
//  Created by Darshan Pandya (@itznotabug) on 06/09/23.
//

/// Represents the source of the configuration values fetched.
public enum SourceType {
    /// Configuration values were sourced from the cache.
    case cache
    
    /// Configuration values were sourced from a network request.
    case network
    
    /// Configuration values were sourced from the app's default values.
    case defaults
    
    /// An error occurred while attempting to fetch configuration values.
    case failure(Error)
}
