class AppException implements Exception {
  AppException(this.message, {this.code, this.detail});

  final String message;
  final String? code;
  final String? detail;

  @override
  String toString() => message;
}
