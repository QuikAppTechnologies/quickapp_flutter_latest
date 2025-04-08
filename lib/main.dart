import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool hasInternet = true;

Future<FirebaseOptions> loadFirebaseOptionsFromJson() async {
  final jsonStr = await rootBundle.loadString('assets/google-services.json');
  final jsonMap = json.decode(jsonStr);

  final client = jsonMap['client'][0];
  final apiKey = client['api_key'][0]['current_key'];
  final projectId = jsonMap['project_info']['project_id'];
  final appId = client['client_info']['mobilesdk_app_id'];
  final senderId = jsonMap['project_info']['project_number'];
  final storageBucket = jsonMap['project_info']['storage_bucket'];

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    storageBucket: storageBucket,
  );
}
const pushNotify = bool.fromEnvironment('PUSH_NOTIFY', defaultValue: false);

WebViewEnvironment? webViewEnvironment;

void main() async {
  // const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  // const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  // const String firebaseProjectId =
  //     String.fromEnvironment('FIREBASE_PROJECT_ID');
  // const String firebaseMessagingSenderId =
  //     String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  // const String firebaseStorageBucket =
  //     String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  const String webUrl = String.fromEnvironment('WEB_URL');
  const pushNotify = bool.fromEnvironment('PUSH_NOTIFY', defaultValue: false);
// const pushNotify = String.fromEnvironment('PUSH_NOTIFY', defaultValue: 'false').toLowerCase() == 'true';
  WidgetsFlutterBinding.ensureInitialized();
    // Android settings for local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // your app icon

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  debugPrint("Push Notify: $pushNotify \n WEBURL: $webUrl \n");
  if (pushNotify == true) {
  await Firebase.initializeApp(
      options: await loadFirebaseOptionsFromJson(),
    );
  // try {
  //     await Firebase.initializeApp(
  //       options: const FirebaseOptions(
  //         apiKey: "AIzaSyBo-ihJ0vVkZJZeP2j5YPmXrdfxHSh9_C0",
  //         appId: "1:68101928519:android:091e10cf76e417abf9a362",
  //         messagingSenderId: "68101928519",
  //         projectId: "pixawaretest",
  //         storageBucket: "pixawaretest.firebasestorage.app",
  //       ),
  //     );
  //   } catch (e, s) {
  //     debugPrint("🔥 Firebase init failed: $e\n$s");
  //   }
// try {
  // await Firebase.initializeApp();
  // await Firebase.initializeApp(
  //       options: FirebaseOptions(
  //         apiKey: firebaseApiKey,
  //         appId: firebaseAppId,
  //         messagingSenderId: firebaseMessagingSenderId,
  //         projectId: firebaseProjectId,
  //         storageBucket: firebaseStorageBucket,
  //       ),
  //     );
    // } catch (e, s) {
      
    //   debugPrint("🔥 Firebase init failed: $e\n$s");
    // }
    
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    messaging.getToken().then((token) {
      debugPrint("✅ FCM Token: $token");
    });

    await messaging.setAutoInitEnabled(true);
    await messaging.requestPermission();


    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        Fluttertoast.showToast(
            msg: "🔔 Notification: ${message.notification?.title}");
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel', // channel ID
              'Default', // channel name
              channelDescription: 'Default notification channel',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      
    // });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await messaging.subscribeToTopic("all");
  } else {
    debugPrint(
        "🚫 Firebase not initialized (pushNotify: $pushNotify, isWeb: $kIsWeb)");
  }
  debugPrint(
      "Website URL: $webUrl");
 
  runApp(MyApp(webUrl: webUrl));
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🔔 Background message received: ${message.messageId}");
}

class MyApp extends StatefulWidget {
  final String webUrl;
  const MyApp({super.key, required this.webUrl});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  late PullToRefreshController? pullToRefreshController;

  String url = "";
  double progress = 0;
  final urlController = TextEditingController();
  DateTime? _lastBackPressed;

  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
  );

  @override
  void initState() {
    super.initState();

    if (pushNotify == true) {
      FirebaseMessaging.instance.getToken().then((token) {
        debugPrint('✅ FCM Token: $token');
      });

      FirebaseMessaging.instance.subscribeToTopic("all");
      FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Fluttertoast.showToast(
            msg: "🔔 Notification: ${message.notification?.title}");
            final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null && android != null) {
          Fluttertoast.showToast(
              msg: "🔔 Notification: ${message.notification?.title}");
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'default_channel', // channel ID
                'Default', // channel name
                channelDescription: 'Default notification channel',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });
    }

    Connectivity().onConnectivityChanged.listen((_) {
      _checkInternetConnection();
    });

    _checkInternetConnection();

    // Enable pull-to-refresh for mobile platforms
    pullToRefreshController = !kIsWeb &&
            [TargetPlatform.android, TargetPlatform.iOS]
                .contains(defaultTargetPlatform)
        ? PullToRefreshController(
            settings: PullToRefreshSettings(color: Colors.blue),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                  urlRequest:
                      URLRequest(url: await webViewController?.getUrl()),
                );
              }
            },
          )
        : null;
  }

  Future<void> _checkInternetConnection() async {
    final result = await Connectivity().checkConnectivity();
    final isOnline = result != ConnectivityResult.none;

    if (mounted) {
      setState(() {
        hasInternet = isOnline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WillPopScope(
        onWillPop: _onBackPressed,
        child: Scaffold(
          body: SafeArea(
            child: hasInternet
                ? InAppWebView(
                    key: webViewKey,
                    webViewEnvironment: webViewEnvironment,
                    initialUrlRequest: URLRequest(url: WebUri(widget.webUrl)),
                    // settings: settings,
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      var uri = navigationAction.request.url;

                      if (uri != null &&
                          !uri.toString().contains(widget.webUrl)) {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                  )
                : noInternetScreen(),
          ),
        ),
      ),
    );
  }

  Future<bool> _onBackPressed() async {
    DateTime now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(
        msg: "Press back again to exit",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
      );
      return Future.value(false);
    }
    return Future.value(true);
  }

  Widget noInternetScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No Internet Connection',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Please check your network settings and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

