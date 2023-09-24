import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'types/source_type.dart';

/// `AppwriteRemoteConfig` is a utility class designed to fetch, cache, and
/// manage remote configuration settings from `appwrite`.
///
/// It provides functionalities similar to **Firebase's RemoteConfig**,
/// allowing the app to fetch configurations from an appwrite collection,
/// cache them locally, or apply default configurations when necessary.
///
/// Use the singleton instance `await AppwriteRemoteConfig.instance` to
/// access the methods.
class AppwriteRemoteConfig {
  /// Client to get Databases & use Realtime!
  Client? _client;

  // Collection Id of the documents
  String _collectionId = "release";

  // Database Id of the collection
  String _databaseId = "remote_config";

  /// Default attribute name for `key`
  String _keyAttribute = "key";

  /// Default attribute name for `value`
  String _valueAttribute = "value";

  int _lastFetchedTime = -1;
  int _cacheLimitInHours = 24;
  Map<String, dynamic> _configs = {};
  Map<String, dynamic> _defaults = {};

  late SharedPreferences _preferences;
  String _lastFetchedTimeKey = "appwriteRemoteConfigLastFetchTime";

  // Files & Directories
  late File _remoteConfigFile;
  late Directory _remoteConfigDirectory;

  AppwriteRemoteConfig._();

  /// Set the appwrite `Client` for creating `Databases` instance,
  /// or accessing `Realtime`.
  void setClient(Client client) {
    this._client = client;
  }

  /// Sets the default configurations to be used when fetched configurations are not available.
  void setDefaults(Map<String, dynamic> defaults) {
    this._defaults = defaults;
  }

  /// Set the `databaseId` & `collectionId` of your remote config documents
  void setDatabaseAndCollectionIds(String databaseId, String collectionId) {
    this._databaseId = databaseId;
    this._collectionId = collectionId;
  }

  /// Set the `keyAttribute` & `valueAttribute` to use while extracting the data from documents.
  void setKeyAndValueAttributeIds(
      String keyAttribute, String valueAttribute) {
    this._keyAttribute = keyAttribute;
    this._valueAttribute = valueAttribute;
  }

  /// Configures the maximum duration for which fetched configurations are considered valid.
  void setCacheLimit(int hours) {
    this._cacheLimitInHours = hours;
  }

  /// Fetches the remote configurations and activates them.
  void fetchAndActivate(Function(SourceType)? callback) async {
    _ensureClientInitialized();

    _fetch()
        .then((sourceType) => callback?.call(sourceType))
        .catchError((error) => callback?.call(SourceType.failure(error)));
  }

  /// Subscribes for real-time updates on a remote config documents.
  ///
  /// If you return `true` from callback, the new or updated configs are saved to disk.
  ///
  /// **Note: Remember to close this subscription when done!**
  RealtimeSubscription addOnConfigUpdateListener({
    Realtime? realtime,
    required bool Function(String, dynamic) callback,
  }) {
    _ensureClientInitialized();

    final realtimeInstance = realtime ?? Realtime(_client!);
    final channel =
        "databases.$_databaseId.collections.$_collectionId.documents";
    final subscription = realtimeInstance.subscribe([channel]);
    subscription.stream.listen((result) {
      // first element contains the full event, atleast on 1.4x
      final event = result.events.first;
      final payload = result.payload;
      if (payload.containsKey(_keyAttribute) &&
          payload.containsKey(_valueAttribute)) {
        final key = payload[_keyAttribute].toString();
        final value = payload[_valueAttribute].toString();

        if (event.contains("delete")) {
          _configs.remove(key);
          _saveToDisk(_configs);
          print("$tag: Removed `$key` from configs!");
        } else {
          // update or create a new key, value pair!
          if (callback.call(key, value)) {
            print("$tag: Saving updated configs to disk...");

            _configs[key] = value;
            _saveToDisk(_configs);
            print("$tag: Updated configs successfully saved to disk!");
          }
        }
      }
    });

    return subscription;
  }

  /// Returns the current configurations being used by the `AppwriteRemoteConfig`.
  Map<String, dynamic> getCurrentConfigs() => _configs;

  /// Retrieves a configuration value as a string for the given [key].
  String getString(String key) {
    return _get(key) ?? DEFAULT_STRING_VALUE;
  }

  /// Retrieves a configuration value as a int for the given [key].
  int getInt(String key) {
    return int.tryParse(_get(key) ?? "$DEFAULT_INT_VALUE") ?? DEFAULT_INT_VALUE;
  }

  /// Retrieves a configuration value as a bool for the given [key].
  bool getBool(String key) {
    final value = _get(key);
    if (value == null) return DEFAULT_BOOL_VALUE;
    final truthyStrings = {
      "t",
      "true",
      "y",
      "yes",
      "1",
      "enable",
      "enabled",
      "on",
      "active"
    };
    return truthyStrings.contains(value.toLowerCase());
  }

  /// Private methods

  /// Gets a config value for the given [key].
  String? _get(String key) {
    final value = _configs[key] ?? _defaults[key] ?? null;
    if (value == null) {
      return null;
    } else {
      return value.toString();
    }
  }

