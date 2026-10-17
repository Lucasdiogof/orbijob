import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/browser/url_policy.dart';

void main() {
  UrlVerdict v(String url, {bool main = true}) =>
      decideUrl(Uri.parse(url), isMainFrame: main);

  group('what may be shown inside the app', () {
    test('http and https pages', () {
      expect(v('https://jobs.example.com/apply/123?x=1#top'), UrlVerdict.allow);
      expect(v('http://jobs.example.com/'), UrlVerdict.allow);
      expect(v('HTTPS://Jobs.Example.com/'), UrlVerdict.allow);
    });

    test('about:blank only', () {
      expect(v('about:blank'), UrlVerdict.allow);
      expect(v('about:config'), UrlVerdict.block);
    });

    test('credentials in the URL are refused (disguised destinations)', () {
      expect(v('https://bank.com@evil.example/login'), UrlVerdict.block);
      expect(v('https://user:pw@example.com/'), UrlVerdict.block);
    });

    test('a URL without a host is refused', () {
      expect(v('https:///path'), UrlVerdict.block);
    });
  });

  group('everything else is refused or handed to the system', () {
    test('dangerous and arbitrary schemes are blocked', () {
      for (final u in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'file:///sdcard/Download/x.html',
        'content://com.android.providers/x',
        'data:text/html,<script>1</script>',
        'blob:https://example.com/uuid',
        'intent://scan/#Intent;scheme=zxing;end',
        'market://details?id=com.evil',
        'itms-services://?action=download-manifest&url=https://x',
        'ftp://example.com/file',
        'whatsapp://send?text=hi',
        'myapp://deeplink',
        'view-source:https://example.com',
      ]) {
        expect(v(u), UrlVerdict.block, reason: u);
      }
    });

    test(
      'mail, phone and sms links go to the matching app, from the main frame only',
      () {
        expect(v('mailto:rh@example.com'), UrlVerdict.system);
        expect(v('tel:+5511999999999'), UrlVerdict.system);
        expect(v('sms:+5511999999999'), UrlVerdict.system);
        expect(v('mailto:rh@example.com', main: false), UrlVerdict.block);
      },
    );

    test('files are left to the system browser, which owns downloads', () {
      expect(v('https://example.com/vaga.pdf'), UrlVerdict.download);
      expect(
        v('https://example.com/a/b/Form.DOCX?download=1'),
        UrlVerdict.download,
      );
      expect(v('https://example.com/archive.zip'), UrlVerdict.download);
      // an iframe asking for a file is simply allowed to try (it cannot navigate the page)
      expect(v('https://example.com/vaga.pdf', main: false), UrlVerdict.allow);
      // no extension, a dot at the end, or a look-alike path segment
      expect(v('https://example.com/careers'), UrlVerdict.allow);
      expect(v('https://example.com/careers.'), UrlVerdict.allow);
      expect(v('https://example.com/pdf/apply'), UrlVerdict.allow);
    });
  });

  group('parseBrowsableUrl (links that come from listings)', () {
    test('accepts plain web links and trims spaces', () {
      expect(
        parseBrowsableUrl(' https://example.com/x '),
        Uri.parse('https://example.com/x'),
      );
    });

    test('rejects anything that is not a web page with a host', () {
      for (final u in [
        '',
        'example.com/no-scheme',
        'javascript:alert(1)',
        'file:///x',
        'mailto:a@b.c',
        'https://',
        'https://user@evil.example/',
        'ht!tp://bad',
      ]) {
        expect(parseBrowsableUrl(u), isNull, reason: u);
      }
    });
  });
}
