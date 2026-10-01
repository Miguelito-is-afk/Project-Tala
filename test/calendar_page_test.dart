import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/pages/calendar_page.dart';

void main() {
  test('keeps the selected day when changing to a month that contains it', () {
    final result = calendarSelectionForMonth(
      DateTime(2026, 5),
      DateTime(2026, 5, 15),
      1,
    );

    expect(result, DateTime(2026, 6, 15));
  });

  test('clamps the selected day to the last day of the target month', () {
    final result = calendarSelectionForMonth(
      DateTime(2026, 1),
      DateTime(2026, 1, 31),
      1,
    );

    expect(result, DateTime(2026, 2, 28));
  });

  test('handles month changes across years', () {
    final result = calendarSelectionForMonth(
      DateTime(2026, 1),
      DateTime(2026, 1, 31),
      -1,
    );

    expect(result, DateTime(2025, 12, 31));
  });
}