  /// Ensures that the Client instance is set!
  void _ensureClientInitialized() {
    if (_client == null) {
      throw Exception(
          "Client is null, use `setClient` before using any AppwriteRemoteConfig API!");
    }
  }

  /// Ensures the necessary directory and file exist.
  Future<void> _ensureLocalStoreExists() async {
    final directory = await getApplicationDocumentsDirectory();
    final directoryPath = '${directory.path}/remoteConfigs';

    _remoteConfigDirectory = Directory(directoryPath);
    _remoteConfigFile = File('$directoryPath/appwrite_rc_network.json');

    if (!_remoteConfigDirectory.existsSync()) {
      _remoteConfigDirectory.createSync(recursive: true);
    } else {
      final commonFile = File(directoryPath);
      final fileStat = commonFile.statSync();
      if (fileStat.type != FileSystemEntityType.directory) {
        commonFile.deleteSync();
        _remoteConfigDirectory.createSync(recursive: true);
      }
    }

    if (!_remoteConfigFile.existsSync()) {
      _remoteConfigFile.createSync(recursive: true);
    } else {
      final fileStat = _remoteConfigFile.statSync();
      if (fileStat.type != FileSystemEntityType.file) {
        _remoteConfigFile.deleteSync();
        _remoteConfigFile.createSync(recursive: true);
      }
    }
  }

  /// Initializes the [SharedPreferences] instance.
  Future<void> _initSharedPreferences() async {
    /// Use `secure_shared_preferences` library if you want encryption.
    _preferences = await SharedPreferences.getInstance();
    final savedTime = _preferences.getInt(_lastFetchedTimeKey);
    _lastFetchedTime = savedTime ?? _date();
  }

  /// Fetches configs from the server.
  Future<SourceType> _fetch() async {
    final savedConfigs = await _loadSavedConfigs();
    if (_isCacheValid() && savedConfigs.isNotEmpty) {
      _configs = savedConfigs;
      return SourceType.cache();
    }

    final databases = Databases(_client!);

    final maxItemsPerPage = 25;
    var documentsQuery = [Query.limit(maxItemsPerPage)];
    final Map<String, String> documentMappings = Map();

    try {
      while (true) {
        final documentsList = await databases.listDocuments(
          databaseId: _databaseId,
          collectionId: _collectionId,
          queries: documentsQuery,
        );

        final documents = documentsList.documents;
        if (documents.isEmpty) break;

        for (final document in documents) {
          final key = document.data[_keyAttribute]!.toString();
          final value = document.data[_valueAttribute]!.toString();
          documentMappings[key] = value;
        }

        if (documents.length < maxItemsPerPage) break;

        final lastId = documents[documents.length - 1].$id;
        documentsQuery = [
          Query.limit(maxItemsPerPage),
          Query.cursorAfter(lastId)
        ];
      }

      if (documentMappings.isEmpty) {
        print("$tag: No documents exist for RemoteConfig!");

        final storedConfigs = await _loadSavedConfigs();
        if (storedConfigs.isNotEmpty) {
          _configs = storedConfigs;
          return SourceType.cache();
        } else {
          _configs = _defaults;
          return SourceType.defaults();
        }
      }

      _configs = documentMappings;
      _saveToDisk(documentMappings);
      return SourceType.network();
    } on Error catch (error) {
      _configs = await _loadSavedConfigs();
      if (_configs.isEmpty) _configs = _defaults;
      return SourceType.failure(error);
    }
  }

  /// Determines if we should use cached configs.
  bool _isCacheValid() {
    int currentTimestamp = _date();
    int difference = currentTimestamp - _lastFetchedTime;
    return difference <= _cacheLimitInHours * 3600 * 1000;
  }

  /// Saves configs to disk.
  void _saveToDisk(Map<String, dynamic> data) {
    Future.sync(() async {
      await _remoteConfigFile.writeAsString(jsonEncode(data));
      await _preferences.setInt(_lastFetchedTimeKey, _date());
    });
  }

  /// Loads configs from disk if they exist.
  Future<Map<String, String>> _loadSavedConfigs() async {
    final dataMappings = Map<String, String>();

    final fileContents = await _remoteConfigFile.readAsString();
    if (fileContents.isEmpty) return dataMappings;

    final jsonObject = jsonDecode(fileContents);
    if (jsonObject.length == 0) return dataMappings;

    for (final key in jsonObject.keys) {
      dataMappings[key] = jsonObject[key].toString();
    }

    return dataMappings;
  }

  /// Returns the date since epoch in milliseconds.
  int _date() {
    final dateTime = DateTime.now();
    return dateTime.millisecondsSinceEpoch;
  }

  // Constants
  static const DEFAULT_INT_VALUE = 0;

  static const DEFAULT_STRING_VALUE = "";

  static const DEFAULT_BOOL_VALUE = false;

  static const tag = "AppwriteRemoteConfig";

  /// Static instance
  static AppwriteRemoteConfig _instance = AppwriteRemoteConfig._();

  static Future<AppwriteRemoteConfig> get instance async {
    await _instance._initSharedPreferences();
    await _instance._ensureLocalStoreExists();
    return _instance;
  }
}
