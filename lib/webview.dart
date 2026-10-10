import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'api_header_provider.dart';
import 'system_info.dart';

/// Saklar untuk bisect. Kalau logout error lagi, matikan satu per satu
/// (ubah ke false) lalu hot restart untuk mencari biang keroknya.
class _Flags {
  /// Patch fetch/XHR untuk menyisipkan header x-*.
  static const bool injectHeaders = true;

  /// Click guard (intersep klik link tertentu).
  static const bool clickGuard = true;

  /// UA mengikuti perangkat (hanya Android; iOS selalu UA bawaan).
  static const bool deviceUserAgent = true;

  /// Android: true = tanpa cache (sama seperti kode awal yang aman).
  static const bool noCacheAndroid = true;

  /// Bersihkan cache HTTP saat berpindah dari halaman aplikasi ke /login
  /// (cookie & localStorage TIDAK dihapus).
  static const bool clearCacheOnLogin = true;

  /// iOS: sinkron cookie ke HTTPCookieStorage.shared. Bisa membuat cookie
  /// sesi lama "hidup lagi" setelah logout, jadi default dimatikan.
  static const bool sharedCookies = false;

  /// Kirim error JS (window.onerror, unhandledrejection, fetch gagal) ke
  /// log Flutter supaya penyebab ERR_RUNTIME kelihatan.
  static const bool jsErrorLogging = true;
}

/// Aturan routing URL (internal vs eksternal).
class _WebRules {
  static const mainLoginUrl = 'https://app.hostborneo.org/login';
  static const portalHost = 'portal.borneoschematic.com';

  /// Selalu dibuka di dalam WebView.
  static const internalHosts = ['hostborneo.org', 'borneoschematic.com'];

  /// Host captcha / human-verification. JANGAN pernah dicegat atau dilempar keluar.
  static const captchaHosts = [
    'cloudflare.com',
    'cloudflareinsights.com',
    'hcaptcha.com',
    'recaptcha.net',
    'gstatic.com',
  ];

  /// Selalu dibuka di browser eksternal (kalau jadi navigasi utama).
  static const externalHosts = [
    'updateborneo.com',
    'bit.ly',
    'linktr.ee',
    'borneoschematics.com', // website marketing (pakai "s"), beda dengan portal
    'wa.me',
    'api.whatsapp.com',
  ];

  static bool hostIn(String host, List<String> list) {
    final h = host.toLowerCase();
    return list.any((s) => h == s || h.endsWith('.$s'));
  }

  static bool isRegisterUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('signup') ||
        u.contains('sign-up') ||
        u.contains('register') ||
        u.contains('buat-akun') ||
        u.contains('daftar');
  }

  /// Path login / logout. Navigasi ini TIDAK BOLEH dilempar ke browser luar.
  static bool isAuthPath(String path) {
    final p = path.toLowerCase();
    return p.contains('login') ||
        p.contains('logout') ||
        p.contains('signout') ||
        p.contains('sign-out');
  }
}

