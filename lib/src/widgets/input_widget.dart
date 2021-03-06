import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_number_input/src/models/country_list.dart';
import 'package:intl_phone_number_input/src/models/country_model.dart';
import 'package:intl_phone_number_input/src/providers/country_provider.dart';
import 'package:intl_phone_number_input/src/utils/formatter/as_you_type_formatter.dart';
import 'package:intl_phone_number_input/src/utils/phone_number.dart';
import 'package:intl_phone_number_input/src/utils/phone_number/phone_number_util.dart';
import 'package:intl_phone_number_input/src/utils/selector_config.dart';
import 'package:intl_phone_number_input/src/utils/test/test_helper.dart';
import 'package:intl_phone_number_input/src/utils/util.dart';
import 'package:intl_phone_number_input/src/utils/widget_view.dart';
import 'package:intl_phone_number_input/src/widgets/selector_button.dart';

/// Enum for [SelectorButton] types.
///
/// Available type includes:
///   * [PhoneInputSelectorType.DROPDOWN]
///   * [PhoneInputSelectorType.BOTTOM_SHEET]
///   * [PhoneInputSelectorType.DIALOG]
enum PhoneInputSelectorType { DROPDOWN, BOTTOM_SHEET, DIALOG }

/// A [TextFormField] for [InternationalPhoneNumberInput].
///
/// [initialValue] accepts a [PhoneNumber] this is used to set initial values
/// for phone the input field and the selector button
///
/// [selectorButtonOnErrorPadding] is a double which is used to align the selector
/// button with the input field when an error occurs
///
/// [locale] accepts a country locale which will be used to translation, if the
/// translation exist
///
/// [countries] accepts list of string on Country isoCode, if specified filters
/// available countries to match the [countries] specified.
class InternationalPhoneNumberInput extends StatefulWidget {
  final SelectorConfig selectorConfig;

  final ValueChanged<PhoneNumber> onInputChanged;
  final ValueChanged<bool> onInputValidated;

  final VoidCallback onSubmit;
  final ValueChanged<String> onFieldSubmitted;
  final ValueChanged<PhoneNumber> onSaved;

  final TextEditingController textFieldController;
  final TextInputAction keyboardAction;

  final PhoneNumber initialValue;
  final String hintText;
  final String errorMessage;

  final int maxLength;

  final bool isEnabled;
  final bool formatInput;
  final bool autoFocus;
  final bool autoFocusSearch;
  final AutovalidateMode autoValidateMode;
  final bool ignoreBlank;
  final bool countrySelectorScrollControlled;
  final bool hideErrorState;

  final String locale;

  final TextStyle textStyle;
  final TextStyle selectorTextStyle;
  final InputBorder inputBorder;
  final InputDecoration inputDecoration;
  final InputDecoration searchBoxDecoration;
  final TextAlign textAlign;
  final TextAlignVertical textAlignVertical;
  final EdgeInsets scrollPadding;
  final Color errorColor;

  final FocusNode focusNode;
  final Iterable<String> autofillHints;

  final List<String> countries;

