import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'api_header_provider.dart';

class Webview extends StatefulWidget {
  const Webview({super.key});

  @override
  State<Webview> createState() => _WebviewState();
}

class _WebviewState extends State<Webview> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  Map<String, String>? _initialHeaders;

  @override
  void initState() {
    super.initState();
    _loadInitialHeaders();
  }

  Future<void> _loadInitialHeaders() async {
    final headers = await ApiHeaderProvider.buildHeaders();
    if (mounted) {
      setState(() {
        _initialHeaders = headers;
      });
    }
  }

  Future<void> _launchExternal(String urlStr) async {
    try {
      final cleanUrl = urlStr.replaceAll('intent://', 'https://');
      await launchUrl(
        Uri.parse(cleanUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Gagal membuka URL eksternal: $e');
    }
  }

  Future<void> _navigateToMainLogin() async {
    if (_webViewController != null) {
      final freshHeaders = await ApiHeaderProvider.buildHeaders();
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri('https://app.hostborneo.org/login'),
          headers: freshHeaders,
          cachePolicy: URLRequestCachePolicy.RELOAD_IGNORING_LOCAL_CACHE_DATA,
        ),
      );
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
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://app.hostborneo.org/login'),
                  headers: _initialHeaders,
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  useShouldInterceptRequest: true,
                  useShouldOverrideUrlLoading: true,
                  supportMultipleWindows: false,
                  javaScriptCanOpenWindowsAutomatically: true,
                  userAgent:
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  hardwareAcceleration: true,
                  cacheMode: CacheMode.LOAD_NO_CACHE,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;

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
                },
                onLoadStop: (controller, url) {
                  setState(() {
                    _isLoading = false;
                  });

                  controller.evaluateJavascript(
                    source: """
                    (function() {
                      if (window.__externalClickInterceptor) return;
                      window.__externalClickInterceptor = true;

                      document.addEventListener('click', function(e) {
                        const el = e.target.closest('a, button, div, span');
                        if (!el) return;

                        const text = (el.innerText || '').toLowerCase().trim();
                        const href = (el.getAttribute('href') || '').toLowerCase();

                        if (text.includes('back to login') || text.includes('kembali ke login')) {
                          e.preventDefault();
                          e.stopPropagation();
                          window.flutter_inappwebview.callHandler('backToMainLogin');
                          return;
                        }

                        if (text.includes('register') || 
                            href.includes('register') || 
                            text.includes('signup') ||
                            href.includes('signup') ||
                            text.includes('buat akun') ||
                            text.includes('daftar') || 
                            text === 'login' || 
                            text === 'masuk' ||
                            el.type === 'submit') {
                          return;
                        }

                        const isReq = text.includes('system requirement') || href.includes('requirement');
                        const isBuy = text.includes('buy activation') || href.includes('pricing') || href.includes('buy');
                        const isSupport = text.includes('contact support') || text.includes('login problem') || href.includes('support') || href.includes('bit.ly');
                        const isRenewal = text.includes('renewal') || text.includes('perpanjang') || href.includes('renewal');
                        const isUpdate = text.includes('download new update') || text.includes('check & download') || href.includes('update');
                        const isForgot = text.includes('forgot password') || text.includes('lupa password') || href.includes('forgot');

                        if (isReq || isBuy || isSupport || isRenewal || isUpdate || isForgot) {
                          e.preventDefault();
                          e.stopPropagation();

                          let targetUrl = el.getAttribute('href');
                          if (!targetUrl || targetUrl.startsWith('#') || targetUrl.startsWith('javascript:') || targetUrl.includes('/renewal')) {
                            if (isReq || isUpdate) targetUrl = 'https://updateborneo.com';
                            else if (isBuy) targetUrl = 'https://borneoschematics.com/pricing';
                            else if (isRenewal) targetUrl = 'https://portal.borneoschematic.com/signin';
                            else if (isSupport) targetUrl = 'https://bit.ly/borneosupport';
                            else if (isForgot) targetUrl = 'https://app.hostborneo.org/forgot-password';
                            else targetUrl = 'https://updateborneo.com';
                          }

                          window.flutter_inappwebview.callHandler('openInExternalBrowser', targetUrl);
                        }
                      }, true);
                    })();
                  """,
                  );
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri == null) return NavigationActionPolicy.ALLOW;

                  final urlStr = uri.toString().toLowerCase();
                  final host = uri.host.toLowerCase();
                  final path = uri.path.toLowerCase();

                  if (urlStr.startsWith('whatsapp://') ||
                      urlStr.startsWith('intent://') ||
                      urlStr.contains('wa.me') ||
                      urlStr.contains('api.whatsapp.com') ||
                      urlStr.startsWith('tel:') ||
                      urlStr.startsWith('mailto:')) {
                    _launchExternal(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (urlStr.contains('portal.borneoschematic.com') &&
                      (path.contains('login') ||
                          path.contains('signin') ||
                          urlStr.contains('back'))) {
                    _navigateToMainLogin();
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (path.contains('renewal') || urlStr.contains('renewal')) {
                    _launchExternal(
                      'https://portal.borneoschematic.com/signin',
                    );
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (path.contains('requirement') ||
                      path.contains('support') ||
                      path.contains('pricing') ||
                      path.contains('forgot') ||
                      urlStr.contains('updateborneo') ||
                      urlStr.contains('bit.ly')) {
                    _launchExternal(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  final isRegisterFlow =
                      urlStr.contains('portal.borneoschematic.com') ||
                      urlStr.contains('signup') ||
                      urlStr.contains('register') ||
                      urlStr.contains('buat-akun');

                  final hasFreshHeader =
                      navigationAction.request.headers?.containsKey(
                        'x-device-id',
                      ) ??
                      false;

                  if (isRegisterFlow && !hasFreshHeader) {
                    final freshHeaders = await ApiHeaderProvider.buildHeaders();
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

                  if (host.contains('borneo') || host.isEmpty) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  _launchExternal(uri.toString());
                  return NavigationActionPolicy.CANCEL;
                },
                shouldInterceptRequest: (controller, request) async {
                  final uri = request.url;
                  if (uri == null) return null;

                  final urlStr = uri.toString().toLowerCase();
                  final path = uri.path.toLowerCase();

                  if (path.endsWith('.css') ||
                      path.endsWith('.png') ||
                      path.endsWith('.jpg') ||
                      path.endsWith('.jpeg') ||
                      path.endsWith('.svg') ||
                      path.endsWith('.woff') ||
                      path.endsWith('.woff2') ||
                      path.endsWith('.js') ||
                      path.endsWith('.ico')) {
                    return null;
                  }

                  if (urlStr.contains('portal.') ||
                      urlStr.contains('signup') ||
                      urlStr.contains('signin') ||
                      urlStr.contains('register') ||
                      urlStr.contains('/login') ||
                      path.endsWith('.html') ||
                      path.endsWith('.php')) {
                    return null;
                  }

                  final isApiCall =
                      (urlStr.contains('/token') || urlStr.contains('/api/')) &&
                      !urlStr.contains('portal.');

                  if (!isApiCall) return null;

                  try {
                    final securityHeaders =
                        await ApiHeaderProvider.buildHeaders();
                    final mergedHeaders = Map<String, String>.from(
                      request.headers ?? {},
                    )..addAll(securityHeaders);

                    final targetUri = Uri.parse(request.url.toString());
                    http.Response response;

                    if (request.method == 'POST') {
                      return null;
                    } else {
                      response = await http.get(
                        targetUri,
                        headers: mergedHeaders,
                      );
                    }

                    final contentType =
                        response.headers['content-type'] ?? 'application/json';
                    final mimeType = contentType.split(';').first.trim();

                    return WebResourceResponse(
                      contentType: mimeType,
                      contentEncoding:
                          response.headers['content-encoding'] ?? 'utf-8',
                      statusCode: response.statusCode,
                      reasonPhrase: response.reasonPhrase ?? 'OK',
                      headers: response.headers,
                      data: response.bodyBytes,
                    );
                  } catch (e) {
                    debugPrint('Intercept Error: $e');
                    return null;
                  }
                },
              ),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
