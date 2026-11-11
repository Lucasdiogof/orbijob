import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/auth/domain/legal_consent.dart';
import 'package:orbijob/features/auth/presentation/auth_cubit.dart';

import '../helpers/fakes.dart';

class _Recorder implements ConsentRecorder {
  _Recorder(this.result);
  ConsentRecordResult result;
  final calls = <String>[];
  @override
  Future<ConsentRecordResult> record(String t, String p) async {
    calls.add('$t|$p');
    return result;
  }
}

class _Store implements ConsentStore {
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String? v) async => value = v;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAuth auth;
  late _Store store;
  AuthCubit make(_Recorder r) =>
      AuthCubit(auth, consentRecorder: r, consentStore: store);

  setUp(() {
    auth = FakeAuth();
    store = _Store();
  });

  test('with e-mail confirmation the server record waits for the first session of that person', () async {
    final r = _Recorder(ConsentRecordResult.recorded);
    final c = make(r);
    await c.signUp('Ana@Example.com', 'password123');
    await _settle();
    expect(r.calls, isEmpty); // no session yet
    expect(store.value, isNotNull);
    auth.emit(const AuthUser(id: 'x', email: 'someone@else.com'));
    await _settle();
    expect(r.calls, isEmpty); // another person on the device never gets it
    expect(store.value, isNotNull);
    auth.emit(const AuthUser(id: 'a', email: 'ana@example.com'));
    await _settle();
    expect(r.calls, ['$termsVersion|$privacyVersion']);
    expect(store.value, isNull);
    await c.close();
  });

  test(
    'a server without the function yet never disturbs the sign-up',
    () async {
      final r = _Recorder(ConsentRecordResult.unavailable);
      final c = make(r);
      await c.signUp('ana@example.com', 'password123');
      expect(c.state.failure, isNull);
      auth.emit(const AuthUser(id: 'a', email: 'ana@example.com'));
      await _settle();
      expect(r.calls, hasLength(1));
      expect(store.value, isNull); // dropped, not retried forever
      await c.close();
    },
  );

  test('a network failure keeps the acceptance for the next session', () async {
    final r = _Recorder(ConsentRecordResult.failed);
    final c = make(r);
    await c.signUp('ana@example.com', 'password123');
    auth.emit(const AuthUser(id: 'a', email: 'ana@example.com'));
    await _settle();
    expect(store.value, isNotNull);
    r.result = ConsentRecordResult.recorded;
    auth.emit(null);
    auth.emit(const AuthUser(id: 'a', email: 'ana@example.com'));
    await _settle();
    expect(store.value, isNull);
    await c.close();
  });

  test('pending value codec', () {
    expect(decodePendingConsent(encodePendingConsent(' A@B.co ', 't', 'p')), (
      email: 'a@b.co',
      terms: 't',
      privacy: 'p',
    ));
    expect(decodePendingConsent('broken'), isNull);
    expect(decodePendingConsent(null), isNull);
  });
}
