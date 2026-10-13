import 'package:equatable/equatable.dart';

import 'search_spec.dart';

/// How often the database looks for new jobs for a search: every hour, once a day or once a week.
enum AlertFrequency {
  instant,
  daily,
  weekly;

  static AlertFrequency parse(Object? v) => AlertFrequency.values.firstWhere(
    (f) => f.name == v,
    orElse: () => AlertFrequency.daily,
  );
}

/// A search the person keeps in their account, with its alert settings. [query] is the stored JSON (see [SearchSpec]).
class SavedSearch extends Equatable {
  const SavedSearch({
    required this.id,
    required this.query,
    this.name,
    this.alertsEnabled = false,
    this.frequency = AlertFrequency.daily,
    this.createdAt,
  });

  final String id;
  final Map<String, dynamic> query;

  /// What the person called it; null for searches saved before names existed.
  final String? name;
  final bool alertsEnabled;
  final AlertFrequency frequency;
  final DateTime? createdAt;

  SearchSpec get spec => SearchSpec.fromQuery(query);

  SavedSearch copyWith({
    Map<String, dynamic>? query,
    String? name,
    bool? alertsEnabled,
    AlertFrequency? frequency,
  }) => SavedSearch(
    id: id,
    query: query ?? this.query,
    name: name ?? this.name,
    alertsEnabled: alertsEnabled ?? this.alertsEnabled,
    frequency: frequency ?? this.frequency,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    query,
    name,
    alertsEnabled,
    frequency,
    createdAt,
  ];
}

abstract class SavedSearchesRepository {
  Future<List<SavedSearch>> list();
  Future<SavedSearch> add(
    Map<String, dynamic> query, {
    String? name,
    bool alertsEnabled = false,
    AlertFrequency frequency = AlertFrequency.daily,
  });

  /// Changes only what is given.
  Future<SavedSearch> update(
    String id, {
    String? name,
    Map<String, dynamic>? query,
    bool? alertsEnabled,
    AlertFrequency? frequency,
  });
  Future<void> remove(String id);
}
