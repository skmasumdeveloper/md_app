// This file contains a utility class to check if a given string is a valid website URL.
class CheckWebsite {
  final urlPattern =
      r'^(https?:\/\/)?([a-zA-Z0-9\-]+\.)+[a-zA-Z]{2,}(:\d+)?(\/.*)?$';

  bool isWebsite(String text) {
    final regex = RegExp(urlPattern, caseSensitive: false);
    return regex.hasMatch(text);
  }
}
