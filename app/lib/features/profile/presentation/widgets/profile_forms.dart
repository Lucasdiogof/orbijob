import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/orbi/orbi.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../preferences/presentation/preferences_cubit.dart';
import '../../domain/professional_profile.dart';
import '../profile_cubit.dart';

String? _blank(String v) => v.trim().isEmpty ? null : v.trim();

/// Opens [page] with the caller's [ProfileCubit].
Future<void> openProfileForm(BuildContext context, Widget page) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BlocProvider.value(
          value: context.read<ProfileCubit>(),
          child: page,
        ),
      ),
    );

/// Create or edit the professional profile. Any profession: every field except the name is optional.
class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key, this.profile, this.suggested});
  final ProfessionalProfile? profile;

  /// Values to start from (for example confirmed suggestions from a résumé). They fill the form; nothing is saved until the user saves.
  final ProfessionalProfile? suggested;
  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _form = GlobalKey<FormState>();
  final _tags = GlobalKey<OrbiTagInputState>();
  late final ProfessionalProfile? _src = widget.suggested ?? widget.profile;
  late final _name = TextEditingController(text: _src?.name);
  late final _headline = TextEditingController(text: _src?.headline);
  late final _summary = TextEditingController(text: _src?.summary);
  late final _country = TextEditingController(text: _src?.countryOfResidence);
  late final _city = TextEditingController(text: _src?.city);
  late List<String> _skills = [...?_src?.skills];
  late String _workMode = _src?.workMode ?? '';
  bool _saving = false;
  late bool _dirty = widget.suggested != null;

  @override
  void dispose() {
    for (final c in [_name, _headline, _summary, _country, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    _tags.currentState?.commit();
    if (!(_form.currentState?.validate() ?? false)) {
      showOrbiSnackBar(context, l.formFixErrors, kind: OrbiSnackKind.error);
      return;
    }
    setState(() => _saving = true);
    final cc = PreferencesCubit.normalizeCountry(_country.text);
    final base = widget.profile ?? ProfessionalProfile(name: _name.text.trim());
    final next = base.copyWith(
      name: _name.text.trim(),
      headline: _headline.text,
      summary: _summary.text,
      city: _city.text,
      skills: _skills,
      countryOfResidence: cc,
      clearCountry: cc == null,
      workMode: _workMode.isEmpty ? null : _workMode,
      clearWorkMode: _workMode.isEmpty,
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = l.profileSaved;
    final ok = await context.read<ProfileCubit>().saveProfile(next);
    if (!mounted) return;
    if (ok) {
      _dirty = false;
      Navigator.of(context).pop();
      showSavedFeedback(messenger, saved);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String? max(String? v, int n) =>
        (v ?? '').length > n ? l.tooLongError(n) : null;
    void touch() => _dirty = true;
    return OrbiFormPage(
      title: widget.profile == null
          ? l.profileCreateTitle
          : l.profileEditAction,
      formKey: _form,
      saving: _saving,
      dirty: _dirty,
      onSave: _save,
      children: [
        OrbiTextField(
          label: l.profileFieldName,
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          onChanged: (_) => touch(),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? l.commonRequired : max(v, 200),
        ),
        OrbiTextField(
          label: l.profileFieldHeadline,
          optional: true,
          controller: _headline,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.jobTitle],
          onChanged: (_) => touch(),
          validator: (v) => max(v, 200),
        ),
        OrbiTextField(
          label: l.profileFieldSummary,
          optional: true,
          controller: _summary,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          onChanged: (_) => touch(),
          validator: (v) => max(v, 4000),
        ),
        OrbiTextField(
          label: l.profileFieldCountry,
          optional: true,
          controller: _country,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.countryCode],
          onChanged: (_) => touch(),
          validator: (v) =>
              (v ?? '').trim().isEmpty ||
                  PreferencesCubit.normalizeCountry(v!) != null
              ? null
              : l.profileCountryInvalid,
        ),
        OrbiTextField(
          label: l.profileFieldCity,
          optional: true,
          controller: _city,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.addressCity],
          onChanged: (_) => touch(),
          validator: (v) => max(v, 120),
        ),
        OrbiDropdownField<String>(
          label: l.profileFieldWorkMode,
          value: _workMode,
          items: [
            DropdownMenuItem(value: '', child: Text(l.profileWorkModeAny)),
            for (final m in workModePreferences)
              DropdownMenuItem(value: m, child: Text(workModeLabel(l, m))),
          ],
          onChanged: (v) => setState(() {
            _workMode = v;
            _dirty = true;
          }),
        ),
        OrbiTagInput(
          key: _tags,
          label: l.profileFieldSkills,
          addLabel: l.profileSkillAdd,
          removeLabel: l.profileSkillRemove,
          helper: l.profileSkillsLimit,
          tags: _skills,
          onChanged: (v) => setState(() {
            _skills = v;
            _dirty = true;
          }),
        ),
      ],
    );
  }
}

