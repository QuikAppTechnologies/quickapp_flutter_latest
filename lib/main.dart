import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


bool hasInternet = true;



    const String webUrl = String.fromEnvironment('WEB_URL');
const bool pushNotify =
    bool.fromEnvironment('PUSH_NOTIFY', defaultValue: false);

WebViewEnvironment? webViewEnvironment;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (pushNotify == true) {
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );

await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBo-ihJ0vVkZJZeP2j5YPmXrdfxHSh9_C0",
        appId: "1:68101928519:android:091e10cf76e417abf9a362",
        messagingSenderId: "68101928519",
        projectId: "pixawaretest",
        storageBucket: "pixawaretest.firebasestorage.app",
      ),
    );
    // await Firebase.initializeApp();
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    messaging.getToken().then((token) {
      debugPrint("✅ FCM Token: $token");
    });

    await messaging.setAutoInitEnabled(true);
    await messaging.requestPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Fluttertoast.showToast(
          msg: "🔔 Notification: ${message.notification?.title}");
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await messaging.subscribeToTopic("all");
  } else {
    debugPrint(
        "🚫 Firebase not initialized (pushNotify: $pushNotify, isWeb: $kIsWeb)");
  }
  debugPrint(
      "Website URL: $webUrl");
  // if (pushNotify) {
  //   await Firebase.initializeApp();
  //   FirebaseMessaging.instance.getToken().then((token) {
  //     print("FCM Token: $token");
  //   });
  //  if (firebaseEnabled && !kIsWeb) {
  //     // await FirebaseInitializer.initialize();
  //     await FirebaseMessaging.instance.setAutoInitEnabled(true);
  //     FirebaseMessaging.onBackgroundMessage(
  //         _firebaseMessagingBackgroundHandler);
  //   } else {
  //     debugPrint("🚫 Firebase not enabled via PUSH_NOTIFY.");
  //   }

  //   if (firebaseEnabled && !kIsWeb) {
  //     FirebaseMessaging.instance.getToken().then((token) {
  //       debugPrint('✅ FCM Token: $token');
  //     });

  //     FirebaseMessaging.instance.subscribeToTopic("all");
  //     FirebaseMessaging.instance.requestPermission();
  //     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //       Fluttertoast.showToast(
  //           msg: "🔔 Notification: ${message.notification?.title}");
  //     });
  //   }
  //   if (firebaseEnabled && !kIsWeb) {
  //     FirebaseMessaging.onBackgroundMessage(
  //         _firebaseMessagingBackgroundHandler);
  //   }

  // }
 
  // Initialize Firebase if push notification is enabled
  // if (firebaseEnabled && !kIsWeb) {
  //   await FirebaseInitializer.initialize();
  //   await FirebaseMessaging.instance.setAutoInitEnabled(true);
    
  //   // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // }

  // String webUrl = const String.fromEnvironment(
  //   'WEB_URL',
  //   defaultValue: 'https://pixaware.co/',
  // );

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

// import 'dart:async';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'firebase_initializer.dart';

// bool hasInternet = true;

// const bool firebaseEnabled =
//     bool.fromEnvironment('FIREBASE_ENABLED', defaultValue: false);

// WebViewEnvironment? webViewEnvironment;

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();


//   await FirebaseInitializer.initialize();
  
//   // await FirebaseInitializer.initialize();
// // if (firebaseEnabled && !kIsWeb) {
// //     try {
// //       // Import Firebase only if enabled
// //       // import 'package:firebase_core/firebase_core.dart';
// //       await Firebase.initializeApp();
// //       print('✅ Firebase initialized.');
// //     } catch (e) {
// //       print('⚠️ Firebase init failed: $e');
// //     }
// //   } else {
// //     print('ℹ️ Firebase is not enabled.');
// //   }


//   // await Firebase.initializeApp();
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

//   String webUrl = const String.fromEnvironment('WEB_URL',
//       defaultValue: 'https://pixaware.co/');

//   runApp(MyApp(webUrl: webUrl,));
// }







// // Handle background messages
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   debugPrint("Handling background message: ${message.messageId}");
// }
// class MyApp extends StatefulWidget {
//   final String webUrl;
//   const MyApp({super.key, required this.webUrl});

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   // This widget is the root of your application.
//   final GlobalKey webViewKey = GlobalKey();

