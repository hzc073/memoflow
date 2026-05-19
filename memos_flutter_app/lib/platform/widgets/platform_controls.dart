import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform_target.dart';

class PlatformSwitch extends StatelessWidget {
  const PlatformSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final target = resolvePlatformTarget(context);
    if (target == PlatformTarget.iPhone || target == PlatformTarget.iPad) {
      return CupertinoSwitch(value: value, onChanged: onChanged);
    }
    return Switch.adaptive(value: value, onChanged: onChanged);
  }
}

class PlatformCheckbox extends StatelessWidget {
  const PlatformCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Checkbox.adaptive(value: value, onChanged: onChanged);
  }
}

class PlatformRadio<T> extends StatelessWidget {
  const PlatformRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: onChanged ?? (_) {},
      child: Radio<T>.adaptive(value: value, enabled: onChanged != null),
    );
  }
}

class PlatformSlider extends StatelessWidget {
  const PlatformSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Slider.adaptive(
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      divisions: divisions,
    );
  }
}

class PlatformProgress extends StatelessWidget {
  const PlatformProgress({super.key, this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator.adaptive(value: value);
  }
}

class PlatformTextField extends StatelessWidget {
  const PlatformTextField({
    super.key,
    this.textFieldKey,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.maxLengthEnforcement,
    this.inputFormatters,
    this.autofocus = false,
    this.enabled,
    this.keyboardType,
    this.expands = false,
    this.textInputAction,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.obscureText = false,
    this.readOnly = false,
    this.enableInteractiveSelection,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
  });

  final Key? textFieldKey;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool? enabled;
  final TextInputType? keyboardType;
  final bool expands;
  final TextInputAction? textInputAction;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final bool obscureText;
  final bool readOnly;
  final bool? enableInteractiveSelection;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: textFieldKey,
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      style: style,
      enabled: enabled,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      expands: expands,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      textInputAction: textInputAction,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      obscureText: obscureText,
      readOnly: readOnly,
      enableInteractiveSelection: enableInteractiveSelection,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
    );
  }
}
