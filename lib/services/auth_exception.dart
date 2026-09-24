class AuthException implements Exception {
  final String message;
  final bool pinRegenerated;

  AuthException(this.message, {this.pinRegenerated = false});

  @override
  String toString() => message;
}
