import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/element.dart' as e;
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/src/dart/element/type.dart' as t;

import 'package:code_builder/code_builder.dart';
import 'package:reactive_forms_generator/src/form_elements/form_group_generator.dart';
import 'package:reactive_forms_generator/src/extensions.dart';
import 'package:reactive_forms_generator/src/types.dart';
import 'package:recase/recase.dart';

import 'library_builder.dart';

class FormGenerator {
  final ClassElement element;
  final DartType? type;

  final Map<String, FormGenerator> formGroupGenerators = {};

  FormGenerator(this.element, this.type) {
    nestedFormGroupElements.forEach(
      (e) => formGroupGenerators[e.name] = FormGenerator(
        e.type.element! as ClassElement,
        e.type,
      ),
    );

    nestedArrayFormGroupElements.forEach(
      (e) {
        final type = e.type;
        final typeArguments =
            type is ParameterizedType ? type.typeArguments : const <DartType>[];

        final typeParameter = typeArguments.first;

        // print(type is ParameterizedType);

        formGroupGenerators[e.name] = FormGenerator(
          typeParameter.element! as ClassElement,
          e.type,
        );
      },
    );
  }

  List<FieldElement> get formControls => element.fields
      .where(
        (e) => e.isFormControl,
      )
      .toList();

  List<FieldElement> get formArrays => element.fields
      .where(
        (e) => e.isFormArray,
      )
      .toList();

  List<FieldElement> get nestedFormGroupElements => element.fields
      .where(
        (e) => e.type.element is ClassElement,
      )
      .where(
        (e) => formGroupChecker.hasAnnotationOfExact(e.type.element!),
      )
      .toList();

  List<FieldElement> get nestedArrayFormGroupElements => element.fields
      .where(
        (e) => e.isFormGroupArray,
      )
      .toList();

  String get className => '${element.name}Form';

  // String fieldName(FieldElement field) => field.name;

  // String fieldValueName(FieldElement field) => '${field.name}Value';

  // String fieldControlName(FieldElement field) => '${field.name}Control';

  Field staticFieldName(FieldElement field) => Field(
        (b) => b
          ..static = true
          ..type = stringRef
          ..name = '${field.fieldControlNameName}'
          ..assignment = Code('"${field.fieldName}"'),
      );

  List<Field> get staticFieldNameList =>
      element.fields.map(staticFieldName).toList();

  Field field(FieldElement field) => Field(
        (b) => b
          // ..static = true
          ..type = stringRef
          ..name = field.fieldName
          ..assignment = Code('"${field.fieldName}"'),
      );

  List<Field> get fieldNameList => element.fields.map(field).toList();

  // String fieldControlPathMethodName(FieldElement field) =>
  //     '${field.name}ControlPath';

  Method fieldControlNameMethod(FieldElement field) => Method(
        (b) => b
          ..returns = stringRef
          ..name = field.fieldControlPath
          ..lambda = true
          ..body = Code(
              '[path, ${field.fieldControlNameName}].whereType<String>().join(".")'),
      );

  List<Method> get fieldControlNameMethodList => [
        ...formControls,
        ...formArrays,
      ].map(fieldControlNameMethod).toList();

  List<Field> get nestedFormGroupFields => nestedFormGroupElements
      .map(
        (e) => Field(
          (b) {
            final name = formGroupGenerators[e.name]!.className;
            b
              ..name = '${e.name}Form'
              ..late = true
              ..type = Reference(name);
          },
        ),
      )
      .toList();

