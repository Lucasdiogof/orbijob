import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/design.dart';
import '../../../core/orbi/orbi.dart';
import '../../../l10n/app_localizations.dart';
import '../../preferences/presentation/preferences_cubit.dart';
import '../domain/pdf_text.dart';
import '../domain/professional_profile.dart';
import '../domain/resume_parser.dart';
import 'profile_cubit.dart';

/// Reads the PDF on the device, then opens the review screen. Every outcome that is not a success is explained honestly:
/// scans, protected files, unreadable fonts and "text but nothing recognisable" each get their own message.
Future<void> startResumeImport(BuildContext context, Uint8List bytes) async {
  final l = AppLocalizations.of(context);
  final nav = Navigator.of(context);
  final cubit = context.read<ProfileCubit>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  // a short "reading" dialog; extraction runs off the UI thread where the platform has threads
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OrbiLoadingIndicator(size: 32),
              const SizedBox(width: AppSpace.s4),
              Flexible(child: Text(l.resumeImportReading)),
            ],
          ),
        ),
      ),
    ),
  );
  final PdfTextResult result = await compute(extractPdfText, bytes);
  nav.pop(); // the dialog
  void say(String m) => showOrbiSnackBarOn(messenger, m);
  switch (result.status) {
    case PdfTextStatus.noTextLayer:
      return say(l.resumeImportNoText);
    case PdfTextStatus.encrypted:
      return say(l.resumeImportEncrypted);
    case PdfTextStatus.unreadable:
      return say(l.resumeImportUnreadable);
    case PdfTextStatus.ok:
      break;
  }
  final suggestion = parseResumeText(result.text);
  if (suggestion.isEmpty) return say(l.resumeImportNothing);
  await nav.push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ResumeImportPage(suggestion: suggestion),
      ),
    ),
  );
}

void showOrbiSnackBarOn(ScaffoldMessengerState? m, String text) {
  m
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 8)),
    );
}

class _Item {
  _Item(String value, {required this.existing, this.include = true})
    : controller = TextEditingController(text: value);
  final TextEditingController controller;
  final String? existing;
  bool include;
}

class _ExpDraft {
  _ExpDraft(SuggestedExperience e, {required this.duplicate})
    : title = TextEditingController(text: e.title),
      company = TextEditingController(text: e.company),
      description = TextEditingController(text: e.description ?? ''),
      start = e.start,
      end = e.end,
      current = e.start != null && e.end == null,
      include = !duplicate;
  final TextEditingController title;
  final TextEditingController company;
  final TextEditingController description;
  DateTime? start;
  DateTime? end;
  bool current;
  bool include;
  final bool duplicate;

  bool get complete =>
      title.text.trim().isNotEmpty && company.text.trim().isNotEmpty;
}

class _EduDraft {
  _EduDraft(SuggestedEducation e, {required this.duplicate})
    : institution = TextEditingController(text: e.institution),
      degree = TextEditingController(text: e.degree ?? ''),
      field = TextEditingController(text: e.field ?? ''),
      start = e.start,
      end = e.end,
      include = !duplicate;
  final TextEditingController institution;
  final TextEditingController degree;
  final TextEditingController field;
  DateTime? start;
  DateTime? end;
  bool include;
  final bool duplicate;

  bool get complete => institution.text.trim().isNotEmpty;
}

/// The review screen: suggested values next to checkboxes, every text editable. Existing profile data is only replaced where
/// the user ticks it; entries already in the profile are shown as such and not added twice.
class ResumeImportPage extends StatefulWidget {
  const ResumeImportPage({super.key, required this.suggestion});
  final ResumeSuggestion suggestion;

  @override
  State<ResumeImportPage> createState() => _ResumeImportPageState();
}

class _ResumeImportPageState extends State<ResumeImportPage> {
  final _form = GlobalKey<FormState>();
  late final ProfileState _before = context.read<ProfileCubit>().state;
  late final ProfessionalProfile? _profile = _before.profile;
  final _scalar = <String, _Item>{};
  final _skills = <String, bool>{};
  final _langs = <String, bool>{};
  final _langLevels = <String, String?>{};
  final _exps = <_ExpDraft>[];
  final _edus = <_EduDraft>[];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.suggestion;
    final p = _profile;
    void scalar(String key, String? value, String? existing) {
      if (value == null || value.trim().isEmpty) return;
      if (existing != null &&
          existing.trim().toLowerCase() == value.trim().toLowerCase()) {
        return; // nothing to change
      }
      _scalar[key] = _Item(
        value,
        existing: existing,
        include: existing == null,
      );
    }

