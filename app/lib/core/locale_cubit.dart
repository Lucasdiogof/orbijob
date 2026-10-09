import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Language override: null follows the device. The choice is also kept in the account when signed in.
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit() : super(null);

  static const supported = ['pt', 'en', 'es'];

  void select(String? code) =>
      emit(supported.contains(code) ? Locale(code!) : null);
}
