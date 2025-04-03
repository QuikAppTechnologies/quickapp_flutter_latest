import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

WebViewEnvironment? webViewEnvironment;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String webUrl = const String.fromEnvironment('WEB_URL',
      defaultValue: 'https://pixaware.co/');

  runApp(MyApp(webUrl: webUrl));
}

class MyApp extends StatefulWidget {
  final String webUrl;
  const MyApp({super.key, required this.webUrl});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();
  @override
  void initState() {
    super.initState();
    //
    // pullToRefreshController = kIsWeb ||
    //         ![TargetPlatform.iOS, TargetPlatform.android]
    //             .contains(defaultTargetPlatform)
    //     ? null
    //     : PullToRefreshController(
    //         settings: PullToRefreshSettings(
    //           color: Colors.blue,
    //         ),
    //         onRefresh: () async {
    //           if (defaultTargetPlatform == TargetPlatform.android) {
    //             webViewController?.reload();
    //           } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    //             webViewController?.loadUrl(
    //                 urlRequest:
    //                     URLRequest(url: await webViewController?.getUrl()));
    //           }
    //         },
    //       );
  }
  DateTime? _lastBackPressed; // Track last back press time
  
      Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home:  WillPopScope( // Intercept back button
        onWillPop: _onBackPressed, 
        child: Scaffold(
        // appBar: AppBar(title: const Text("")),
        body: SafeArea(
            child: InAppWebView(
                  key: webViewKey,
                  webViewEnvironment: webViewEnvironment,
                  initialUrlRequest: URLRequest(url: WebUri(widget.webUrl)),
                ),),
      ),
    ),
    );
  }
   Future<bool> _onBackPressed() async {
    DateTime now = DateTime.now();
    if (_lastBackPressed == null || 
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Press back again to exit"),
          duration: Duration(seconds: 2),
        ),
      );
      return Future.value(false); // Do not exit
    }
    return Future.value(true); // Exit app
  }

}
