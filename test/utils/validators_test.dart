import 'package:budget/utils/validators.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

void main() {
  group('Input validation', () {
    group('Amount validator', () {
      late AmountValidator validator;
      late AmountValidator noZeroValidator;

      setUp(() {
        validator = const AmountValidator(allowZero: true);
        noZeroValidator = const AmountValidator(allowZero: false);
      });

      test('amount validator rejects null amount', () {
        final String? result = validator.validateAmount(null);

        expect(result, 'Please enter an amount');
      });

      test('amount validator rejects empty string', () {
        final String? result = validator.validateAmount('');

        expect(result, 'Please enter a valid amount');
      });

      test('amount validator rejects negative amounts', () {
        final String? result = validator.validateAmount('-1');

        expect(result, 'Please enter a positive amount');
      });

      test('amount validator rejects a very large amount', () {
        final String? result = validator.validateAmount('100000000000000000');

        expect(result, 'No way you have that much money');
      });

      test('amount validator rejects zero when allowZero is false', () {
        final String? result = noZeroValidator.validateAmount('0');

        expect(result, 'Please enter a valid amount');
      });

      test('amount validator accepts positive amounts', () {
        final String? result = validator.validateAmount('100');

        expect(result, isNull);
      });

      test('amount validator accepts zero when allowZero is true', () {
        final String? result = validator.validateAmount('0');

        expect(result, isNull);
      });
    });

    group('Email validator', () {
      test('email validator rejects null email', () {
        final String? result = validateEmail(null);

        expect(result, 'Required');
      });

      test('email validator rejects email without @', () {
        final String? result = validateEmail('test');

        expect(result, 'Invalid email address');
      });

      test('email validator rejects email without username', () {
        final String? result = validateEmail('@test.com');

        expect(result, 'Invalid email address');
      });

      test('email validator rejects email when its domain has no TLD', () {
        final String? result = validateEmail('test@test');

        expect(result, 'Invalid email address');
      });

      test(
        'email validator rejects email when its domain has a dot but no TLD',
        () {
          final String? result = validateEmail('test@test.');

          expect(result, 'Invalid email address');
        },
      );

      test('email validator rejects email when its domain is only TLD', () {
        final String? result = validateEmail('.com');

        expect(result, 'Invalid email address');
      });

      test(
        'email validator rejects email when it consists of only @ and TLD',
        () {
          final String? result = validateEmail('@.com');

          expect(result, 'Invalid email address');
        },
      );

      test('email validator accepts an email address', () {
        final String? result = validateEmail('test@test.com');

        expect(result, null);
      });
    });

    group('Title validator', () {
      test('title validator rejects null input', () {
        final String? result = validateTitle(null);

        expect(result, 'Please enter a title');
      });

      test('title validator rejects empty string input', () {
        final String? result = validateTitle('');

        expect(result, 'Please enter a title');
      });

      test('title validator rejects string that is too long', () {
        final String? result = validateTitle(
          'this is a string that is more than fifty characters long',
        );

        expect(result, 'Title must be less than 50 characters');
      });

      test('title validator accepts string that is exactly 50 characters', () {
        final String? result = validateTitle(
          'this is a title that is exactly 50 characters long',
        );

        expect(result, isNull);
      });

      test('title validator accepts string that is under 50 characters', () {
        final String? result = validateTitle('Comfortable title');

        expect(result, isNull);
      });
    });
  });

  group('Input formatting', () {
    group('Amount formatter', () {
      test('default formats zero as 0.00', () {
        final String result = formatAmount(0);

        expect(result, '0.00');
      });

      test('default formats integer as x.00', () {
        final String result = formatAmount(1);

        expect(result, '1.00');
      });

      test('default formats decimal and integer as x.xx', () {
        final String result = formatAmount(1.55);

        expect(result, '1.55');
      });

      test('default formats decimal only as 0.xx', () {
        final String result = formatAmount(0.55);

        expect(result, '0.55');
      });

      test('default rounds amounts with precision > 2', () {
        final String result = formatAmount(1.548);

        expect(result, '1.55');
      });

      test('round=true formats small doubles as int', () {
        final String result = formatAmount(1.5, round: true);

        expect(result, '2');
      });

      test('round=true formats numbers <0.5 as 0', () {
        final String result = formatAmount(0.45, round: true);

        expect(result, '0');
      });

      test('default formats numbers in the thousands with K', () {
        final String result = formatAmount(1000);

        expect(result, '1.00K');
      });

      test('default formats numbers in the millions with M', () {
        final String result = formatAmount(1_000_000);

        expect(result, '1.00M');
      });

      test('default formats numbers in the billions with B', () {
        final String result = formatAmount(1_000_000_000);

        expect(result, '1.00B');
      });

      test('default properly rounds large numbers', () {
        final String result = formatAmount(2345);

        expect(result, '2.35K');
      });

      test('round=true formats large numbers as integers', () {
        final String result = formatAmount(1000, round: true);

        expect(result, '1K');
      });

      test('round=true properly rounds large numbers', () {
        final String result = formatAmount(2500, round: true);

        expect(result, '3K');
      });

      test('exact=true does\'nt truncate large numbers', () {
        final String result = formatAmount(1000, exact: true);

        expect(result, '1,000.00');
      });

      test(
        'exact=true and round=true rounds decimal places but doesn\'t truncate large numbers',
        () {
          final String result = formatAmount(999.51, exact: true, round: true);

          expect(result, '1,000');
        },
      );
    });

    group('Decimal text input formatter', () {
      late DecimalTextInputFormatter formatter;

      String formatText(String oldValue, String newValue) {
        return formatter
            .formatEditUpdate(
              TextEditingValue(text: oldValue),
              TextEditingValue(text: newValue),
            )
            .text;
      }

      setUp(() => formatter = DecimalTextInputFormatter());

      test('value can\'t have more than two decimal places', () {
        final String value = formatText('0.00', '0.000');

        expect(value, '0.00');
      });

      test('value can\'t have decimal place with no leading digit', () {
        final String value = formatText('0.00', '.00');

        expect(value, '0.00');
      });

      test('value can\'t contain non-number characters other than dot', () {
        final String value = formatText('', 'f');

        expect(value, '');
      });
    });
  });
}
