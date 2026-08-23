import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/viewmodels/split_viewmodel.dart';

void main() {
  group('SplitViewModel.extractSplitDescription', () {
    test('extracts description from standard split transaction description', () {
      expect(
        SplitViewModel.extractSplitDescription('Split: Dinner (Alice, Bob)'),
        'Dinner',
      );
      expect(
        SplitViewModel.extractSplitDescription('Split: Team Lunch (Charlie)'),
        'Team Lunch',
      );
      expect(
        SplitViewModel.extractSplitDescription('Split: Grocery'),
        'Grocery',
      );
      expect(
        SplitViewModel.extractSplitDescription('split: Movie tickets (Dave)'),
        'Movie tickets',
      );
    });

    test('handles descriptions without Split prefix or partner suffixes', () {
      expect(
        SplitViewModel.extractSplitDescription('Dinner with friends'),
        'Dinner with friends',
      );
      expect(
        SplitViewModel.extractSplitDescription(''),
        '',
      );
    });
  });
}