  InternationalPhoneNumberInput({
    Key key,
    this.selectorConfig = const SelectorConfig(),
    @required this.onInputChanged,
    this.onInputValidated,
    this.onSubmit,
    this.onFieldSubmitted,
    this.onSaved,
    this.textFieldController,
    this.keyboardAction,
    this.initialValue,
    this.hintText = 'Phone number',
    this.errorMessage = 'Invalid phone number',
    this.maxLength = 15,
    this.isEnabled = true,
    this.formatInput = true,
    this.autoFocus = false,
    this.autoFocusSearch = false,
    this.autoValidateMode = AutovalidateMode.disabled,
    this.ignoreBlank = false,
    this.countrySelectorScrollControlled = true,
    this.hideErrorState = false,
    this.locale,
    this.textStyle,
    this.selectorTextStyle,
    this.inputBorder,
    this.inputDecoration,
    this.searchBoxDecoration,
    this.textAlign = TextAlign.start,
    this.textAlignVertical = TextAlignVertical.center,
    this.scrollPadding,
    this.focusNode,
    this.autofillHints,
    this.countries,
    this.errorColor = const Color(0xFFFF2066),
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InternationalPhoneNumberInput> {
  TextEditingController controller;
  double selectorButtonBottomPadding = 0;

  Country country;
  List<Country> countries = [];
  bool isNotValid = true;

  bool get _showErrorState {
    if (widget.hideErrorState) {
      return false;
    }

    if (widget.ignoreBlank) {
      return controller.text.isNotEmpty ? this.isNotValid : false;
    } else {
      return this.isNotValid;
    }
  }

  @override
  void initState() {
    super.initState();
    loadCountries();
    controller = widget.textFieldController ?? TextEditingController();
    initialiseWidget();
  }

  @override
  void setState(fn) {
    if (this.mounted) {
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: _showErrorState ? widget.errorColor : Color(0xFFDCDBDB),
              ),
              borderRadius: BorderRadius.all(
                Radius.circular(3.0),
              ),
            ),
          ),
          child: _InputWidgetView(state: this),
        ),
        if (_showErrorState)
          Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              widget.errorMessage,
              style: TextStyle(
                fontSize: 13.0,
                color: widget.errorColor,
              ),
            ),
          )
      ],
    );
  }

  @override
  void didUpdateWidget(InternationalPhoneNumberInput oldWidget) {
    if (oldWidget.initialValue != widget.initialValue ||
        oldWidget.initialValue?.hash != widget.initialValue?.hash) {
      loadCountries();
      initialiseWidget();
    }
    super.didUpdateWidget(oldWidget);
  }

  /// [initialiseWidget] sets initial values of the widget
  void initialiseWidget() async {
    if (widget.initialValue != null) {
      if (widget.initialValue.phoneNumber != null &&
          widget.initialValue.phoneNumber.isNotEmpty &&
          await PhoneNumberUtil.isValidNumber(
              phoneNumber: widget.initialValue.phoneNumber,
              isoCode: widget.initialValue.isoCode)) {
        controller.text =
            await PhoneNumber.getParsableNumber(widget.initialValue);

        phoneNumberControllerListener();
      }
    }
  }

  /// loads countries from [Countries.countryList] and selected Country
  void loadCountries() {
    if (this.mounted) {
      List<Country> countries =
          CountryProvider.getCountriesData(countries: widget.countries);

      final CountryComparator countryComparator =
          widget.selectorConfig?.countryComparator;
      if (countryComparator != null) {
        countries.sort(countryComparator);
      }

      Country country = Utils.getInitialSelectedCountry(
        countries,
        widget.initialValue?.isoCode ?? '',
      );

      setState(() {
        this.countries = countries;
        this.country = country;
      });
    }
  }

  /// Listener that validates changes from the widget, returns a bool to
  /// the `ValueCallback` [widget.onInputValidated]
  void phoneNumberControllerListener() {
    if (this.mounted) {
      String parsedPhoneNumberString =
          controller.text.replaceAll(RegExp(r'[^\d+]'), '');

      getParsedPhoneNumber(parsedPhoneNumberString, this.country?.alpha2Code)
          .then((phoneNumber) {
        if (phoneNumber == null) {
          String phoneNumber =
              '${this.country?.dialCode}$parsedPhoneNumberString';

          if (widget.onInputChanged != null) {
            widget.onInputChanged(PhoneNumber(
                phoneNumber: phoneNumber,
                isoCode: this.country?.alpha2Code,
                dialCode: this.country?.dialCode));
          }

          if (widget.onInputValidated != null) {
            widget.onInputValidated(false);
          }
          this.isNotValid = true;
        } else {
          if (widget.onInputChanged != null) {
            widget.onInputChanged(PhoneNumber(
                phoneNumber: phoneNumber,
                isoCode: this.country?.alpha2Code,
                dialCode: this.country?.dialCode));
          }

          if (widget.onInputValidated != null) {
            widget.onInputValidated(true);
          }
          this.isNotValid = false;
        }
      });
    }
  }

  /// Returns a formatted String of [phoneNumber] with [isoCode], returns `null`
  /// if [phoneNumber] is not valid or if an [Exception] is caught.
  Future<String> getParsedPhoneNumber(
      String phoneNumber, String isoCode) async {
    if (phoneNumber.isNotEmpty && isoCode != null) {
      try {
        bool isValidPhoneNumber = await PhoneNumberUtil.isValidNumber(
            phoneNumber: phoneNumber, isoCode: isoCode);

        if (isValidPhoneNumber) {
          return await PhoneNumberUtil.normalizePhoneNumber(
              phoneNumber: phoneNumber, isoCode: isoCode);
        }
      } on Exception {
        return null;
      }
    }
    return null;
  }

  /// Creates or Select [InputDecoration]
  InputDecoration getInputDecoration(InputDecoration decoration) {
    return decoration ??
        InputDecoration(
          border: widget.inputBorder ?? UnderlineInputBorder(),
          hintText: widget.hintText,
        );
  }

  /// Validate the phone number when a change occurs
  void onChanged(String value) {
    phoneNumberControllerListener();
  }

  /// Changes Selector Button Country and Validate Change.
  void onCountryChanged(Country country) {
    setState(() {
      this.country = country;
    });
    phoneNumberControllerListener();
  }

  void _phoneNumberSaved() {
    if (this.mounted) {
      String parsedPhoneNumberString =
          controller.text.replaceAll(RegExp(r'[^\d+]'), '');

      getParsedPhoneNumber(parsedPhoneNumberString, this.country?.alpha2Code)
          .then(
        (phoneNumber) => widget.onSaved?.call(
          PhoneNumber(
              phoneNumber: phoneNumber,
              isoCode: this.country?.alpha2Code,
              dialCode: this.country?.dialCode),
        ),
      );
    }
  }

  /// Saved the phone number when form is saved
  void onSaved(String value) {
    _phoneNumberSaved();
  }

  /// Corrects duplicate locale
  String get locale {
    if (widget.locale.toLowerCase() == 'nb' ||
        widget.locale.toLowerCase() == 'nn') {
      return 'no';
    }
    return widget.locale;
  }
}

