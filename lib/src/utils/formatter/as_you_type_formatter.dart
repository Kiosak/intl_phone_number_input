import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_number_input/src/utils/phone_number/phone_number_util.dart';

typedef OnInputFormatted<T> = void Function(T value);

/// [AsYouTypeFormatter] is a custom formatter that extends [TextInputFormatter]
/// which provides as you type validation and formatting for phone number inputted.
class AsYouTypeFormatter extends TextInputFormatter {
  /// Contains characters allowed as seperators.
  final RegExp separatorChars = RegExp(r'[^\d]+');

  /// The [allowedChars] contains [RegExp] for allowable phone number characters.
  final RegExp allowedChars = RegExp(r'[\d+]');

  /// The [isoCode] of the [Country] formatting the phone number to
  final String isoCode;

  /// The [dialCode] of the [Country] formatting the phone number to
  final String dialCode;

  /// [onInputFormatted] is a callback that passes the formatted phone number
  final OnInputFormatted<TextEditingValue> onInputFormatted;

  AsYouTypeFormatter(
      {@required this.isoCode,
      @required this.dialCode,
      @required this.onInputFormatted})
      : assert(isoCode != null),
        assert(dialCode != null);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    int oldValueLength = oldValue.text.length;
    int newValueLength = newValue.text.length;

    if (newValueLength > 0 && newValueLength > oldValueLength) {
      String newValueText = newValue.text;
      String rawText = newValueText.replaceAll(separatorChars, '');
      String textToParse = dialCode + rawText;

      final insertedDigits = newValueText
          .substring(
              oldValue.selection.start == -1 ? 0 : oldValue.selection.start,
              newValue.selection.end == -1 ? 0 : newValue.selection.end)
          .replaceAll(separatorChars, '');

      formatAsYouType(input: textToParse).then(
        (String value) {
          String parsedText = parsePhoneNumber(value);

          int offset =
              oldValue.selection.start == -1 ? 0 : oldValue.selection.start;
          for (int digitIndex = 0;
              digitIndex < insertedDigits.length && offset < parsedText.length;
              ++offset) {
            final insertedDigit = insertedDigits[digitIndex];
            final parsedChar = parsedText[offset];
            if (parsedChar == insertedDigit) {
              ++digitIndex;
            }
          }

          if (separatorChars.hasMatch(parsedText)) {
            this.onInputFormatted(
              TextEditingValue(
                text: parsedText,
                selection: TextSelection.collapsed(offset: offset),
              ),
            );
          }
        },
      );
    }
    return newValue;
  }

  /// Accepts [input], unformatted phone number and
  /// returns a [Future<String>] of the formatted phone number.
  Future<String> formatAsYouType({@required String input}) async {
    try {
      String formattedPhoneNumber = await PhoneNumberUtil.formatAsYouType(
          phoneNumber: input, isoCode: isoCode);
      return formattedPhoneNumber;
    } on Exception {
      return '';
    }
  }

  String parsePhoneNumber(String phoneNumber) {
    if (dialCode.length > 4) {
      if (isPartOfNorthAmericanNumberingPlan(dialCode)) {
        String northAmericaDialCode = '+1';
        String countryDialCodeWithSpace = northAmericaDialCode +
            ' ' +
            dialCode.replaceFirst(northAmericaDialCode, '');

        return phoneNumber
            .replaceFirst(countryDialCodeWithSpace, '')
            .replaceFirst(separatorChars, '')
            .trim();
      }
    }
    return phoneNumber.replaceFirst(dialCode, '').trim();
  }

  bool isPartOfNorthAmericanNumberingPlan(String dialCode) {
    return dialCode.contains('+1');
  }
}
