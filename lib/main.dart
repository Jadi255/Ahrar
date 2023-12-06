import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qalam/Pages/fetchers.dart';
import 'package:qalam/auth.dart';
import 'package:qalam/home.dart';
import 'styles.dart';
import 'user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FlutterSecureStorage storage = FlutterSecureStorage();
  final pb = PocketBase('https://ahrar.pockethost.io');
  final authService = AuthService(pb);
  Provider.debugCheckInvalidValueType = null;
  final user = User(
      id: '',
      fullName: '',
      bio: '',
      isVerified: false,
      avatar: null,
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
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = Provider.of<User>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'قلم',
      theme: appTheme,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        // Get the URI from the route name
        final uri = Uri.parse(settings.name!);
        // Check the path of the URI
        switch (uri.path) {
          case '/splash':
            return MaterialPageRoute(
                builder: (context) => SplashScreen(authService: authService));
          case '/login':
            return MaterialPageRoute(
                builder: (context) => Login(authService: authService));
          case '/home':
            return MaterialPageRoute(
                builder: (context) => Home(authService: authService));
          case '/signUp':
            return MaterialPageRoute(
                builder: (context) =>
                    Placeholder()); // Replace with your SignUp widget
          case '/friendRequests':
            return MaterialPageRoute(
                builder: (context) =>
                    Placeholder()); // Replace with your FriendRequests widget
          case '/showComments':
            final id = uri.queryParameters['id'];
            return MaterialPageRoute(
                builder: (context) => Placeholder(
                      child: Text('id'),
                    )); // Replace with your ShowComments widget
          case '/discoverTopics':
            final id = uri.queryParameters['id'];
            return MaterialPageRoute(
                builder: (context) => Placeholder(
                      child: Text('id'),
                    )); // Replace with your DiscoverTopics widget
          case '/viewProfile':
            final id = uri.queryParameters['id'];
            return MaterialPageRoute(
                builder: (context) => Placeholder(
                      child: Text('id'),
                    )); // Replace with your ViewProfile widget
          case '/showCommentsExtern':
            final id = uri.queryParameters['id'];
            return MaterialPageRoute(
                builder: (context) => Placeholder(
                      child: Text('id'),
                    )); // Replace with your ShowCommentsExtern widget
          case '/viewProfileExtern':
            final id = uri.queryParameters['id'];
            return MaterialPageRoute(
                builder: (context) => Placeholder(
                      child: Text('id'),
                    )); // Replace with your ViewProfileExtern widget
          default:
            return MaterialPageRoute(
                builder: (context) =>
                    UnknownPage()); // Replace with your UnknownPage widget
        }
      },
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
        Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  Login(authService: authService),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                var begin = Offset(1.0, 0.0);
                var end = Offset.zero;
                var curve = Curves.ease;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ));

        return;
      }
      final avatar = CachedNetworkImageProvider(avatarUrl);
      user.id = id;
      user.fullName = fullName;
      user.bio = bio!;
      user.isVerified = isVerified ?? false;
      user.avatar = avatar;
      user.realTime();
      Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                Home(authService: authService),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              var begin = Offset(1.0, 0.0);
              var end = Offset.zero;
              var curve = Curves.ease;

              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ));
    } else {
      Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                Login(authService: authService),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              var begin = Offset(1.0, 0.0);
              var end = Offset.zero;
              var curve = Curves.ease;

              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ));
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