/// Click guard. RAW string supaya regex JS (\s dll) aman.
///
/// Perbaikan utama:
/// - Hanya bereaksi pada elemen yang memang bisa diklik (a/button/role=button),
///   BUKAN div/span.
/// - Teks hanya dicocokkan kalau pendek (<= 60 karakter).
/// - Klik pada logo diblokir (tidak navigasi ke href).
/// - BUG FIX: regex logo dulu /logo|brand|borneo/ sehingga "logout" ikut
///   cocok (karena "logo" ada di dalam "logout"). Sekarang memakai batas
///   kata, dan elemen logout tidak pernah disentuh.
const String _clickGuardScript = r"""
(function() {
  if (window.__borneoClickGuard) return;
  window.__borneoClickGuard = true;

  var CLICKABLE = 'a[href], button, [role="button"], [role="link"], input[type="submit"], input[type="button"]';
  var LOGO_RE = /(^|[^a-z])(logo|brand)([^a-z]|$)/i;
  var LOGOUT_RE = /log-?out|sign-?out|keluar/i;
  var LOGOUT_SEL = '[class*="logout" i],[id*="logout" i],[href*="logout" i],[aria-label*="logout" i],[class*="signout" i],[id*="signout" i]';

  function norm(s) { return (s || '').replace(/\s+/g, ' ').trim().toLowerCase(); }
  function attr(el, name) { return (el && el.getAttribute && el.getAttribute(name)) || ''; }
  function stop(e) {
    e.preventDefault();
    e.stopPropagation();
    if (e.stopImmediatePropagation) e.stopImmediatePropagation();
  }
  function call(name, arg) {
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler(name, arg);
      }
    } catch (err) {}
  }

  document.addEventListener('click', function(e) {
    var node = e.target;
    if (!node || !node.closest) return;

    // ---- 0. Logout / sign out: jangan pernah diganggu ----
    try {
      if (node.closest(LOGOUT_SEL)) return;
      var clickable0 = node.closest('a[href], button, [role="button"], [role="link"]');
      if (clickable0 && LOGOUT_RE.test(norm(clickable0.innerText) + ' ' + attr(clickable0, 'aria-label') + ' ' + attr(clickable0, 'title'))) return;
    } catch (err) {}

    // ---- 1. Logo: jangan navigasi ke mana-mana ----
    var img = node.closest('img, svg, picture');
    var link = node.closest('a[href]');
    var imgMeta = img ? [attr(img, 'alt'), attr(img, 'src'), attr(img, 'class'), attr(img, 'id')].join(' ') : '';
    var linkMeta = link ? [attr(link, 'class'), attr(link, 'id'), attr(link, 'aria-label'), attr(link, 'title')].join(' ') : '';

    if (img && LOGO_RE.test(imgMeta)) { stop(e); return; }
    if (link) {
      var hasGraphic = !!link.querySelector('img, svg, picture');
      var noText = norm(link.innerText) === '';
      var p = link.pathname || '';
      var isHome = (p === '' || p === '/') && !link.hash;
      if (hasGraphic && (LOGO_RE.test(linkMeta) || (noText && isHome))) { stop(e); return; }
    }

    // ---- 2. Hanya elemen klik asli. Area kosong / div / span => diabaikan ----
    var el = node.closest(CLICKABLE);
    if (!el) return;

    var text = norm(el.innerText || el.value || attr(el, 'aria-label'));
    var t = (text.length > 0 && text.length <= 60) ? text : '';
    var href = el.tagName === 'A' ? (el.href || '') : '';
    var hrefL = href.toLowerCase();

    // ---- 3. Back to login ----
    if (t.indexOf('back to login') !== -1 || t.indexOf('kembali ke login') !== -1) {
      stop(e);
      call('backToMainLogin');
      return;
    }

    // ---- 4. Register / login / submit => tetap internal ----
    if (t.indexOf('register') !== -1 ||
        t.indexOf('signup') !== -1 ||
        t.indexOf('sign up') !== -1 ||
        t.indexOf('create account') !== -1 ||
        t.indexOf('buat akun') !== -1 ||
        t.indexOf('daftar') !== -1 ||
        t === 'login' || t === 'masuk' ||
        hrefL.indexOf('register') !== -1 ||
        hrefL.indexOf('signup') !== -1 ||
        el.type === 'submit') {
      return;
    }

    // ---- 5. Link yang memang harus keluar ----
    var isReq = t.indexOf('system requirement') !== -1 || hrefL.indexOf('requirement') !== -1;
    var isBuy = t.indexOf('buy activation') !== -1 || hrefL.indexOf('pricing') !== -1 || hrefL.indexOf('/buy') !== -1;
    var isSupport = t.indexOf('contact support') !== -1 || t.indexOf('login problem') !== -1 || hrefL.indexOf('support') !== -1 || hrefL.indexOf('bit.ly') !== -1;
    var isRenewal = t.indexOf('renewal') !== -1 || t.indexOf('perpanjang') !== -1 || hrefL.indexOf('renewal') !== -1;
    var isUpdate = t.indexOf('download new update') !== -1 || t.indexOf('check & download') !== -1 || hrefL.indexOf('update') !== -1;
    var isForgot = t.indexOf('forgot password') !== -1 || t.indexOf('lupa password') !== -1 || hrefL.indexOf('forgot') !== -1;

    if (!(isReq || isBuy || isSupport || isRenewal || isUpdate || isForgot)) return;

    stop(e);

    var raw = attr(el, 'href');
    var dest = href;
    if (!raw || raw.charAt(0) === '#' || raw.indexOf('javascript:') === 0 || raw.indexOf('/renewal') !== -1) {
      if (isReq || isUpdate) dest = 'https://updateborneo.com';
      else if (isBuy) dest = 'https://borneoschematics.com/pricing';
      else if (isRenewal) dest = 'https://portal.borneoschematic.com/signin';
      else if (isSupport) dest = 'https://bit.ly/borneosupport';
      else if (isForgot) dest = 'https://app.hostborneo.org/forgot-password';
      else dest = 'https://updateborneo.com';
    }
    call('openInExternalBrowser', dest);
  }, true);
})();
""";

