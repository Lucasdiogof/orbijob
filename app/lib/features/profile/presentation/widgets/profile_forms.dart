import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/date_field_tile.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../preferences/presentation/preferences_cubit.dart';
import '../../domain/professional_profile.dart';
import '../profile_cubit.dart';

Widget _scaffold(BuildContext context, String title, Widget body) => Scaffold(
  appBar: AppBar(title: Text(title)),
  body: Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: body,
    ),
  ),
);

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
  const ProfileFormPage({super.key, this.profile});
  final ProfessionalProfile? profile;
  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile?.name);
  late final _headline = TextEditingController(text: widget.profile?.headline);
  late final _summary = TextEditingController(text: widget.profile?.summary);
  late final _country = TextEditingController(
    text: widget.profile?.countryOfResidence,
  );
  late final _city = TextEditingController(text: widget.profile?.city);
  final _skillInput = TextEditingController();
  late List<String> _skills = [...?widget.profile?.skills];
  late String? _workMode = widget.profile?.workMode;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _headline,
      _summary,
      _country,
      _city,
      _skillInput,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSkill() {
    final v = _skillInput.text.trim();
    if (v.isEmpty || v.length > 80) return;
    if (_skills.any((s) => s.toLowerCase() == v.toLowerCase())) {
      _skillInput.clear();
      return;
    }
    if (_skills.length >= 200) return;
    setState(() => _skills = [..._skills, v]);
    _skillInput.clear();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    _addSkill();
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
      workMode: _workMode,
      clearWorkMode: _workMode == null,
    );
    final ok = await context.read<ProfileCubit>().saveProfile(next);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String? max(String? v, int n) =>
        (v ?? '').length > n ? l.tooLongError(n) : null;
    return _scaffold(
      context,
      widget.profile == null ? l.profileCreateTitle : l.profileEditAction,
      Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l.profileFieldName),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? l.commonRequired : max(v, 200),
            ),
            TextFormField(
              controller: _headline,
              decoration: InputDecoration(
                labelText: '${l.profileFieldHeadline} (${l.commonOptional})',
              ),
              validator: (v) => max(v, 200),
            ),
            TextFormField(
              controller: _summary,
              decoration: InputDecoration(
                labelText: '${l.profileFieldSummary} (${l.commonOptional})',
              ),
              maxLines: 5,
              validator: (v) => max(v, 4000),
            ),
            TextFormField(
              controller: _country,
              decoration: InputDecoration(
                labelText: '${l.profileFieldCountry} (${l.commonOptional})',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ||
                      PreferencesCubit.normalizeCountry(v!) != null
                  ? null
                  : l.profileCountryInvalid,
            ),
            TextFormField(
              controller: _city,
              decoration: InputDecoration(
                labelText: '${l.profileFieldCity} (${l.commonOptional})',
              ),
              validator: (v) => max(v, 120),
            ),
            const SizedBox(height: AppSpace.s3),
            DropdownButtonFormField<String?>(
              initialValue: _workMode,
              decoration: InputDecoration(labelText: l.profileFieldWorkMode),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l.profileWorkModeAny),
                ),
                for (final m in workModePreferences)
                  DropdownMenuItem<String?>(
                    value: m,
                    child: Text(workModeLabel(l, m)),
                  ),
              ],
              onChanged: (v) => setState(() => _workMode = v),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(l.profileFieldSkills, style: context.text.titleSmall),
            const SizedBox(height: AppSpace.s2),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              children: [
                for (final s in _skills)
                  InputChip(
                    label: Text(s),
                    deleteButtonTooltipMessage: l.profileSkillRemove(s),
                    onDeleted: () => setState(
                      () => _skills = _skills.where((e) => e != s).toList(),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillInput,
                    decoration: InputDecoration(
                      labelText: l.profileSkillAdd,
                      helperText: l.profileSkillsLimit,
                    ),
                    onSubmitted: (_) => _addSkill(),
                  ),
                ),
                IconButton(
                  tooltip: l.profileSkillAdd,
                  icon: const Icon(Icons.add),
                  onPressed: _addSkill,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton(
              label: l.commonSave,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
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
    if (!valid || err != null) return;
    setState(() => _saving = true);
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
    ok ? Navigator.of(context).pop() : setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String? req(String? v) =>
        (v ?? '').trim().isEmpty ? l.commonRequired : null;
    return _scaffold(
      context,
      widget.initial == null ? l.experienceNewTitle : l.experienceEditTitle,
      Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [
            TextFormField(
              controller: _role,
              decoration: InputDecoration(labelText: l.experienceRole),
              validator: req,
            ),
            TextFormField(
              controller: _company,
              decoration: InputDecoration(labelText: l.experienceCompany),
              validator: req,
            ),
            const SizedBox(height: AppSpace.s3),
            DateFieldTile(
              label: l.fieldStartDate,
              value: _start,
              onChanged: (d) => setState(() => _start = d),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.experienceCurrent),
              value: _current,
              onChanged: (v) => setState(() => _current = v ?? false),
            ),
            DateFieldTile(
              label: l.fieldEndDate,
              value: _current ? null : _end,
              enabled: !_current,
              onChanged: (d) => setState(() => _end = d),
            ),
            if (_dateError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s1),
                child: Text(
                  _dateError!,
                  style: context.text.bodySmall!.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ),
            TextFormField(
              controller: _desc,
              decoration: InputDecoration(
                labelText: '${l.experienceDescription} (${l.commonOptional})',
              ),
              maxLines: 5,
              validator: (v) =>
                  (v ?? '').length > 4000 ? l.tooLongError(4000) : null,
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton(
              label: l.commonSave,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
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
    if (!valid || err != null) return;
    setState(() => _saving = true);
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
    ok ? Navigator.of(context).pop() : setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _scaffold(
      context,
      widget.initial == null ? l.educationNewTitle : l.educationEditTitle,
      Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [
            TextFormField(
              controller: _inst,
              decoration: InputDecoration(labelText: l.educationInstitution),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? l.commonRequired : null,
            ),
            TextFormField(
              controller: _field,
              decoration: InputDecoration(
                labelText: '${l.educationField} (${l.commonOptional})',
              ),
            ),
            TextFormField(
              controller: _degree,
              decoration: InputDecoration(labelText: l.educationDegree),
            ),
            const SizedBox(height: AppSpace.s3),
            DateFieldTile(
              label: l.fieldStartDate,
              value: _start,
              onChanged: (d) => setState(() => _start = d),
            ),
            DateFieldTile(
              label: l.fieldEndDate,
              value: _end,
              onChanged: (d) => setState(() => _end = d),
            ),
            if (_dateError != null)
              Text(
                _dateError!,
                style: context.text.bodySmall!.copyWith(
                  color: context.colors.error,
                ),
              ),
            const SizedBox(height: AppSpace.s4),
            AppButton(
              label: l.commonSave,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
