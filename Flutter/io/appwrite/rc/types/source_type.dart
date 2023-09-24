/// Represents the source of the configuration values fetched.
class SourceType {
  final String _type;
  final Error? error;

  SourceType._(this._type, {this.error});

  /// Configuration values were sourced from the cache.
  factory SourceType.cache() => SourceType._("cache");

  /// Configuration values were sourced from a network request.
  factory SourceType.network() => SourceType._("network");

  /// Configuration values were sourced from the app's default values.
  factory SourceType.defaults() => SourceType._("defaults");

  /// An error occurred while attempting to fetch configuration values.
  factory SourceType.failure(Error error) => SourceType._("failure", error: error);

  @override
  String toString() {
    if (_type == "Failure") {
      return '$_type: $error';
    }

    return _type;
  }
}