String workModeLabel(AppLocalizations l, String mode) => switch (mode) {
  'remote' => l.workModeRemote,
  'hybrid' => l.workModeHybrid,
  'onsite' => l.workModeOnsite,
  _ => mode,
};

/// Add or edit one experience. A current job has a start date and no end date.
class ExperienceFormPage extends StatefulWidget {
  const ExperienceFormPage({super.key, required this.profileId, this.initial});
  final String profileId;
  final Experience? initial;
  @override
  State<ExperienceFormPage> createState() => _ExperienceFormPageState();
}

class _ExperienceFormPageState extends State<ExperienceFormPage> {
  final _form = GlobalKey<FormState>();
  late final _company = TextEditingController(text: widget.initial?.company);
  late final _role = TextEditingController(text: widget.initial?.title);
  late final _desc = TextEditingController(text: widget.initial?.description);
  late DateTime? _start = widget.initial?.startDate;
  late DateTime? _end = widget.initial?.endDate;
  late bool _current = widget.initial?.isCurrent ?? false;
  bool _saving = false;
  bool _dirty = false;
  String? _dateError;

  @override
  void dispose() {
    for (final c in [_company, _role, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final valid = _form.currentState?.validate() ?? false;
    String? err;
    if (_current && _start == null) {
      err = l.experienceCurrentNeedsStart;
    } else if (!_current &&
        _start != null &&
        _end != null &&
        _end!.isBefore(_start!)) {
      err = l.experienceDatesInvalid;
    }
    setState(() => _dateError = err);
    if (!valid || err != null) {
      showOrbiSnackBar(context, l.formFixErrors, kind: OrbiSnackKind.error);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = l.commonSaved;
    final ok = await context.read<ProfileCubit>().saveExperience(
      Experience(
        id: widget.initial?.id,
        profileId: widget.profileId,
        company: _company.text.trim(),
        title: _role.text.trim(),
        startDate: _start,
        endDate: _current ? null : _end,
        description: _blank(_desc.text),
      ),
    );
    if (!mounted) return;
    if (ok) {
      _dirty = false;
      Navigator.of(context).pop();
      showSavedFeedback(messenger, saved);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String? req(String? v) =>
        (v ?? '').trim().isEmpty ? l.commonRequired : null;
    void touch() => _dirty = true;
    return OrbiFormPage(
      title: widget.initial == null
          ? l.experienceNewTitle
          : l.experienceEditTitle,
      formKey: _form,
      saving: _saving,
      dirty: _dirty,
      onSave: _save,
      children: [
        OrbiTextField(
          label: l.experienceRole,
          controller: _role,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.jobTitle],
          onChanged: (_) => touch(),
          validator: req,
        ),
        OrbiTextField(
          label: l.experienceCompany,
          controller: _company,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.organizationName],
          onChanged: (_) => touch(),
          validator: req,
        ),
        OrbiDateField(
          label: l.fieldStartDate,
          value: _start,
          onChanged: (d) => setState(() {
            _start = d;
            _dirty = true;
          }),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l.experienceCurrent),
          value: _current,
          onChanged: (v) => setState(() {
            _current = v ?? false;
            _dirty = true;
          }),
        ),
        OrbiDateField(
          label: l.fieldEndDate,
          value: _current ? null : _end,
          enabled: !_current,
          errorText: _dateError,
          onChanged: (d) => setState(() {
            _end = d;
            _dirty = true;
          }),
        ),
        OrbiTextField(
          label: l.experienceDescription,
          optional: true,
          controller: _desc,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          onChanged: (_) => touch(),
          validator: (v) =>
              (v ?? '').length > 4000 ? l.tooLongError(4000) : null,
        ),
      ],
    );
  }
}

/// Add or edit one education entry. Only the institution is required; dates, degree and field are optional.
class EducationFormPage extends StatefulWidget {
  const EducationFormPage({super.key, required this.profileId, this.initial});
  final String profileId;
  final Education? initial;
  @override
  State<EducationFormPage> createState() => _EducationFormPageState();
}

class _EducationFormPageState extends State<EducationFormPage> {
  final _form = GlobalKey<FormState>();
  late final _inst = TextEditingController(text: widget.initial?.institution);
  late final _degree = TextEditingController(text: widget.initial?.degree);
  late final _field = TextEditingController(text: widget.initial?.field);
  late DateTime? _start = widget.initial?.startDate;
  late DateTime? _end = widget.initial?.endDate;
  bool _saving = false;
  bool _dirty = false;
  String? _dateError;

