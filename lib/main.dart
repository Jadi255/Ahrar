import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'Pages/friends.dart' hide ShowComments;
import 'Pages/circle.dart';
import 'Pages/profiles.dart';
import 'Pages/settings.dart';
import 'Pages/topics.dart';
import 'Pages/styles.dart';
import 'Pages/auth.dart';
import 'home.dart';
import 'Pages/signup.dart' hide id;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MyApp(),
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
      path: '/',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: const FriendsCircle(),
      ),
    ),
    GoRoute(
      path: '/signUp',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: const SignUp(),
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
      path: '/friendRequests',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: const FriendRequests(),
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
      path: '/discoverTopics/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'];
        return MaterialPage<void>(
          key: state.pageKey,
          child: DiscoverTopics(topic: id!),
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
