import 'package:flutter_bloc/flutter_bloc.dart';

/// Searches made in this session, newest first (in-memory; persistence arrives with the profile storage).
class RecentSearchesCubit extends Cubit<List<String>> {
  RecentSearchesCubit() : super(const []);

  static const maxItems = 5;

  void record(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ...state.where((e) => e.toLowerCase() != q.toLowerCase())];
    emit(next.take(maxItems).toList());
  }

  void clear() => emit(const []);
}