  @override
  void dispose() {
    for (final c in [_inst, _degree, _field]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final valid = _form.currentState?.validate() ?? false;
    final err = _start != null && _end != null && _end!.isBefore(_start!)
        ? l.experienceDatesInvalid
        : null;
    setState(() => _dateError = err);
    if (!valid || err != null) {
      showOrbiSnackBar(context, l.formFixErrors, kind: OrbiSnackKind.error);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = l.commonSaved;
    final ok = await context.read<ProfileCubit>().saveEducation(
      Education(
        id: widget.initial?.id,
        profileId: widget.profileId,
        institution: _inst.text.trim(),
        degree: _blank(_degree.text),
        field: _blank(_field.text),
        startDate: _start,
        endDate: _end,
      ),
    );
    if (!mounted) return;
    if (ok) {
      _dirty = false;
      Navigator.of(context).pop();
      showSavedFeedback(messenger, saved);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void touch() => _dirty = true;
    return OrbiFormPage(
      title: widget.initial == null
          ? l.educationNewTitle
          : l.educationEditTitle,
      formKey: _form,
      saving: _saving,
      dirty: _dirty,
      onSave: _save,
      children: [
        OrbiTextField(
          label: l.educationInstitution,
          controller: _inst,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.organizationName],
          onChanged: (_) => touch(),
          validator: (v) => (v ?? '').trim().isEmpty ? l.commonRequired : null,
        ),
        OrbiTextField(
          label: l.educationField,
          optional: true,
          controller: _field,
          textInputAction: TextInputAction.next,
          onChanged: (_) => touch(),
        ),
        OrbiTextField(
          label: l.educationDegree,
          optional: true,
          controller: _degree,
          textInputAction: TextInputAction.done,
          onChanged: (_) => touch(),
        ),
        OrbiDateField(
          label: l.fieldStartDate,
          value: _start,
          onChanged: (d) => setState(() {
            _start = d;
            _dirty = true;
          }),
        ),
        OrbiDateField(
          label: l.fieldEndDate,
          value: _end,
          errorText: _dateError,
          onChanged: (d) => setState(() {
            _end = d;
            _dirty = true;
          }),
        ),
      ],
    );
  }
}
