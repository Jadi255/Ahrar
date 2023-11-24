import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:tahrir/Pages/circle.dart';
import 'package:tahrir/Pages/profiles.dart';
import 'Pages/styles.dart';
import 'Pages/auth.dart';
import 'home.dart';
import 'Pages/signup.dart' hide id;
import 'user_data.dart';

String initialRoute = "/home";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  var email = prefs.getString('email');
  var password = prefs.getString('password');
  var req = await authenticate(email, password);
  if (req != 1) {
    initialRoute = '/login';
  }
  runApp(
    const Directionality(
      textDirection: TextDirection.rtl,
      child: MyApp(),
    ),
  );
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: const Login(),
      ),
    ),
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: const Home(),
      ),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: const SignUp(),
      ),
    ),
    GoRoute(
      path: '/showComments/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'];
        return MaterialPage<void>(
          key: state.pageKey,
          child: ShowComments(post: id!),
        );
      },
    ),
    GoRoute(
      path: '/viewProfile/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'];
        return MaterialPage<void>(
          key: state.pageKey,
          child: ViewProfile(target: id!),
        );
      },
    ),
    GoRoute(
      path: '/showCommentsExtern/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'];
        return MaterialPage<void>(
          key: state.pageKey,
          child: ShowCommentsExtern(post: id!),
        );
      },
    ),
    GoRoute(
      path: '/viewProfileExtern/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'];
        return MaterialPage<void>(
          key: state.pageKey,
          child: ViewProfileExtern(target: id!),
        );
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'أحرار',
      theme: appTheme,
      routerConfig: _router,
    );
  }
}

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text('أحرار', style: defaultText),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stripes,
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: logo,
            ),
            const Divider(),
            const Padding(padding: EdgeInsets.all(15), child: Auth()),
            TahrirSlogan,
          ],
        ),
      ),
    );
  }
}

class NoConnection extends StatelessWidget {
  const NoConnection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('أحرار', style: defaultText),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off),
              Divider(
                color: Colors.transparent,
              ),
              Text('أنت غير متصل بالإنترنت'),
              Divider(
                color: Colors.transparent,
              ),
              Text('سنحاول إعادة الإتصال'),
              Divider(
                color: Colors.transparent,
              ),
              CupertinoActivityIndicator()
            ],
          ),
        ));
  }
}
