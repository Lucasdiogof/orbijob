import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/translation/network_probe.dart';
import 'package:orbijob/features/translation/translation_cache.dart';
import 'package:orbijob/features/translation/translation_cubit.dart';
import 'package:orbijob/features/translation/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/translation_fakes.dart';

class FakeNetwork implements NetworkProbe {
  FakeNetwork(this.value);
  NetworkKind value;
  @override
  Future<NetworkKind> kind() async => value;
}

/// Counts downloads and lets a test hold one open.
class SlowPrepareEngine extends FakeEngine {
  SlowPrepareEngine() : super(ready: false);
  @override
  Future<bool> prepare(String from, String to) async {
    prepared++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    ready = true;
    return true;
  }
}

const _german =
    'Wir suchen eine Pflegefachkraft für unser Krankenhaus in Köln. Sie arbeiten im Team und betreuen Patienten auf der Station. Wir bieten einen sicheren Arbeitsplatz und Weiterbildung.';

JobPosting _job(String id) => JobPosting(
  source: 't',
  externalId: id,
  company: 'Klinik GmbH',
  title: 'Pflegefachkraft (m/w/d) im Krankenhaus',
  originalUrl: 'https://example.invalid/$id',
  description: _german,
);

TranslationCubit _cubit(
  FakeEngine engine,
  NetworkProbe? net, {
  SharedPreferences? prefs,
}) => TranslationCubit(
  TranslationService(engine: engine, cache: MemoryTranslationCache()),
  initialTarget: 'pt',
  prefs: prefs,
  network: net,
);

void main() {
  test('Wi-Fi: missing language data downloads by itself and the listing is translated', () async {
    final e = FakeEngine(ready: false);
    final c = _cubit(e, FakeNetwork(NetworkKind.unmetered));
    await c.loadDetail(_job('1'));
    expect(e.prepared, 1);
    expect(c.state.details['t:1']!.status, DetailStatus.ready);
    await c.close();
  });

  test('mobile data with the Wi-Fi policy: nothing is downloaded, the person can do it now', () async {
    final e = FakeEngine(ready: false);
    final c = _cubit(e, FakeNetwork(NetworkKind.mobile));
    await c.loadDetail(_job('1'));
    expect(e.prepared, 0);
    final d = c.state.details['t:1']!;
    expect(d.status, DetailStatus.waitingWifi);
    expect(d.downloadMb, 30);
    await c.downloadAndLoad(_job('1')); // the explicit tap
    expect(e.prepared, 1);
    expect(c.state.details['t:1']!.status, DetailStatus.ready);
    await c.close();
  });

  test('mobile data with the "always" policy downloads by itself', () async {
    SharedPreferences.setMockInitialValues({'tr.download': 'always'});
    final e = FakeEngine(ready: false);
    final c = _cubit(
      e,
      FakeNetwork(NetworkKind.mobile),
      prefs: await SharedPreferences.getInstance(),
    );
    expect(c.state.policy, DownloadPolicy.always);
    await c.loadDetail(_job('1'));
    expect(e.prepared, 1);
    expect(c.state.details['t:1']!.status, DetailStatus.ready);
    await c.close();
  });

  test(
    'the "ask" policy and an unknown network keep the manual prompt',
    () async {
      SharedPreferences.setMockInitialValues({'tr.download': 'ask'});
      final e = FakeEngine(ready: false);
      final c = _cubit(
        e,
        FakeNetwork(NetworkKind.unmetered),
        prefs: await SharedPreferences.getInstance(),
      );
      await c.loadDetail(_job('1'));
      expect(c.state.details['t:1']!.status, DetailStatus.needsDownload);
      final c2 = _cubit(FakeEngine(ready: false), null);
      await c2.loadDetail(_job('2'));
      expect(c2.state.details['t:2']!.status, DetailStatus.needsDownload);
      expect(e.prepared, 0);
      await c.close();
      await c2.close();
    },
  );

  test('no connection and no language data: says so, downloads nothing, and works once the connection is back', () async {
    final e = FakeEngine(ready: false);
    final net = FakeNetwork(NetworkKind.none);
    final c = _cubit(e, net);
    await c.loadDetail(_job('1'));
    expect(e.prepared, 0);
    expect(c.state.details['t:1']!.status, DetailStatus.offlineNoModel);
    net.value = NetworkKind.unmetered;
    await c.loadDetail(_job('1'), retry: true);
    expect(c.state.details['t:1']!.status, DetailStatus.ready);
    await c.close();
  });

  test('two listings that need the same language share one download', () async {
    final e = SlowPrepareEngine();
    final c = _cubit(e, FakeNetwork(NetworkKind.unmetered));
    await Future.wait([c.loadDetail(_job('1')), c.loadDetail(_job('2'))]);
    expect(e.prepared, 1);
    expect(c.state.details['t:1']!.status, DetailStatus.ready);
    expect(c.state.details['t:2']!.status, DetailStatus.ready);
    await c.close();
  });

  test(
    'a failed download falls back to the original with a retry state',
    () async {
      final e = FakeEngine(ready: false);
      // the engine "downloads" but the data never becomes ready
      final broken = _NeverReady();
      final c = _cubit(broken, FakeNetwork(NetworkKind.unmetered));
      await c.loadDetail(_job('1'));
      expect(broken.prepared, 1);
      expect(c.state.details['t:1']!.status, DetailStatus.failed);
      expect(e.prepared, 0);
      await c.close();
    },
  );

  test('changing the language drops what was shown, a language already matching is left alone', () async {
    final c = _cubit(
      FakeEngine(ready: false),
      FakeNetwork(NetworkKind.unmetered),
    );
    await c.loadDetail(_job('1'));
    c.setTarget('de');
    expect(c.state.details, isEmpty);
    await c.loadDetail(_job('1'));
    expect(c.state.details['t:1']!.status, DetailStatus.none);
    await c.close();
  });

  test('the policy is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final c = _cubit(FakeEngine(), null, prefs: p);
    expect(c.state.policy, DownloadPolicy.wifiOnly);
    await c.setPolicy(DownloadPolicy.always);
    expect(p.getString('tr.download'), 'always');
    expect(
      _cubit(FakeEngine(), null, prefs: p).state.policy,
      DownloadPolicy.always,
    );
    await c.close();
  });
}

/// An engine whose download "succeeds" but the data is still not there.
class _NeverReady extends FakeEngine {
  _NeverReady() : super(ready: false);
  @override
  Future<bool> prepare(String from, String to) async {
    prepared++;
    return true;
  }
}
