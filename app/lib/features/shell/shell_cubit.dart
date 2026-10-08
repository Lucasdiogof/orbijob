import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShellState extends Equatable {
  const ShellState({this.index = 0, this.searchFocusTick = 0});
  final int index;

  /// Incremented when something (e.g. the Home search field) asks Explore to focus its field.
  final int searchFocusTick;

  @override
  List<Object?> get props => [index, searchFocusTick];
}

class ShellCubit extends Cubit<ShellState> {
  ShellCubit() : super(const ShellState());

  static const int home = 0;
  static const int explore = 1;
  static const int favorites = 2;
  static const int applications = 3;

  void goTo(int index) =>
      emit(ShellState(index: index, searchFocusTick: state.searchFocusTick));
  void openSearch() => emit(
    ShellState(index: explore, searchFocusTick: state.searchFocusTick + 1),
  );
}