//   InAppWebViewController? webViewController;
//   InAppWebViewSettings settings = InAppWebViewSettings(
//       isInspectable: kDebugMode,
//       mediaPlaybackRequiresUserGesture: false,
//       allowsInlineMediaPlayback: true,
//       iframeAllow: "camera; microphone",
//       iframeAllowFullscreen: true);

//   PullToRefreshController? pullToRefreshController;
//   String url = "";
//   double progress = 0;
//   final urlController = TextEditingController();
//   @override
//   void initState() {
//     super.initState();

//     FirebaseMessaging.instance.getToken().then((token) {
//       print('FCM Token: $token');
//     });

//     FirebaseMessaging.instance.subscribeToTopic("all");
//     FirebaseMessaging.instance.requestPermission();
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//     Fluttertoast.showToast(
//               msg: "Notification: ${message.notification?.title}");
//         });

//           // Internet monitoring
//        Connectivity()
//             .onConnectivityChanged
//             .listen((List<ConnectivityResult> results) {
//           _checkInternetConnection();
//         });

//         _checkInternetConnection(); // Initial check
//       }

//       Future<void> _checkInternetConnection() async {
//         final result = await Connectivity().checkConnectivity();
//         final isOnline = result != ConnectivityResult.none;

//         if (mounted) {
//           setState(() {
//             hasInternet = isOnline;
//           });
//         }

//     //
//     // pullToRefreshController = kIsWeb ||
//     //         ![TargetPlatform.iOS, TargetPlatform.android]
//     //             .contains(defaultTargetPlatform)
//     //     ? null
//     //     : PullToRefreshController(
//     //         settings: PullToRefreshSettings(
//     //           color: Colors.blue,
//     //         ),
//     //         onRefresh: () async {
//     //           if (defaultTargetPlatform == TargetPlatform.android) {
//     //             webViewController?.reload();
//     //           } else if (defaultTargetPlatform == TargetPlatform.iOS) {
//     //             webViewController?.loadUrl(
//     //                 urlRequest:
//     //                     URLRequest(url: await webViewController?.getUrl()));
//     //           }
//     //         },
//     //       );
//   }
//   DateTime? _lastBackPressed; // Track last back press time

//       Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home:  WillPopScope( // Intercept back button
//         onWillPop: _onBackPressed, 
//         child: Scaffold(
//         // appBar: AppBar(title: const Text("")),
//         body: SafeArea(
//             child:  hasInternet
//       ? InAppWebView(
//               key: webViewKey,
//               webViewEnvironment: webViewEnvironment,
//               initialUrlRequest: URLRequest(url: WebUri(widget.webUrl)),
//               shouldOverrideUrlLoading: (controller, navigationAction) async {
//                 var uri = navigationAction.request.url;

//                 if (uri != null && !uri.toString().contains(widget.webUrl)) {
//                   // Open external links in the default browser
//                   if (await canLaunchUrl(uri)) {
//                     await launchUrl(uri, mode: LaunchMode.externalApplication);
//                   }
//                   return NavigationActionPolicy
//                       .CANCEL; // Prevent WebView from loading the URL
//                 }

//                 return NavigationActionPolicy.ALLOW; // Allow internal links
//               },
//             )
//                 : noInternetScreen(),
//                 ),
//       ),
//     ),
//     );
//   }


// Future<bool> _onBackPressed() async {
//     DateTime now = DateTime.now();
//     if (_lastBackPressed == null || 
//         now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
//       _lastBackPressed = now;

//       // Show Toast Message
//       Fluttertoast.showToast(
//         msg: "Press back again to exit",
//         toastLength: Toast.LENGTH_SHORT,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.black54,
//         textColor: Colors.white,
//       );

//       return Future.value(false); // Do not exit
//     }
//     return Future.value(true); // Exit app
//   }
// Widget noInternetScreen() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.wifi_off, size: 100, color: Colors.grey),
//             const SizedBox(height: 20),
//             Text(
//               'No Internet Connection',
//               style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               'Please check your network settings and try again.',
//               textAlign: TextAlign.center,
//               style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

// }