class _InputWidgetView
    extends WidgetView<InternationalPhoneNumberInput, _InputWidgetState> {
  final _InputWidgetState state;

  _InputWidgetView({Key key, @required this.state})
      : super(key: key, state: state);

  @override
  Widget build(BuildContext context) {
    final countryCode = state?.country?.alpha2Code ?? '';
    final dialCode = state?.country?.dialCode ?? '';

    return Container(
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SelectorButton(
                country: state.country,
                countries: state.countries,
                onCountryChanged: state.onCountryChanged,
                selectorConfig: widget.selectorConfig,
                selectorTextStyle: widget.selectorTextStyle,
                searchBoxDecoration: widget.searchBoxDecoration,
                locale: state.locale,
                isEnabled: widget.isEnabled,
                autoFocusSearchField: widget.autoFocusSearch,
                isScrollControlled: widget.countrySelectorScrollControlled,
              ),
            ],
          ),
          Flexible(
            child: TextFormField(
              key: Key(TestHelper.TextInputKeyValue),
              textDirection: TextDirection.ltr,
              controller: state.controller,
              focusNode: widget.focusNode,
              enabled: widget.isEnabled,
              autofocus: widget.autoFocus,
              keyboardType: TextInputType.phone,
              textInputAction: widget.keyboardAction,
              style: widget.textStyle,
              decoration: state.getInputDecoration(widget.inputDecoration),
              textAlign: widget.textAlign,
              textAlignVertical: widget.textAlignVertical,
              onEditingComplete: widget.onSubmit,
              onFieldSubmitted: widget.onFieldSubmitted,
              autovalidateMode: widget.autoValidateMode,
              autofillHints: widget.autofillHints,
              onSaved: state.onSaved,
              scrollPadding: widget.scrollPadding ?? EdgeInsets.all(20.0),
              inputFormatters: [
                LengthLimitingTextInputFormatter(widget.maxLength),
                widget.formatInput
                    ? AsYouTypeFormatter(
                        isoCode: countryCode,
                        dialCode: dialCode,
                        onInputFormatted: (TextEditingValue value) {
                          state.controller.value = value;
                        },
                      )
                    : FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: state.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
