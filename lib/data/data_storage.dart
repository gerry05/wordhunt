import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wordhunt/globals.dart' as globals;
import '../config/secrets.dart';

class DataStorage {
  final storage = const FlutterSecureStorage();

  Future<void> storeKey() async {
    try {
      await storage.write(
        key: 'gemini_api_key',
        value: Secrets.geminiApiKey,
      );
      debugPrint("API key stored successfully.");
    } catch (e) {
      debugPrint("Error storing API key: $e");
    }
  }

  Future<String?> getApiKey() async {
    try {
      return await storage.read(key: 'gemini_api_key');
    } catch (e) {
      debugPrint("Error retrieving API key: $e");
      return null;
    }
  }

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
      globals.storeWordsFound = words!.split(',');
      return words.split(',');
    } catch (e) {
      debugPrint("Error retrieving words: $e");
      return [];
    }
  }
}
