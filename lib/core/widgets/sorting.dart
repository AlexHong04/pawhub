class SortUtils {
  /// Generic sorter for ANY field
  static List<Map<String, dynamic>> sort(
      List<Map<String, dynamic>> items, {
        required String by,
        bool ascending = true,
      }) {
    final sorted = List<Map<String, dynamic>>.from(items);

    sorted.sort((a, b) {
      final aValue = a[by];
      final bValue = b[by];

      // NULL safety
      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return 1;
      if (bValue == null) return -1;

      // NUMBER sorting
      if (aValue is num && bValue is num) {
        return ascending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      }

      // DATE sorting (ISO string)
      if (aValue is String && bValue is String) {
        final aDate = DateTime.tryParse(aValue);
        final bDate = DateTime.tryParse(bValue);

        if (aDate != null && bDate != null) {
          return ascending
              ? aDate.compareTo(bDate)
              : bDate.compareTo(aDate);
        }

        // STRING sorting fallback
        return ascending
            ? aValue.toLowerCase().compareTo(bValue.toLowerCase())
            : bValue.toLowerCase().compareTo(aValue.toLowerCase());
      }

      // fallback safe compare
      return 0;
    });

    return sorted;
  }
}