    scalar('name', s.name, p?.name);
    scalar('headline', s.headline, p?.headline);
    scalar('email', s.email, p?.contactEmail);
    scalar('phone', s.phone, p?.phone);
    scalar('city', s.city, p?.city);
    scalar('country', s.country, p?.countryOfResidence);
    scalar('summary', s.summary, p?.summary);
    final have = {
      for (final k in p?.skills ?? const <String>[]) k.toLowerCase(),
    };
    for (final k in s.skills) {
      if (!have.contains(k.toLowerCase())) _skills[k] = true;
    }
    final haveLang = {
      for (final l in p?.languages ?? const <ProfileLanguage>[]) l.code,
    };
    for (final l in s.languages) {
      if (!haveLang.contains(l.code)) {
        _langs[l.code] = true;
        _langLevels[l.code] = l.level;
      }
    }
    String key(String a, String b) =>
        '${a.trim().toLowerCase()}|${b.trim().toLowerCase()}';
    final haveExp = {
      for (final e in _before.experiences) key(e.title, e.company),
    };
    for (final e in s.experiences) {
      _exps.add(
        _ExpDraft(e, duplicate: haveExp.contains(key(e.title, e.company))),
      );
    }
    final haveEdu = {
      for (final e in _before.education) key(e.institution, e.degree ?? ''),
    };
    for (final e in s.education) {
      _edus.add(
        _EduDraft(
          e,
          duplicate: haveEdu.contains(key(e.institution, e.degree ?? '')),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final i in _scalar.values) {
      i.controller.dispose();
    }
    for (final e in _exps) {
      e.title.dispose();
      e.company.dispose();
      e.description.dispose();
    }
    for (final e in _edus) {
      e.institution.dispose();
      e.degree.dispose();
      e.field.dispose();
    }
    super.dispose();
  }

  int get _count =>
      _scalar.values.where((i) => i.include).length +
      _skills.values.where((v) => v).length +
      _langs.values.where((v) => v).length +
      _exps.where((e) => e.include && !e.duplicate).length +
      _edus.where((e) => e.include && !e.duplicate).length;

  Future<void> _apply() async {
    final l = AppLocalizations.of(context);
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) {
      showOrbiSnackBar(context, l.formFixErrors, kind: OrbiSnackKind.error);
      return;
    }
    final nameItem = _scalar['name'];
    final nameValue = nameItem != null && nameItem.include
        ? nameItem.controller.text.trim()
        : _profile?.name;
    if (nameValue == null || nameValue.isEmpty) {
      setState(() => _error = l.resumeImportNeedsName);
      return;
    }
    for (final e in _exps) {
      if (e.include && !e.duplicate && !e.complete) {
        setState(() => _error = l.resumeImportNeedsFields);
        return;
      }
    }
    for (final e in _edus) {
      if (e.include && !e.duplicate && !e.complete) {
        setState(() => _error = l.resumeImportNeedsInstitution);
        return;
      }
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final done = l.resumeImportApplied;
    final cubit = context.read<ProfileCubit>();
    String? picked(String k) {
      final i = _scalar[k];
      return i != null && i.include ? i.controller.text.trim() : null;
    }

    final base = _profile ?? ProfessionalProfile(name: nameValue);
    final cc = picked('country') == null
        ? null
        : PreferencesCubit.normalizeCountry(picked('country')!);
    final newSkills = [
      for (final e in _skills.entries)
        if (e.value) e.key,
    ];
    final newLangs = [
      for (final e in _langs.entries)
        if (e.value) ProfileLanguage(code: e.key, level: _langLevels[e.key]),
    ];
    final next = base.copyWith(
      name: nameValue,
      headline: picked('headline'),
      summary: picked('summary'),
      city: picked('city'),
      contactEmail: picked('email'),
      phone: picked('phone'),
      countryOfResidence: cc,
      skills: [...base.skills, ...newSkills],
      languages: [...base.languages, ...newLangs],
    );
    var ok = await cubit.saveProfile(next);
    final profileId = cubit.state.profile?.id;
    if (ok && profileId != null) {
      for (final e in _exps.where((e) => e.include && !e.duplicate)) {
        ok = await cubit.saveExperience(
          Experience(
            profileId: profileId,
            company: e.company.text.trim(),
            title: e.title.text.trim(),
            startDate: e.start,
            endDate: e.current ? null : e.end,
            description: e.description.text.trim().isEmpty
                ? null
                : e.description.text.trim(),
          ),
        );
        if (!ok) break;
      }
      for (final e in _edus.where((e) => e.include && !e.duplicate)) {
        if (!ok) break;
        ok = await cubit.saveEducation(
          Education(
            profileId: profileId,
            institution: e.institution.text.trim(),
            degree: e.degree.text.trim().isEmpty ? null : e.degree.text.trim(),
            field: e.field.text.trim().isEmpty ? null : e.field.text.trim(),
            startDate: e.start,
            endDate: e.end,
          ),
        );
      }
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      showSavedFeedback(messenger, done);
    } else {
      setState(() => _saving = false);
    }
  }

  Widget _scalarRow(
    String key,
    String label, {
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) {
    final item = _scalar[key];
    if (item == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Checkbox(
              value: item.include,
              semanticLabel: label,
              onChanged: (v) => setState(() => item.include = v ?? false),
            ),
          ),
          Expanded(
            child: OrbiTextField(
              label: label,
              controller: item.controller,
              maxLines: maxLines,
              keyboardType: keyboard,
              enabled: item.include,
              helper: item.existing == null
                  ? null
                  : l.resumeImportReplaces(item.existing!),
              validator: item.include ? validator : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final fmt = MaterialLocalizations.of(context);
    String dates(DateTime? a, DateTime? b, bool current) {
      if (a == null && b == null) return '';
      final from = a == null ? '' : fmt.formatMonthYear(a);
      final to = current
          ? l.resumeImportPresent
          : (b == null ? '' : fmt.formatMonthYear(b));
      return l.resumeImportDates(from, to);
    }

    Widget header(String t) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: OrbiSectionHeader(title: t),
    );

    final scalars = _scalar.isNotEmpty;
    return OrbiFormPage(
      title: l.resumeImportTitle,
      formKey: _form,
      saving: _saving,
      dirty: true,
      saveLabel: l.resumeImportApply(_count),
      onSave: _count == 0 ? () {} : _apply,
      children: [
        OrbiCard(
          color: c.primaryContainer,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: c.onPrimaryContainer),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Text(
                  l.resumeImportIntro,
                  style: context.text.bodySmall!.copyWith(
                    color: c.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) AuthMessageLike(text: _error!),
        if (scalars)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(l.resumeImportSectionIdentity),
              _scalarRow(
                'name',
                l.profileFieldName,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l.commonRequired : null,
              ),
              _scalarRow('headline', l.profileFieldHeadline),
              _scalarRow(
                'email',
                l.profileFieldEmail,
                keyboard: TextInputType.emailAddress,
                validator: (v) =>
                    RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch((v ?? '').trim())
                    ? null
                    : l.profileEmailInvalid,
              ),
              _scalarRow(
                'phone',
                l.profileFieldPhone,
                keyboard: TextInputType.phone,
              ),
              _scalarRow('city', l.profileFieldCity),
              _scalarRow(
                'country',
                l.profileFieldCountry,
                validator: (v) =>
                    PreferencesCubit.normalizeCountry((v ?? '').trim()) != null
                    ? null
                    : l.profileCountryInvalid,
              ),
              _scalarRow('summary', l.profileFieldSummary, maxLines: 5),
            ],
          ),
        if (_skills.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(l.resumeImportSectionSkills),
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: [
                  for (final e in _skills.entries)
                    OrbiFilterChip(
                      label: e.key,
                      selected: e.value,
                      onSelected: (v) => setState(() => _skills[e.key] = v),
                    ),
                ],
              ),
            ],
          ),
        if (_langs.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(l.resumeImportSectionLanguages),
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: [
                  for (final e in _langs.entries)
                    OrbiFilterChip(
                      label: _langLevels[e.key] == null
                          ? e.key.toUpperCase()
                          : '${e.key.toUpperCase()} · ${_langLevels[e.key]}',
                      selected: e.value,
                      onSelected: (v) => setState(() => _langs[e.key] = v),
                    ),
                ],
              ),
            ],
          ),
        if (_exps.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(l.resumeImportSectionExperience),
              for (final e in _exps)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s3),
                  child: OrbiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            e.duplicate
                                ? l.resumeImportAlready
                                : dates(e.start, e.end, e.current),
                            style: context.metadataStyle,
                          ),
                          value: e.include && !e.duplicate,
                          onChanged: e.duplicate
                              ? null
                              : (v) => setState(() => e.include = v ?? false),
                        ),
                        OrbiTextField(
                          label: l.experienceRole,
                          controller: e.title,
                          enabled: e.include && !e.duplicate,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        OrbiTextField(
                          label: l.experienceCompany,
                          controller: e.company,
                          enabled: e.include && !e.duplicate,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        OrbiTextField(
                          label: l.experienceDescription,
                          optional: true,
                          controller: e.description,
                          maxLines: 4,
                          enabled: e.include && !e.duplicate,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (_edus.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(l.resumeImportSectionEducation),
              for (final e in _edus)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s3),
                  child: OrbiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            e.duplicate
                                ? l.resumeImportAlready
                                : dates(e.start, e.end, false),
                            style: context.metadataStyle,
                          ),
                          value: e.include && !e.duplicate,
                          onChanged: e.duplicate
                              ? null
                              : (v) => setState(() => e.include = v ?? false),
                        ),
                        OrbiTextField(
                          label: l.educationInstitution,
                          controller: e.institution,
                          enabled: e.include && !e.duplicate,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        OrbiTextField(
                          label: l.educationDegree,
                          optional: true,
                          controller: e.degree,
                          enabled: e.include && !e.duplicate,
                        ),
                        const SizedBox(height: AppSpace.s3),
                        OrbiTextField(
                          label: l.educationField,
                          optional: true,
                          controller: e.field,
                          enabled: e.include && !e.duplicate,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A small error banner (same look as the account messages).
class AuthMessageLike extends StatelessWidget {
  const AuthMessageLike({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: AppSize.iconSm,
                color: c.onErrorContainer,
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  text,
                  style: context.text.bodyMedium!.copyWith(
                    color: c.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
