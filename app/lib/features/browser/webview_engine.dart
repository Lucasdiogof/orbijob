import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'browser_engine.dart';
import 'url_policy.dart';

/// The real engine: `webview_flutter` (Android WebView, iOS WKWebView).
///
/// Safety choices, all deliberate:
///  * no JavaScript channels and no scripts of ours are ever injected: the page's own JavaScript runs (sites need it), nothing else;
///  * navigation is filtered through [decideUrl] (http(s) only; downloads and mail/phone links go to the system);
///  * Android: local file and content access off, mixed content in compatibility mode, camera/microphone/location requests denied,
///    certificate errors are not bypassed;
///  * cookies and sessions use the platform defaults (persistent, so legitimate sign-in and application flows work); third-party
///    cookies are accepted on Android because many application portals embed their form from another domain.
class WebViewBrowserEngine implements BrowserEngine {
  const WebViewBrowserEngine();

  @override
  Widget view({
    required Uri initial,
    required BrowserEvents events,
    required ValueChanged<BrowserController> onCreated,
  }) => _WebViewHost(initial: initial, events: events, onCreated: onCreated);

  // shortcut: cookies only (the platform cookie store is shared by all web views); page caches/localStorage need a live controller
  @override
  Future<void> clearData() => WebViewCookieManager().clearCookies();
}

class _WebViewHost extends StatefulWidget {
  const _WebViewHost({
    required this.initial,
    required this.events,
    required this.onCreated,
  });
  final Uri initial;
  final BrowserEvents events;
  final ValueChanged<BrowserController> onCreated;

  @override
  State<_WebViewHost> createState() => _WebViewHostState();
}

class _WebViewHostState extends State<_WebViewHost> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final PlatformWebViewControllerCreationParams params =
        defaultTargetPlatform == TargetPlatform.iOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{
              PlaybackMediaTypes.audio,
              PlaybackMediaTypes.video,
            },
          )
        : const PlatformWebViewControllerCreationParams();
    final c = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            if (uri == null) return NavigationDecision.prevent;
            final verdict = decideUrl(uri, isMainFrame: req.isMainFrame);
            if (verdict == UrlVerdict.allow) return NavigationDecision.navigate;
            if (req.isMainFrame) widget.events.onVerdict(uri, verdict);
            return NavigationDecision.prevent;
          },
          onProgress: widget.events.onProgress,
          onPageStarted: (url) {
            final u = Uri.tryParse(url);
            if (u != null) widget.events.onPageStarted(u);
          },
          onPageFinished: (url) {
            final u = Uri.tryParse(url);
            if (u != null) widget.events.onPageFinished(u);
          },
          onUrlChange: (change) {
            final u = Uri.tryParse(change.url ?? '');
            if (u != null) widget.events.onUrlChanged(u);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              widget.events.onFailure(
                BrowserFailure(description: error.description),
              );
            }
          },
          // never click through a certificate problem
          onSslAuthError: (request) {
            request.cancel();
            widget.events.onFailure(
              const BrowserFailure(description: 'tls', isTls: true),
            );
          },
        ),
      );
    final platform = c.platform;
    if (platform is AndroidWebViewController) {
      platform
        ..setAllowFileAccess(false)
        ..setAllowContentAccess(false)
        ..setMixedContentMode(MixedContentMode.compatibilityMode)
        ..setGeolocationEnabled(false)
        ..setMediaPlaybackRequiresUserGesture(true)
        ..setOnPlatformPermissionRequest((r) => r.deny())
        ..setOnShowFileSelector(_pickFiles);
      AndroidWebViewCookieManager(
        const PlatformWebViewCookieManagerCreationParams(),
      ).setAcceptThirdPartyCookies(platform, true);
    }
    c.loadRequest(widget.initial);
    _controller = c;
    widget.onCreated(_Controller(c));
  }

  /// `<input type="file">` on Android: the system file picker, restricted to the extensions the page accepts when it names them.
  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final exts = <String>[
      for (final t in params.acceptTypes)
        if (RegExp(r'^\.[A-Za-z0-9]{1,5}$').hasMatch(t.trim()))
          t.trim().substring(1),
    ];
    final multiple = params.mode == FileSelectorMode.openMultiple;
    final picked = multiple
        ? await FilePicker.pickFiles(
            type: exts.isEmpty ? FileType.any : FileType.custom,
            allowedExtensions: exts.isEmpty ? null : exts,
          )
        : [
            ?await FilePicker.pickFile(
              type: exts.isEmpty ? FileType.any : FileType.custom,
              allowedExtensions: exts.isEmpty ? null : exts,
            ),
          ];
    return [for (final f in picked) f.uri.toString()];
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}

class _Controller implements BrowserController {
  _Controller(this._c);
  final WebViewController _c;

  @override
  Future<void> load(Uri uri) => _c.loadRequest(uri);
  @override
  Future<void> reload() => _c.reload();
  @override
  Future<void> goBack() => _c.goBack();
  @override
  Future<void> goForward() => _c.goForward();
  @override
  Future<bool> canGoBack() => _c.canGoBack();
  @override
  Future<bool> canGoForward() => _c.canGoForward();
}
