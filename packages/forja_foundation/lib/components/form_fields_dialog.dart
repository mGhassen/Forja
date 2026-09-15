import 'package:flutter/material.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/components/dialog.dart';
import 'package:forja_foundation/components/field.dart';
import 'package:forja_foundation/components/input.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';

/// One opaque text/password field for [showFormFieldsDialog].
class FormFieldSpec {
  const FormFieldSpec({
    required this.id,
    required this.label,
    this.type = 'text',
    this.value = '',
    this.hint = '',
    this.required = false,
  });

  final String id;
  final String label;

  /// `text` | `password` (opaque; unknown → text).
  final String type;
  final String value;
  final String hint;
  final bool required;

  static FormFieldSpec? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? '').toString().trim();
    final label = (j['label'] ?? '').toString().trim();
    if (id.isEmpty || label.isEmpty) return null;
    return FormFieldSpec(
      id: id,
      label: label,
      type: (j['type'] ?? 'text').toString().trim().toLowerCase(),
      value: (j['value'] ?? j['default'] ?? '').toString(),
      hint: (j['hint'] ?? j['placeholder'] ?? '').toString(),
      required: j['required'] == true,
    );
  }
}

/// Pack-declared modal form — title / fields / action labels only.
class FormFieldsSpec {
  const FormFieldsSpec({
    required this.title,
    required this.fields,
    this.submitLabel = 'Save',
    this.cancelLabel = 'Cancel',
    this.description = '',
    this.action = '',
    this.toastOk = '',
  });

  final String title;
  final List<FormFieldSpec> fields;
  final String submitLabel;
  final String cancelLabel;
  final String description;

  /// Opaque plugin action to run on submit (host wire).
  final String action;

  /// Optional success toast after submit.
  final String toastOk;

  static FormFieldsSpec? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final title = (j['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;
    final raw = j['fields'];
    if (raw is! List || raw.isEmpty) return null;
    final fields = <FormFieldSpec>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final f = FormFieldSpec.fromJson(Map<String, dynamic>.from(e));
      if (f != null) fields.add(f);
    }
    if (fields.isEmpty) return null;
    return FormFieldsSpec(
      title: title,
      fields: fields,
      submitLabel: (j['submitLabel'] ?? j['submit'] ?? 'Save').toString(),
      cancelLabel: (j['cancelLabel'] ?? j['cancel'] ?? 'Cancel').toString(),
      description: (j['description'] ?? '').toString(),
      action: (j['action'] ?? '').toString().trim(),
      toastOk: (j['toastOk'] ?? j['toast'] ?? '').toString(),
    );
  }

  /// Prefill field values by id (edit / import). Does not invent fields.
  FormFieldsSpec withValues(Map<String, String> values) {
    if (values.isEmpty) return this;
    return FormFieldsSpec(
      title: title,
      submitLabel: submitLabel,
      cancelLabel: cancelLabel,
      description: description,
      action: action,
      toastOk: toastOk,
      fields: [
        for (final f in fields)
          FormFieldSpec(
            id: f.id,
            label: f.label,
            type: f.type,
            hint: f.hint,
            required: f.required,
            value: values.containsKey(f.id) ? values[f.id]! : f.value,
          ),
      ],
    );
  }
}

/// Show a pack-declared form. Returns field id → value, or null if cancelled.
Future<Map<String, String>?> showFormFieldsDialog({
  required BuildContext context,
  required FormFieldsSpec spec,
}) {
  return showForjaDialog<Map<String, String>>(
    context: context,
    title: spec.title,
    description: spec.description.isEmpty ? null : spec.description,
    barrierDismissible: true,
    body: _FormFieldsBody(spec: spec),
  );
}

class _FormFieldsBody extends StatefulWidget {
  const _FormFieldsBody({required this.spec});

  final FormFieldsSpec spec;

  @override
  State<_FormFieldsBody> createState() => _FormFieldsBodyState();
}

class _FormFieldsBodyState extends State<_FormFieldsBody> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final f in widget.spec.fields)
        f.id: TextEditingController(text: f.value),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _values() => {
        for (final e in _ctrls.entries) e.key: e.value.text,
      };

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final spec = widget.spec;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < spec.fields.length; i++) ...[
          if (i > 0) SizedBox(height: theme.spaceMd),
          Field(
            label: spec.fields[i].label,
            isRequired: spec.fields[i].required,
            child: Input(
              controller: _ctrls[spec.fields[i].id],
              hintText: spec.fields[i].hint.isEmpty
                  ? null
                  : spec.fields[i].hint,
              obscureText: spec.fields[i].type == 'password' ||
                  spec.fields[i].type == 'secret',
            ),
          ),
        ],
        SizedBox(height: theme.spaceLg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Button(
              variant: ButtonVariant.ghost,
              label: spec.cancelLabel,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            SizedBox(width: theme.spaceSm),
            Button(
              variant: ButtonVariant.primary,
              label: spec.submitLabel,
              onPressed: () => Navigator.of(context).maybePop(_values()),
            ),
          ],
        ),
      ],
    );
  }
}
