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
    return Radio.adaptive(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
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
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    return Slider.adaptive(
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
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
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      style: style,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
