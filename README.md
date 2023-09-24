# `AppwriteRemoteConfig` 🚀
A Firebase RemoteConfig like solution for `appwrite`!

## Features  🌟
1. **Fetching and Caching**
Seamlessly fetch configurations from an Appwrite, cache & store them locally!

2. **Default Configurations**
Set default configurations that your app can fall back on in the absence of fetched configurations or when offline.

3. **Realtime Updates**
Observe changes to your RemoteConfig collection in realtime using Appwrite's Realtime capabilities.

4. **Drop In Replacement [Almost]**
The API is designed to be familiar to those who have used Firebase RemoteConfig.

## Getting Started 🛠
1. **Database**: Create a Database, name it as you want & set an ID.
Recommended ID: `remote_config` (configurable in the api).

2. **Collection**: Create a Collection, name it as you want & set an ID.
Recommended ID: `release` (configurable in the api).

3. **Attributes**: Create 2 attributes as `key`, `value` pattern.
Recommended: `key: String` & `value: String` (configurable in the api).
Ensure the size of the value attribute is sufficient, especially if you plan to store URLs or other long strings. I'd advise using a size of 1024 as a precaution.

## Usage 🔧
Explore the platform-specific directories (Android, iOS, Flutter) to get an insight into the `API` and its integration into your project.