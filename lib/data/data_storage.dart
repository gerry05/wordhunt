import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wordhunt/globals.dart' as globals;

class DataStorage {
  final storage = const FlutterSecureStorage();

  Future<void> gameStoreWords(List<String> words) async {
    try {
      await storage.write(key: 'storeWordsFound', value: words.join(','));
      debugPrint("Words stored successfully.");
    } catch (e) {
      debugPrint("Error storing words: $e");
    }
  }

  Future<List<String>> gameGetWords() async {
    try {
      final words = await storage.read(key: 'storeWordsFound');
      debugPrint("Words retrieved successfully.: $words");
      if (words == null) {
        globals.storeWordsFound = [];
        return [];
      }
      globals.storeWordsFound = words.split(',');
      return globals.storeWordsFound;
    } catch (e) {
      debugPrint("Error retrieving words: $e");
      return [];
    }
  }
}
