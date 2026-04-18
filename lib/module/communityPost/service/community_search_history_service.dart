import 'package:shared_preferences/shared_preferences.dart';

class CommunitySearchHistoryService {
  static const String _historyKey = 'community_post_search_history';
  static const int _maxHistoryLength = 10;

  /// Saves a new search query to the local history.
  static Future<void> saveSearchQuery(String query) async {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];

    // Remove the query if it already exists to prevent duplicates and to bring it to the top of the list.
    history.remove(trimmedQuery);

    // Insert the latest search at the very beginning of the list.
    history.insert(0, trimmedQuery);

    // If the history exceeds the maximum allowed length, truncate the older entries.
    if (history.length > _maxHistoryLength) {
      history = history.sublist(0, _maxHistoryLength);
    }

    // Save the updated list back to local storage.
    await prefs.setStringList(_historyKey, history);
  }

  static Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  /// Useful for when a user clicks the "x" next to an individual history item.
  static Future<void> removeSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    history.remove(query);
    await prefs.setStringList(_historyKey, history);
  }

  /// Clears the entire search history from local storage.
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}