class Webview extends StatefulWidget {
  const Webview({super.key});

  @override
  State<Webview> createState() => _WebviewState();
}

class _WebviewState extends State<Webview> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;
  Map<String, String>? _initialHeaders;

  String? _userAgent;

  String? _lastExternalUrl;
  DateTime _lastExternalAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastHeaderReload;

  /// true kalau sebelumnya user ada di halaman aplikasi (bukan login).
  bool _wasInsideApp = false;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  Future<String?> _buildUserAgent() async {
    if (!_Flags.deviceUserAgent || !Platform.isAndroid) return null;
    try {
      final ua = await InAppWebViewController.getDefaultUserAgent();
      // Hilangkan penanda WebView ("; wv" dan "Version/4.0") agar terbaca
      // seperti Chrome Android biasa.
      return ua
          .replaceAll('; wv)', ')')
          .replaceAll(RegExp(r'Version/\d+\.\d+\s'), '');
    } catch (e) {
      debugPrint('Gagal ambil default UA: $e');
      return null;
    }
  }

  Future<void> _loadHeaders() async {
    final headers = await ApiHeaderProvider.buildHeaders();
    headers['Accept'] =
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
    final ua = await _buildUserAgent();

    if (mounted) {
      setState(() {
        _initialHeaders = headers;
        _userAgent = ua;
      });
    }
  }

  Future<void> _launchExternal(String urlStr) async {
    // Cegah double-launch untuk URL yang sama dalam 1 detik.
    final now = DateTime.now();
    if (urlStr == _lastExternalUrl &&
        now.difference(_lastExternalAt) < const Duration(seconds: 1)) {
      return;
    }
    _lastExternalUrl = urlStr;
    _lastExternalAt = now;

    try {
      final cleanUrl = urlStr.replaceAll('intent://', 'https://');
      final uri = Uri.tryParse(cleanUrl);
      if (uri == null || !uri.hasScheme) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Gagal membuka URL eksternal: $e');
    }
  }

  Future<void> _navigateToMainLogin() async {
    if (_webViewController != null) {
      final freshHeaders = await ApiHeaderProvider.buildHeaders();
      freshHeaders['Accept'] =
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(_WebRules.mainLoginUrl),
          headers: freshHeaders,
          cachePolicy: URLRequestCachePolicy.RELOAD_IGNORING_LOCAL_CACHE_DATA,
        ),
      );
    }
  }

  /// Dipanggil setiap route berubah (termasuk SPA pushState). Kalau user
  /// pindah dari halaman aplikasi ke /login (logout), cache HTTP dibersihkan
  /// agar bundle / respons lama tidak bentrok dengan sesi yang baru dihapus.
  Future<void> _handleRouteChange(WebUri? url) async {
    final path = url?.path.toLowerCase() ?? '';
    if (path.isEmpty) return;

    final onAuthPage =
        _WebRules.isAuthPath(path) ||
        _WebRules.isRegisterUrl(path) ||
        path.contains('signin') ||
        path.contains('forgot');

    if (onAuthPage) {
      if (_wasInsideApp && _Flags.clearCacheOnLogin) {
        _wasInsideApp = false;
        try {
          await InAppWebViewController.clearAllCache();
        } catch (e) {
          debugPrint('Gagal clear cache: $e');
        }
      }
    } else {
      _wasInsideApp = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialHeaders == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Patch XHR + fetch: sisipkan header x-* (termasuk signature) ke request
    // ke domain internal.
    //
    // Perubahan dibanding versi sebelumnya:
    // - Tidak ada lagi "await refresh()" di setiap fetch. Header hanya
    //   di-refresh (maks 300 ms) kalau sudah basi > 1.5 detik.
    // - Timer refresh hanya jalan saat halaman terlihat.
    // - Objek init milik aplikasi web tidak dimutasi.
    // - XHR: header yang sudah di-set oleh aplikasi tidak digandakan.
    // - Error JS / fetch gagal dilaporkan ke Flutter (handler 'jsError').
    final targetedInjectionScript =
        """
      (function() {
        if (window.__targetedInterceptorLoaded) return;
        window.__targetedInterceptorLoaded = true;

        var LOG_ERRORS = ${_Flags.jsErrorLogging};
        var INTERNAL = ['hostborneo.org', 'borneoschematic.com'];
        var activeHeaders = ${jsonEncode(_initialHeaders)};
        var lastRefresh = 0;
        var refreshing = null;
        var STALE_MS = 1500;

        function report(kind, detail) {
          if (!LOG_ERRORS) return;
          try {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('jsError', kind + ' | ' + detail);
            }
          } catch (e) {}
        }

        function refresh() {
          if (!refreshing) {
            refreshing = (async function() {
              try {
                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                  var fresh = await window.flutter_inappwebview.callHandler('getFreshHeaders');
                  if (fresh && typeof fresh === 'object') {
                    activeHeaders = fresh;
                    lastRefresh = Date.now();
                  }
                }
              } catch (e) {}
            })().then(function() { refreshing = null; });
          }
          return refreshing;
        }

        setInterval(function() {
          if (document.visibilityState === 'visible') refresh();
        }, 2000);
        ['pointerdown', 'touchstart', 'keydown'].forEach(function(n) {
          document.addEventListener(n, refresh, true);
        });

        if (LOG_ERRORS) {
          window.addEventListener('error', function(e) {
            report('window.onerror', (e.message || '') + ' @ ' + (e.filename || '') + ':' + (e.lineno || '') + ':' + (e.colno || ''));
          });
          window.addEventListener('unhandledrejection', function(e) {
            var r = e.reason;
            report('unhandledrejection', (r && (r.stack || r.message)) || String(r));
          });
        }

        function shouldAttach(input) {
          try {
            var raw = (input && input.url) ? input.url : input.toString();
            var h = new URL(raw, location.href).hostname.toLowerCase();
            return INTERNAL.some(function(d) { return h === d || h.endsWith('.' + d); });
          } catch (e) { return false; }
        }

        // ---------- XHR ----------
        var origOpen = XMLHttpRequest.prototype.open;
        var origSend = XMLHttpRequest.prototype.send;
        var origSetHeader = XMLHttpRequest.prototype.setRequestHeader;

        XMLHttpRequest.prototype.open = function(method, url) {
          this._targetUrl = url;
          this._appHeaders = {};
          return origOpen.apply(this, arguments);
        };

        XMLHttpRequest.prototype.setRequestHeader = function(k, v) {
          try {
            if (!this._appHeaders) this._appHeaders = {};
            this._appHeaders[String(k).toLowerCase()] = true;
          } catch (e) {}
          return origSetHeader.apply(this, arguments);
        };

        XMLHttpRequest.prototype.send = function(data) {
          if (shouldAttach(this._targetUrl)) {
            var self = this;
            var already = this._appHeaders || {};
            Object.keys(activeHeaders).forEach(function(k) {
              var lk = k.toLowerCase();
              if (lk.indexOf('x-') === 0 && !already[lk]) {
                try { origSetHeader.call(self, k, String(activeHeaders[k])); } catch (e) {}
              }
            });
          }
          if (LOG_ERRORS) {
            var u = this._targetUrl;
            this.addEventListener('error', function() { report('xhr-fail', String(u)); });
          }
          return origSend.call(this, data);
        };

        // ---------- fetch ----------
        var origFetch = window.fetch;
        window.fetch = function(input, init) {
          if (!shouldAttach(input)) {
            return origFetch.call(window, input, init);
          }

          var prep = Promise.resolve();
          if (Date.now() - lastRefresh > STALE_MS) {
            prep = Promise.race([
              refresh(),
              new Promise(function(r) { setTimeout(r, 300); })
            ]).catch(function() {});
          }

          return prep.then(function() {
            var nextInit = Object.assign({}, init || {});
            var src = nextInit.headers;
            if (!src && typeof Request !== 'undefined' && input instanceof Request) {
              src = input.headers;
            }
            var headers = new Headers(src);
            Object.keys(activeHeaders).forEach(function(k) {
              if (k.toLowerCase().indexOf('x-') === 0) headers.set(k, String(activeHeaders[k]));
            });
            nextInit.headers = headers;

            return origFetch.call(window, input, nextInit).catch(function(e) {
              var u = (input && input.url) ? input.url : String(input);
              report('fetch-fail', u + ' : ' + e);
              throw e;
            });
          });
        };
      })();
    """;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_webViewController != null) {
          final currentUrl =
              (await _webViewController!.getUrl())?.toString().toLowerCase() ??
              '';

          if (currentUrl.contains('portal.') ||
              currentUrl.contains('signup') ||
              currentUrl.contains('register') ||
              currentUrl.contains('signin')) {
            await _navigateToMainLogin();
            return;
          }

          if (await _webViewController!.canGoBack()) {
            await _webViewController!.goBack();
          } else {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: AppBar(
            elevation: 1,
            backgroundColor: const Color(0xFF1E222D),
            titleSpacing: 12,
            title: Row(
              children: [
                Image.asset(
                  'assets/images/app_logo.png',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.hub,
                    color: Colors.purpleAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Borneo Schematics',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Version: ${_initialHeaders?['x-app-version'] ?? '1.0.9659.13774'} - '
                        '[IDIPv6]: ${_initialHeaders?['x-publicip'] ?? '2001:448a:2003:4f57:2cac:5eb0:b9ff:24f2'} - '
                        'CID: ${_initialHeaders?['x-cid'] ?? 'BI5SHACABRZQUhxUVVQ='}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white60,
                          fontFamily: 'monospace',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Get Help, Support & Media',
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      size: 18,
                      color: Colors.blueAccent,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Help & Media',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ),
                color: const Color(0xFF252936),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'update_site':
                      _launchExternal('https://updateborneo.com');
                      break;
                    case 'tutorials':
                      _launchExternal('https://linktr.ee/OfficialBorneoMedia');
                      break;
                    case 'support':
                      _launchExternal('https://bit.ly/borneosupport');
                      break;
                    case 'camera':
                      _launchExternal('https://updateborneo.com');
                      break;
                    case 'system_info':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SystemInfoDevice(headers: _initialHeaders ?? {}),
                        ),
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'update_site',
                    child: Row(
                      children: [
                        Icon(Icons.public, size: 18, color: Colors.blueAccent),
                        SizedBox(width: 10),
                        Text(
                          'Official Update Site',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'tutorials',
                    child: Row(
                      children: [
                        Icon(
                          Icons.ondemand_video,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Tutorials & Media',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'support',
                    child: Row(
                      children: [
                        Icon(
                          Icons.headset_mic,
                          size: 18,
                          color: Colors.greenAccent,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Help & Support',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'camera',
                    child: Row(
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 18,
                          color: Colors.orangeAccent,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Camera Diagnostic',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'system_info',
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: Colors.amberAccent,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'EULA & System Info',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            bottom: _isLoading
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(2),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.blueAccent,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_WebRules.mainLoginUrl),
                  headers: _initialHeaders,
                ),
                // forMainFrameOnly: true => script TIDAK masuk ke iframe
                // Cloudflare Turnstile (patch fetch/XHR di dalam iframe
                // challenge bisa membuat verifikasi gagal).
                initialUserScripts: UnmodifiableListView<UserScript>([
                  if (_Flags.clickGuard)
                    UserScript(
                      source: _clickGuardScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      forMainFrameOnly: true,
                    ),
                  if (_Flags.injectHeaders)
                    UserScript(
                      source: targetedInjectionScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      forMainFrameOnly: true,
                    ),
                ]),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  useShouldInterceptRequest: Platform.isAndroid,
                  useShouldOverrideUrlLoading: true,
                  supportMultipleWindows: false,
                  javaScriptCanOpenWindowsAutomatically: true,
                  // null/kosong => pakai UA bawaan perangkat.
                  userAgent: _userAgent ?? '',
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  hardwareAcceleration: true,
                  // Android: sama seperti kode awal (tanpa cache) supaya
                  // aman setelah logout. Ubah lewat _Flags.noCacheAndroid.
                  cacheMode: _Flags.noCacheAndroid
                      ? CacheMode.LOAD_NO_CACHE
                      : CacheMode.LOAD_DEFAULT,
                  // Turnstile berjalan di iframe lintas-domain (Android).
                  thirdPartyCookiesEnabled: true,
                  // iOS: lihat penjelasan di _Flags.sharedCookies.
                  sharedCookiesEnabled: _Flags.sharedCookies,
                  allowsInlineMediaPlayback: true,
                  isInspectable: kDebugMode,
                ),
                onProgressChanged: (controller, progress) {
                  if (!mounted) return;
                  setState(() {
                    _progress = progress / 100;
                  });
                  if (progress > 60 && _isLoading) {
                    setState(() => _isLoading = false);
                  }
                },
                onWebViewCreated: (controller) {
                  _webViewController = controller;

                  controller.addJavaScriptHandler(
                    handlerName: 'getFreshHeaders',
                    callback: (args) async {
                      return await ApiHeaderProvider.buildHeaders();
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'openInExternalBrowser',
                    callback: (args) {
                      if (args.isNotEmpty && args[0] != null) {
                        _launchExternal(args[0].toString());
                      }
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'backToMainLogin',
                    callback: (args) {
                      _navigateToMainLogin();
                    },
                  );

                  // Error JS dari halaman web (penyebab ERR_RUNTIME).
                  controller.addJavaScriptHandler(
                    handlerName: 'jsError',
                    callback: (args) {
                      if (kDebugMode && args.isNotEmpty) {
                        debugPrint('[WEB JS ERROR] ${args[0]}');
                      }
                    },
                  );
                },
                onConsoleMessage: (controller, message) {
                  if (kDebugMode) {
                    debugPrint(
                      '[WEB CONSOLE ${message.messageLevel}] ${message.message}',
                    );
                  }
                },
                onUpdateVisitedHistory: (controller, url, isReload) {
                  _handleRouteChange(url);
                },
                onLoadStop: (controller, url) {
                  _lastHeaderReload = null;

                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _progress = 1.0;
                    });
                  }

                  // Idempotent (dijaga flag window.__targetedInterceptorLoaded).
                  if (_Flags.injectHeaders) {
                    controller.evaluateJavascript(
                      source: targetedInjectionScript,
                    );
                  }

                  // Idempotent (dijaga flag window.__borneoClickGuard).
                  if (_Flags.clickGuard) {
                    controller.evaluateJavascript(source: _clickGuardScript);
                  }
                },
                onLoadError: (controller, url, code, message) {
                  debugPrint('WebView Error [$code]: $message on URL: $url');
                  if (mounted) setState(() => _isLoading = false);
                },
                onLoadHttpError: (controller, url, statusCode, description) {
                  debugPrint(
                    'HTTP Error [$statusCode]: $description on URL: $url',
                  );
                  if (mounted) setState(() => _isLoading = false);
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri == null) return NavigationActionPolicy.ALLOW;

                  final scheme = uri.scheme.toLowerCase();
                  final host = uri.host.toLowerCase();
                  final path = uri.path.toLowerCase();
                  final full = uri.toString().toLowerCase();

                  // 1. Skema khusus => aplikasi eksternal.
                  if (const [
                        'tel',
                        'mailto',
                        'sms',
                        'whatsapp',
                        'intent',
                      ].contains(scheme) ||
                      host == 'wa.me' ||
                      host == 'api.whatsapp.com') {
                    _launchExternal(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  // 2. about:, blob:, data:, javascript: dll => biarkan.
                  if (scheme != 'http' && scheme != 'https') {
                    return NavigationActionPolicy.ALLOW;
                  }

                  // 3. Navigasi di iframe (Turnstile, embed) => JANGAN diganggu.
                  if (!navigationAction.isForMainFrame) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  // 4. Host captcha => selalu internal.
                  if (_WebRules.hostIn(host, _WebRules.captchaHosts)) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  final isInternal = _WebRules.hostIn(
                    host,
                    _WebRules.internalHosts,
                  );

                  // 4b. Login / logout di host aplikasi => selalu internal,
                  // tidak boleh terkena aturan "lempar keluar" di bawah.
                  // (Portal tetap ditangani aturan khususnya di langkah 5.)
                  if (isInternal &&
                      host != _WebRules.portalHost &&
                      _WebRules.isAuthPath(path)) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  final currentUrl =
                      (await controller.getUrl())?.toString() ?? '';
                  final onRegisterPage = _WebRules.isRegisterUrl(currentUrl);
                  final goingToRegister = _WebRules.isRegisterUrl(full);

                  // 5. Alur register: tidak boleh terkena aturan "lempar keluar".
                  if (!goingToRegister) {
                    // Portal login/signin => kembali ke login utama.
                    if (host == _WebRules.portalHost &&
                        (path.contains('login') ||
                            path.contains('signin') ||
                            path.endsWith('/back'))) {
                      _navigateToMainLogin();
                      return NavigationActionPolicy.CANCEL;
                    }

                    // Hanya cek PATH (bukan query string), supaya redirect
                    // seperti /login?next=...renewal tidak salah tangkap.
                    if (path.contains('renewal')) {
                      _launchExternal('https://${_WebRules.portalHost}/signin');
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (path.contains('requirement') ||
                        path.contains('support') ||
                        path.contains('pricing') ||
                        path.contains('forgot') ||
                        _WebRules.hostIn(host, _WebRules.externalHosts)) {
                      _launchExternal(uri.toString());
                      return NavigationActionPolicy.CANCEL;
                    }
                  }

                  // 6. Portal / register di host internal: sertakan header segar.
                  final needsHeaders =
                      isInternal &&
                      (host == _WebRules.portalHost || goingToRegister);
                  if (needsHeaders) {
                    final hasFreshHeader =
                        navigationAction.request.headers?.keys.any(
                          (k) => k.toLowerCase() == 'x-device-id',
                        ) ??
                        false;

                    if (!hasFreshHeader && _lastHeaderReload != full) {
                      _lastHeaderReload = full;
                      final freshHeaders =
                          await ApiHeaderProvider.buildHeaders();
                      freshHeaders['Accept'] =
                          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
                      await controller.loadUrl(
                        urlRequest: URLRequest(
                          url: uri,
                          headers: freshHeaders,
                          cachePolicy: URLRequestCachePolicy
                              .RELOAD_IGNORING_LOCAL_CACHE_DATA,
                        ),
                      );
                      return NavigationActionPolicy.CANCEL;
                    }
                  }

                  // 7. Internal / register => tetap di WebView.
                  if (isInternal || goingToRegister || onRegisterPage) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  // 8. Sisanya => browser eksternal.
                  _launchExternal(uri.toString());
                  return NavigationActionPolicy.CANCEL;
                },
                shouldInterceptRequest: (controller, request) async {
                  if (!Platform.isAndroid) return null;

                  final uri = request.url;

                  // Hanya API milik Borneo. Cloudflare/captcha/CDN lain
                  // TIDAK BOLEH lewat http client Dart (fingerprint TLS &
                  // cookie berbeda => challenge gagal).
                  if (!_WebRules.hostIn(uri.host, const ['hostborneo.org'])) {
                    return null;
                  }
                  if (request.isForMainFrame ?? false) return null;
                  if ((request.method ?? 'GET').toUpperCase() != 'GET') {
                    return null;
                  }

                  final path = uri.path.toLowerCase();
                  const staticExt = [
                    '.css',
                    '.png',
                    '.jpg',
                    '.jpeg',
                    '.svg',
                    '.woff',
                    '.woff2',
                    '.js',
                    '.ico',
                    '.html',
                    '.php',
                  ];
                  if (staticExt.any(path.endsWith)) return null;

                  final isApiCall =
                      path.contains('/api/') || path.contains('/token');
                  if (!isApiCall) return null;

                  try {
                    final securityHeaders =
                        await ApiHeaderProvider.buildHeaders();
                    final mergedHeaders = Map<String, String>.from(
                      request.headers ?? {},
                    )..addAll(securityHeaders);

                    final response = await http.get(
                      Uri.parse(uri.toString()),
                      headers: mergedHeaders,
                    );

                    final contentType =
                        response.headers['content-type'] ?? 'application/json';
                    final mimeType = contentType.split(';').first.trim();

                    // Body sudah didekompres oleh http client, jadi buang
                    // header yang tidak lagi valid.
                    final cleanHeaders =
                        Map<String, String>.from(response.headers)..removeWhere(
                          (k, _) => const [
                            'content-encoding',
                            'content-length',
                            'transfer-encoding',
                          ].contains(k.toLowerCase()),
                        );

                    return WebResourceResponse(
                      contentType: mimeType,
                      contentEncoding: 'utf-8',
                      statusCode: response.statusCode,
                      reasonPhrase: response.reasonPhrase ?? 'OK',
                      headers: cleanHeaders,
                      data: response.bodyBytes,
                    );
                  } catch (e) {
                    debugPrint('Intercept Error: $e');
                    return null;
                  }
                },
              ),
              if (_isLoading && _progress == 0)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
