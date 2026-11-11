import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/di/injector.dart';
import 'package:orbijob/features/browser/browser_engine.dart';
import 'package:orbijob/features/browser/link_share.dart';

/// Stands in for the url_launcher plugin (the test host has none): records the URLs and answers [opens].
List<String> mockLauncher(WidgetTester t, {required bool opens}) {
  final urls = <String>[];
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method == 'launch') {
      urls.add((call.arguments as Map)['url'] as String);
    }
    return opens;
  });
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return urls;
}

/// Records what the screen asks of the web view and lets a test play the part of the page.
class FakeBrowserController implements BrowserController {
  final loaded = <Uri>[];
  var reloads = 0;
  var backs = 0;
  var forwards = 0;
  bool back = false;
  bool forward = false;

  @override
  Future<void> load(Uri uri) async => loaded.add(uri);
  @override
  Future<void> reload() async => reloads++;
  @override
  Future<void> goBack() async => backs++;
  @override
  Future<void> goForward() async => forwards++;
  @override
  Future<bool> canGoBack() async => back;
  @override
  Future<bool> canGoForward() async => forward;
}

class FakeBrowserEngine implements BrowserEngine {
  final controller = FakeBrowserController();
  Uri? initial;
  BrowserEvents? events;
  var views = 0;
  var clears = 0;

  /// what the "web view" kept for the sites visited (stands for cookies/cache/local storage)
  final cookies = <String>{};

  @override
  Future<bool> clearData() async {
    clears++;
    if (failClear) throw StateError('clear failed');
    if (clearResult) cookies.clear();
    return clearResult;
  }

  /// false = the engine ran but some step failed (partial clean-up)
  var clearResult = true;

  var failClear = false;

  @override
  Widget view({
    required Uri initial,
    required BrowserEvents events,
    required ValueChanged<BrowserController> onCreated,
  }) {
    this.initial = initial;
    this.events = events;
    views++;
    onCreated(controller);
    return const SizedBox.expand(key: ValueKey('fake-web-view'));
  }
}

/// Installs the fakes after `pumpApp` (which registers the production engine) and returns them.
({FakeBrowserEngine engine, List<Uri> shared}) installFakeBrowser() {
  final engine = FakeBrowserEngine();
  final shared = <Uri>[];
  sl
    ..unregister<BrowserEngine>()
    ..registerSingleton<BrowserEngine>(engine)
    ..unregister<LinkShare>()
    ..registerSingleton<LinkShare>((uri) async => shared.add(uri));
  return (engine: engine, shared: shared);
}