  Method fieldValueMethod(FieldElement field) {
    String fieldValue = '${field.fieldControlName}.value';

    // do not add additional cast if the field is nullable to avoid
    // unnecessary_cast notes
    if (field.type.nullabilitySuffix == NullabilitySuffix.none) {
      fieldValue += ' as ${field.type}';
    }

    if (field.isFormGroupArray) {
      final typeParameter =
          (field.type as ParameterizedType).typeArguments.first;

      final formGenerator =
          FormGenerator(typeParameter.element! as ClassElement, type);

      fieldValue =
          '${field.name}${formGenerator.className}.map((e) => e.model).toList()';
    } else if (field.isFormArray) {
      final type = (field.type as ParameterizedType).typeArguments.first;

      fieldValue =
          '${field.fieldControlName}.value?.whereType<${type.getDisplayString(
        withNullability: true,
      )}>().toList() ?? []';
    }

    return Method(
      (b) => b
        ..name = field.fieldValueName
        ..lambda = true
        ..type = MethodType.getter
        ..returns = Reference(field.type.toString())
        ..body = Code(
          fieldValue,
        ),
    );
  }

  List<Method> get fieldValueMethodList => [
        ...formControls,
        ...formArrays,
      ].map(fieldValueMethod).toList();

  Method fieldContainsMethod(FieldElement field) => Method(
        (b) => b
          ..name = 'contains${field.name.pascalCase}'
          ..lambda = true
          ..type = MethodType.getter
          ..returns = Reference('bool')
          ..body = Code(
            'form.contains(${field.fieldControlPath}())',
          ),
      );

  List<Method> get fieldContainsMethodList => [
        ...formControls,
        ...formArrays,
      ].map(fieldContainsMethod).toList();

  Method errors(FieldElement field) => Method(
        (b) => b
          ..name = '${field.name}Errors'
          ..lambda = true
          ..type = MethodType.getter
          ..returns = Reference('Object?')
          ..body = Code(
            '${field.fieldControlName}.errors',
          ),
      );

  List<Method> get fieldErrorsMethodList => [
        ...formControls,
        ...formArrays,
      ].map(errors).toList();

  Method focus(FieldElement field) => Method(
        (b) => b
          ..name = '${field.name}Focus'
          ..lambda = true
          ..type = MethodType.getter
          ..returns = Reference('void')
          ..body = Code(
            'form.focus(${field.fieldControlPath}())',
          ),
      );

  List<Method> get fieldFocusMethodList => [
        ...formControls,
        ...formArrays,
      ].map(focus).toList();

  Method control(FieldElement field) {
    String displayType = field.type.getDisplayString(withNullability: true);

    // we need to trim last NullabilitySuffix.question cause FormControl modifies
    // generic T => T?
    if (field.type.nullabilitySuffix == NullabilitySuffix.question) {
      displayType = displayType.substring(0, displayType.length - 1);
    }

    final reference = 'FormControl<$displayType>';

    return Method(
      (b) => b
        ..name = field.fieldControlName
        ..lambda = true
        ..type = MethodType.getter
        ..returns = Reference(reference)
        ..body = Code(
          'form.control(${field.fieldControlPath}()) as ${reference}',
        ),
    );
  }

  Method array(FieldElement field) {
    final type = (field.type as ParameterizedType).typeArguments.first;

    String displayType = type.getDisplayString(withNullability: true);

    // we need to trim last NullabilitySuffix.question cause FormControl modifies
    // generic T => T?
    if (type.nullabilitySuffix == NullabilitySuffix.question) {
      displayType = displayType.substring(0, displayType.length - 1);
    }

    String typeReference = 'FormArray<$displayType>';

    if (field.isFormGroupArray) {
      typeReference = 'FormArray';
    }

    return Method(
      (b) => b
        ..name = field.fieldControlName
        ..lambda = true
        ..type = MethodType.getter
        ..returns = Reference(typeReference)
        ..body = Code(
          'form.control(${field.fieldControlPath}()) as ${typeReference}',
        ),
    );
  }

  List<Method> get fieldControlMethodList => formControls.map(control).toList();

  List<Method> get fieldArrayMethodList => formArrays.map(array).toList();

  Method get modelMethod => Method(
        (b) {
          final fields = formControls
              .map(
                (field) => '${field.fieldName}:${field.fieldValueName}',
              )
              .toList();

          fields.addAll(
            formArrays.map(
              (field) => '${field.fieldName}:${field.fieldValueName}',
            ),
          );

          fields.addAll(
            nestedFormGroupElements.map(
              (field) => '${field.fieldName}:${field.name}Form.model',
            ),
          );

          b
            ..name = 'model'
            ..returns = Reference(element.name)
            ..type = MethodType.getter
            ..lambda = true
            ..body = Code('''
              ${element.name}(${fields.join(', ')})
            ''');
        },
      );

  Constructor get _constructor => Constructor(
        (b) {
          final formGroupInitializers = formGroupGenerators
              .map((name, generator) {
                final item =
                    '${name}Form = ${generator.className}(${element.name.camelCase}.${name}, form, \'${name}\');';

                return MapEntry(name, item);
              })
              .values
              .toList();

          formGroupInitializers.addAll(
            nestedArrayFormGroupElements.map(
              (e) {
                final typeParameter =
                    (e.type as ParameterizedType).typeArguments.first;

                final formGenerator =
                    FormGenerator(typeParameter.element! as ClassElement, type);

                return '''${e.name}${formGenerator.className} = ${element.name.camelCase}.${e.name}
                  .asMap()
                  .map((k, v) => MapEntry(k, ${formGenerator.className}(v, form, "${e.name}.\$k")))
                  .values
                  .toList();
                ''';
              },
            ),
          );

          b
            ..requiredParameters.addAll(
              [
                Parameter(
                  (b) => b
                    ..name = element.name.camelCase
                    ..toThis = true,
                ),
                Parameter(
                  (b) => b
                    ..name = 'form'
                    ..toThis = true,
                ),
                Parameter(
                  (b) => b
                    ..name = 'path'
                    ..toThis = true,
                ),
              ],
            )
            ..body = Code('''
              ${formGroupInitializers.join('')}
            ''');
        },
      );

  List<Spec> get generate => [
        Class(
          (b) => b
            ..name = className
            ..fields.addAll(
              [
                // ...fieldNameList,
                ...staticFieldNameList,
                // ...fieldControlFieldList,
                ...nestedFormGroupFields,
                // ..type = Reference(element.name),
                Field(
                  (b) {
                    final displayType =
                        type?.getDisplayString(withNullability: true) ??
                            element.name;
                    b
                      ..name = element.name.camelCase
                      ..modifier = FieldModifier.final$
                      ..type = Reference('$displayType');
                  },
                ),
                Field(
                  (b) => b
                    ..name = 'form'
                    ..modifier = FieldModifier.final$
                    ..type = Reference('FormGroup'),
                ),
                Field(
                  (b) => b
                    ..name = 'path'
                    ..modifier = FieldModifier.final$
                    ..type = Reference('String?'),
                ),
                ...nestedArrayFormGroupElements.map(
                  (e) {
                    final typeParameter =
                        (e.type as ParameterizedType).typeArguments.first;

                    final formGenerator = FormGenerator(
                        typeParameter.element! as ClassElement, type);

                    return Field(
                      (b) => b
                        ..name = '${e.name}${formGenerator.className}'
                        ..type = Reference('List<${formGenerator.className}>')
                        ..late = true,
                    );
                  },
                ),
              ],
            )
            ..constructors.add(_constructor)
            ..methods.addAll(
              [
                ...fieldControlNameMethodList,
                ...fieldValueMethodList,
                ...fieldContainsMethodList,
                ...fieldErrorsMethodList,
                ...fieldFocusMethodList,
                ...fieldControlMethodList,
                ...fieldArrayMethodList,
                modelMethod,
                Method(
                  (b) {
                    b
                      ..name = 'formElements'
                      ..lambda = true
                      // ..requiredParameters.add(Parameter(
                      //   (b) => b
                      //     ..name = element.name.camelCase
                      //     ..type = Reference(element.name),
                      // ))
                      ..returns = Reference('FormGroup')
                      ..body = Code(
                        FormGroupGenerator(
                          e.FieldElementImpl('FakeFieldElement', 20)
                            ..type = t.InterfaceTypeImpl(
                              element: element,
                              typeArguments: [],
                              nullabilitySuffix: NullabilitySuffix.none,
                            ),
                          type,
                        ).element(),
                      );
                  },
                )
              ],
            ),
        ),
        ...formGroupGenerators.values.map((e) => e.generate).expand((e) => e),
      ];
}
