import 'package:reactive_forms_annotations/reactive_forms_annotations.dart';

enum ValidatorsApplyMode {
  merge,
  override,
}

class FormArrayAnnotation<T> {
  final List<Validator<T>> validators;

  final List<AsyncValidator<T>> asyncValidators;

  final int asyncValidatorsDebounceTime;

  final bool disabled;

  final List<Validator<T>> itemValidators;

  final List<AsyncValidator<T>> itemAsyncValidators;

  final int itemAsyncValidatorsDebounceTime;

  final bool itemDisabled;

  const FormArrayAnnotation({
    this.validators = const [],
    this.asyncValidators = const [],
    this.asyncValidatorsDebounceTime = 250,
    this.disabled = false,
    this.itemValidators = const [],
    this.itemAsyncValidators = const [],
    this.itemAsyncValidatorsDebounceTime = 250,
    this.itemDisabled = false,
  });
}

class RfArray<T> extends FormArrayAnnotation<T> {
  final List<Validator<T>> validators;

  final List<AsyncValidator<T>> asyncValidators;

  final int asyncValidatorsDebounceTime;

  final bool disabled;

  final List<Validator<T>> itemValidators;

  final List<AsyncValidator<T>> itemAsyncValidators;

  final int itemAsyncValidatorsDebounceTime;

  final bool itemDisabled;

  const RfArray({
    this.validators = const [],
    this.asyncValidators = const [],
    this.asyncValidatorsDebounceTime = 250,
    this.disabled = false,
    this.itemValidators = const [],
    this.itemAsyncValidators = const [],
    this.itemAsyncValidatorsDebounceTime = 250,
    this.itemDisabled = false,
  }) : super(
          validators: validators,
          asyncValidators: asyncValidators,
          asyncValidatorsDebounceTime: asyncValidatorsDebounceTime,
          disabled: disabled,
          itemValidators: itemValidators,
          itemAsyncValidators: itemAsyncValidators,
          itemAsyncValidatorsDebounceTime: itemAsyncValidatorsDebounceTime,
          itemDisabled: itemDisabled,
        );
}
