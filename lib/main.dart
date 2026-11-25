import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const siteUrl = 'https://sites.google.com/view/yandepderche/';
const appVersion = '1.0.0';
const brand = Color(0xFF0F766E);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: b),
        appBarTheme: const AppBarTheme(centerTitle: false),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Yandepderçe',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final WebViewController _c;
  int _progress = 0;
  _Status _status = _Status.loading;
  bool _slow = false;
  Timer? _timeout;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: (_) {
          if (_status == _Status.loading) {
            _timeout?.cancel();
            setState(() => _status = _Status.ready);
          }
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) _fail(slow: false);
        },
        onNavigationRequest: (req) {
          final host = Uri.tryParse(req.url)?.host ?? '';
          final inApp = host.contains('google') ||
              host.contains('gstatic') ||
              host.contains('googleusercontent');
          if (!req.isMainFrame || inApp) return NavigationDecision.navigate;
          launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ));
    // Internet gaýdyp gelende awtomatiki gaýtadan ýükle
    _connSub = Connectivity().onConnectivityChanged.listen((r) {
      final online = r.any((x) => x != ConnectivityResult.none);
      if (online && _status == _Status.offline) _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(first: true));
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    try {
      final r = await InternetAddress.lookup('sites.google.com')
          .timeout(const Duration(seconds: 5));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _fail({required bool slow}) {
    _timeout?.cancel();
    if (!mounted) return;
    setState(() {
      _status = _Status.offline;
      _slow = slow;
    });
  }

  Future<void> _load({bool first = false}) async {
    setState(() {
      _status = _Status.loading;
      _progress = 0;
    });
    if (!await _hasInternet()) {
      _fail(slow: false);
      return;
    }
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 25), () {
      if (_status == _Status.loading) _fail(slow: true);
    });
    String url = siteUrl;
    if (!first) {
      final cur = await _c.currentUrl();
      if (cur != null && cur.startsWith('http')) url = cur;
    }
    await _c.loadRequest(Uri.parse(url));
  }

  Future<void> _onBack() async {
    final s = _scaffoldKey.currentState;
    if (s != null && s.isDrawerOpen) {
      s.closeDrawer();
    } else if (_status == _Status.ready && await _c.canGoBack()) {
      _c.goBack();
    } else {
      SystemNavigator.pop();
    }
  }

  void _go(VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  void _showInfo(String title, List<Widget> body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: body,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ýap')),
        ],
      ),
    );
  }

  void _aboutDev() => _showInfo('Programmist barada', const [
        Text('Oraz Çarýarow',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text('Android programma düzüji'),
        SizedBox(height: 12),
        Text('Ýeňil, çalt we ulanmaga aňsat programmalar döredýär. '
            'Web sahypasy we täze işleri bilen şu programma arkaly tanyşyp bilersiň.'),
      ]);

  void _aboutApp() => _showInfo('App barada', const [
        Text('Yandepderçe',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text('Wersiýa $appVersion'),
        SizedBox(height: 12),
        Text('Bu programma Oraz Çarýarowyň web sahypasyny telefonda ýeňil '
            'we çalt açmak üçin döredildi. Flutter bilen ýasaldy, '
            'Android 7.0 we ondan ýokary wersiýalarda işleýär.'),
      ]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Yandepderçe'),
          bottom: _status == _Status.ready && _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                      value: _progress / 100, minHeight: 3),
                )
              : null,
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  color: cs.primaryContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: cs.primary,
                        child: Text('OÇ',
                            style: TextStyle(
                                color: cs.onPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 12),
                      Text('Oraz Çarýarow',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer)),
                      Text('Android app düzüji',
                          style: TextStyle(color: cs.onPrimaryContainer)),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Baş sahypa'),
                  onTap: () => _go(() {
                    _c.loadRequest(Uri.parse(siteUrl));
                    if (_status != _Status.ready) _load(first: true);
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Täzele'),
                  onTap: () => _go(() {
                    if (_status == _Status.ready) {
                      _c.reload();
                    } else {
                      _load();
                    }
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Programmist barada'),
                  onTap: () => _go(_aboutDev),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('App barada'),
                  onTap: () => _go(_aboutApp),
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_browser),
                  title: const Text('Brauzerde aç'),
                  onTap: () => _go(() => launchUrl(Uri.parse(siteUrl),
                      mode: LaunchMode.externalApplication)),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Wersiýa $appVersion',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _c),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: switch (_status) {
                  _Status.ready => const SizedBox.shrink(),
                  _Status.loading => const _LoadingView(key: ValueKey('l')),
                  _Status.offline => _OfflineView(
                      key: const ValueKey('o'),
                      slow: _slow,
                      onRetry: _load,
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Status { loading, ready, offline }

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Image.asset('assets/icon/icon.png',
                width: 92, height: 92, cacheWidth: 256),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
                strokeWidth: 3.5, strokeCap: StrokeCap.round, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text('Garaşyň...',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView({super.key, required this.slow, required this.onRetry});
  final bool slow;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
                color: cs.primaryContainer, shape: BoxShape.circle),
            child: Icon(slow ? Icons.hourglass_empty : Icons.wifi_off_rounded,
                size: 50, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 24),
          Text(slow ? 'Baglanyşyk haýal' : 'Internet ýok',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            slow
                ? 'Sahypa wagtynda açylmady. Birazdan gaýtadan synanyşyp gör.'
                : 'Wi‑Fi ýa-da mobil maglumatyňy barla. Internet gaýdyp gelende sahypa özi açylar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Gaýtadan synanyş'),
          ),
        ],
      ),
    );
  }
}
