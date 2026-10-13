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
