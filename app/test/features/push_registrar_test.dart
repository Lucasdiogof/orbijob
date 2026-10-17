import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/push/domain/push_messaging.dart';
import 'package:orbijob/features/push/push_registrar.dart';

class _Messaging implements PushMessaging {
  _Messaging({
    this.allowed = true,
    this.tok = 'token-1',
    this.plat = 'android',
  });
  bool allowed;
  String? tok;
  String? plat;
  int starts = 0;
  int deletes = 0;
  final refresh = StreamController<String>.broadcast();
  final taps = StreamController<String>.broadcast();
  @override
  String? get platform => plat;
  @override
  Future<bool> start() async {
    starts++;
    return allowed;
  }

  @override
  Future<String?> token() async => tok;
  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Stream<String> get opened => taps.stream;
  @override
  Future<void> deleteToken() async => deletes++;
}

class _Devices implements PushDevicesRepository {
  final rows = <String, String>{};
  final log = <String>[];
  bool fail = false;
  @override
  Future<void> register({
    required String token,
    required String platform,
    String? locale,
  }) async {
    if (fail) throw Exception('offline');
    rows[token] = '$platform/$locale';
    log.add('+$token');
  }

  @override
  Future<void> remove(String token) async {
    if (fail) throw Exception('offline');
    rows.remove(token);
    log.add('-$token');
  }
}

void main() {
  test(
    'signing in stores this device once, with platform and language',
    () async {
      final m = _Messaging();
      final d = _Devices();
      final r = PushRegistrar(m, d);
      await r.onSignedIn('u1', locale: 'pt-BR');
      await r.onSignedIn(
        'u1',
        locale: 'pt-BR',
      ); // rebuilds of the scope do not ask again
      expect(d.rows, {'token-1': 'android/pt-BR'});
      expect(m.starts, 1);
    },
  );

  test('a token rotation replaces the stored row', () async {
    final m = _Messaging();
    final d = _Devices();
    await PushRegistrar(m, d).onSignedIn('u1');
    m.refresh.add('token-2');
    await pumpEventQueue();
    expect(d.rows.keys, ['token-2']);
    expect(d.log, ['+token-1', '+token-2', '-token-1']);
  });

  test(
    'signing out removes the row while the session still exists, forgets the token, and the next account starts clean',
    () async {
      final m = _Messaging();
      final d = _Devices();
      final r = PushRegistrar(m, d);
      await r.onSignedIn('u1');
      await r.beforeSignOut();
      expect(d.rows, isEmpty);
      expect(m.deletes, 1);
      m.tok = 'token-b';
      await r.onSignedIn('u2');
      expect(d.rows.keys, ['token-b']);
      m.refresh.add('late'); // the first account's listener is gone
      await pumpEventQueue();
      expect(d.rows.keys, contains('late'));
      expect(d.log.where((e) => e == '+late'), hasLength(1));
    },
  );

  test(
    'no push without permission, without a platform (web) or without a backend; nothing is stored',
    () async {
      final denied = _Devices();
      await PushRegistrar(_Messaging(allowed: false), denied).onSignedIn('u1');
      expect(denied.rows, isEmpty);
      final web = _Devices();
      final webMsg = _Messaging(plat: null);
      await PushRegistrar(webMsg, web).onSignedIn('u1');
      expect(web.rows, isEmpty);
      expect(webMsg.starts, 0);
      await PushRegistrar(_Messaging(), null).onSignedIn('u1');
      await PushRegistrar(const NoPushMessaging(), _Devices()).onSignedIn('u1');
    },
  );

  test('failures never reach sign-in or sign-out', () async {
    final d = _Devices()..fail = true;
    final r = PushRegistrar(_Messaging(), d);
    await r.onSignedIn('u1');
    await r.beforeSignOut();
    final noToken = _Devices();
    await PushRegistrar(_Messaging(tok: null), noToken).onSignedIn('u1');
    expect(noToken.rows, isEmpty);
  });

  test('a tapped push is forwarded', () async {
    final m = _Messaging();
    final r = PushRegistrar(m, _Devices());
    final got = <String>[];
    final sub = r.opened.listen(got.add);
    m.taps.add('n-42');
    await pumpEventQueue();
    expect(got, ['n-42']);
    await sub.cancel();
  });
}
