import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Theme preference: follow the system by default. Kept in memory (not persisted yet).
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  void select(ThemeMode mode) => emit(mode);
}
