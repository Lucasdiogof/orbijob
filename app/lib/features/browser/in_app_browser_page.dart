import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/design.dart';
import '../../core/di/injector.dart';
import '../../core/open_link.dart';
import '../../core/orbi/orbi.dart';
import '../../l10n/app_localizations.dart';
import 'browser_engine.dart';
import 'link_share.dart';
import 'url_policy.dart';

enum _Menu { share, copy, external }

/// The job's own site, shown inside OrbiJob. Everything the person types stays between them and the site: this screen only
/// reports navigation (address, progress, errors) and never reads or changes page content, form data, cookies or headers.
///
/// A site that does not work here (sign-in flows, blocks, captchas) is one tap away from the system browser.
class InAppBrowserPage extends StatefulWidget {
  const InAppBrowserPage({super.key, required this.url});
  final Uri url;

  @override
  State<InAppBrowserPage> createState() => _InAppBrowserPageState();
}

class _InAppBrowserPageState extends State<InAppBrowserPage> {
  late Uri _current = widget.url;
  BrowserController? _controller;
  int _progress = 0;
  bool _loading = true;
  bool _firstLoadDone = false;
  bool _canBack = false;
  bool _canForward = false;
  BrowserFailure? _failure;
  bool _noticeHidden = false;

  late final BrowserEvents _events = BrowserEvents(
    onProgress: (p) {
      if (!mounted) return;
      setState(() {
        _progress = p;
        _loading = p < 100;
      });
    },
    onPageStarted: (u) {
      if (!mounted) return;
      setState(() {
        _current = u;
        _loading = true;
        _failure = null;
      });
    },
    onPageFinished: (u) {
      if (!mounted) return;
      setState(() {
        _current = u;
        _loading = false;
        _firstLoadDone = true;
      });
      _refreshHistory();
    },
    onUrlChanged: (u) {
      if (!mounted) return;
      setState(() => _current = u);
      _refreshHistory();
    },
    onFailure: (f) {
      if (!mounted) return;
      setState(() {
        _failure = f;
        _loading = false;
      });
    },
    onVerdict: _onVerdict,
  );

  Future<void> _refreshHistory() async {
    final c = _controller;
    if (c == null) return;
    final back = await c.canGoBack();
    final fwd = await c.canGoForward();
    if (mounted) {
      setState(() {
        _canBack = back;
        _canForward = fwd;
      });
    }
  }

  void _say(String text, {OrbiSnackKind kind = OrbiSnackKind.info}) {
    if (mounted) showOrbiSnackBar(context, text, kind: kind);
  }

  Future<void> _onVerdict(Uri uri, UrlVerdict verdict) async {
    final l = AppLocalizations.of(context);
    switch (verdict) {
      case UrlVerdict.download:
        _say(l.browserDownloadExternal);
        await _openExternal(uri);
      case UrlVerdict.system:
        final ok = await openSystemLink(uri);
        if (!ok) _say(l.browserCannotOpenExternal, kind: OrbiSnackKind.error);
      case UrlVerdict.block:
        _say(l.browserBlockedLink, kind: OrbiSnackKind.error);
      case UrlVerdict.allow:
        break;
    }
  }

  Future<void> _openExternal(Uri uri) async {
    final l = AppLocalizations.of(context);
    final ok = await openExternalLink(uri.toString());
    if (!ok) _say(l.browserCannotOpenExternal, kind: OrbiSnackKind.error);
  }

  Future<void> _retry() async {
    setState(() {
      _failure = null;
      _loading = true;
      _progress = 0;
    });
    final c = _controller;
    if (c == null) return;
    // a page that never loaded has nothing to reload: load the address again
    _firstLoadDone ? await c.reload() : await c.load(_current);
  }

