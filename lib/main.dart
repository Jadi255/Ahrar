import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/external_posts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:qalam/Pages/fetchers.dart';
import 'package:qalam/auth.dart';
import 'package:qalam/home.dart';
import 'package:qalam/Pages/cache.dart';
import 'package:go_router/go_router.dart';

import 'styles.dart';
import 'user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await FirebaseMessaging.instance.requestPermission(provisional: true);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
  } catch (e) {
    print(e);
  }
  final pb = await PocketBase('https://ahrar.pockethost.io');
  final authService = AuthService(pb);
  await Hive.initFlutter();
  Hive.registerAdapter(MessageAdapter());
  Provider.debugCheckInvalidValueType = null;
  final user = User(
      id: '',
      fullName: '',
      bio: '',
      isVerified: false,
      avatar: null,
      emailNotify: false,
      pb: authService.pb); // make sure 'user' is your global User instance
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider<User>.value(value: user),
      ],
      child: MyApp(),
    ),
  );
}
/**
We've added Provider<AuthService>.value to provide an instance of AuthService to the widget tree.
In MyApp, we've used Provider.of<AuthService>(context) to get the AuthService instance, and used it to set the initialLocation of _router.
These changes encapsulate the authentication logic in AuthService, represent a user with the User class, and use Provider to make AuthService available throughout the app. This makes the code more modular, easier to manage, and easier to test.
 */

class MyApp extends StatelessWidget {
  var begin = Offset(1.0, 0.0);
  var end = Offset.zero;
  var curve = Curves.ease;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final _router = GoRouter(routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: SplashScreen(authService: authService),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) {
          return MaterialPage<void>(
            key: state.pageKey,
            child: Login(authService: authService),
          );
        },
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) {
          return MaterialPage<void>(
            key: state.pageKey,
            child:
                PopScope(canPop: false, child: Home(authService: authService)),
          );
        },
      ),
      GoRoute(
        path: '/showPost/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'];
          return MaterialPage<void>(
            key: state.pageKey,
            child: ExternalLink(id: id!),
          );
        },
      ),
    ], initialLocation: "/");
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'تطبيق قلم',
      theme: appTheme,
      routerConfig: _router,
    );
  }
}

class SplashScreen extends StatefulWidget {
  final AuthService authService;

  SplashScreen({required this.authService});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    checkAuthentication();
  }

  void checkAuthentication() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = Provider.of<User>(context, listen: false);
    final isAuthenticated = await authService.isAuthenticated();
    Fetcher fetcher = Fetcher(pb: authService.pb);
    fetcher.fetchTopics();
    if (isAuthenticated) {
      final prefs = await SharedPreferences.getInstance();
      String? id = await prefs.getString('user_id');
      String? fullName = await prefs.getString('user_fullName');
      String? bio = await prefs.getString('user_bio');
      bool? isVerified = await prefs.getBool('isVerified');
      var avatarUrl = prefs.getString('user_avatarUrl');
      if (id == null || fullName == null || avatarUrl == null) {
        context.go('/login');
        return;
      }
      final avatar = CachedNetworkImageProvider(avatarUrl);
      user.id = id;
      user.fullName = fullName;
      user.bio = bio!;
      user.isVerified = isVerified ?? false;
      user.avatar = avatar;
      user.realTime();
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<User>(context);

    return Scaffold(
      body: Center(child: shimmer),
    );
  }
}

class UnknownPage extends StatelessWidget {
  const UnknownPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
