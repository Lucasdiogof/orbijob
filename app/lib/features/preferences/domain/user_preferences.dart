import 'package:equatable/equatable.dart';

class UserPreferences extends Equatable {
  const UserPreferences({
    this.theme = 'system',
    this.locale,
    this.countriesOfInterest = const [],
  });

  /// `system` | `light` | `dark` (matches the `user_preferences.theme` check constraint).
  final String theme;

  /// `pt` | `en` | `es`, or null to follow the device.
  final String? locale;
  final List<String> countriesOfInterest;

  @override
  List<Object?> get props => [theme, locale, countriesOfInterest];
}

abstract class PreferencesRepository {
  /// Defaults when the user has not saved anything yet.
  Future<UserPreferences> load();
  Future<void> save(UserPreferences p);
}

/// A saved search: the query is stored as an opaque JSON map (term, country, filters).
class SavedSearch extends Equatable {
  const SavedSearch({required this.id, required this.query});
  final String id;
  final Map<String, dynamic> query;
  @override
  List<Object?> get props => [id, query];
}

abstract class SavedSearchesRepository {
  Future<List<SavedSearch>> list();
  Future<SavedSearch> add(Map<String, dynamic> query);
  Future<void> remove(String id);
}