  Future<void> _menu(_Menu m) async {
    final l = AppLocalizations.of(context);
    switch (m) {
      case _Menu.share:
        await sl<LinkShare>()(_current);
      case _Menu.copy:
        await Clipboard.setData(ClipboardData(text: _current.toString()));
        _say(l.browserLinkCopied, kind: OrbiSnackKind.success);
      case _Menu.external:
        await _openExternal(_current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final secure = _current.scheme == 'https';
    final failed = _failure != null;
    return PopScope(
      // the system back button (Android) walks the page history first, and only then leaves the browser
      canPop: !_canBack || failed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller?.goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const ValueKey('browser-close'),
            tooltip: l.browserClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: Tooltip(
            message: secure ? l.browserSecureHint : l.browserNotSecure,
            child: Row(
              children: [
                Icon(
                  secure
                      ? Icons.lock_outline_rounded
                      : Icons.warning_amber_rounded,
                  size: AppSize.iconSm,
                  color: secure ? c.success : c.warning,
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _current.host,
                        key: const ValueKey('browser-domain'),
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        secure ? l.browserSecure : l.browserNotSecure,
                        style: context.metadataStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: l.browserReload,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _retry,
            ),
            PopupMenuButton<_Menu>(
              tooltip: l.browserMore,
              onSelected: _menu,
              itemBuilder: (_) => [
                PopupMenuItem(value: _Menu.share, child: Text(l.browserShare)),
                PopupMenuItem(
                  value: _Menu.copy,
                  child: Text(l.browserCopyLink),
                ),
                PopupMenuItem(
                  value: _Menu.external,
                  child: Text(l.browserOpenExternal),
                ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _loading && !failed
                ? Semantics(
                    label: l.commonLoading,
                    child: LinearProgressIndicator(
                      value: _progress <= 0 ? null : _progress / 100,
                      minHeight: 3,
                      backgroundColor: c.container,
                      color: c.primary,
                    ),
                  )
                : const SizedBox(height: 3),
          ),
        ),
        body: Column(
          children: [
            // the page is the site's own and is never translated here: say so once, quietly
            if (!_noticeHidden)
              Material(
                color: c.container,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpace.s4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: AppSize.iconSm,
                        color: c.muted,
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(
                        child: Text(
                          l.browserLanguageNotice,
                          style: context.metadataStyle,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('browser-notice-close'),
                        tooltip: l.commonClose,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: AppSize.iconSm,
                        ),
                        onPressed: () => setState(() => _noticeHidden = true),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  // the web view stays mounted behind the error and loading layers, so "try again" can reload it
                  Positioned.fill(
                    child: sl<BrowserEngine>().view(
                      initial: widget.url,
                      events: _events,
                      onCreated: (ctl) => _controller = ctl,
                    ),
                  ),
                  if (_loading && !_firstLoadDone && !failed)
                    Positioned.fill(
                      child: ColoredBox(
                        color: c.bg,
                        child: OrbiLoadingView(label: l.commonLoading),
                      ),
                    ),
                  if (failed)
                    Positioned.fill(
                      child: ColoredBox(
                        color: c.bg,
                        child: OrbiEmptyState(
                          icon: Icons.public_off_rounded,
                          title: l.browserErrorTitle,
                          body: _failure!.isTls
                              ? l.browserErrorTls
                              : l.browserErrorBody,
                          kind: OrbiStateKind.error,
                          action: OrbiPrimaryButton(
                            label: l.retry,
                            icon: Icons.refresh_rounded,
                            onPressed: _retry,
                          ),
                          secondaryAction: OrbiSecondaryButton(
                            label: l.browserOpenExternal,
                            icon: Icons.open_in_new_rounded,
                            onPressed: () => _openExternal(_current),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    tooltip: l.browserBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _canBack ? () => _controller?.goBack() : null,
                  ),
                  IconButton(
                    tooltip: l.browserForward,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: _canForward
                        ? () => _controller?.goForward()
                        : null,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openExternal(_current),
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      size: AppSize.iconSm,
                    ),
                    label: Text(l.browserOpenExternal),
                  ),
                  const SizedBox(width: AppSpace.s2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
