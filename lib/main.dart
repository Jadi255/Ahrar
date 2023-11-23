import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أحرار',
      theme: appTheme,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const Login(),
        '/home': (context) => const Home(),
        '/signup': (context) => const SignUp(),
      },
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
