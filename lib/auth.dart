import 'package:crypton/crypton.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'user_data.dart';
import 'styles.dart';

class Login extends StatefulWidget {
  final AuthService authService;
  Login({super.key, required this.authService});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  late final AuthService authService;
  var initConnectivityState;

  @override
  void initState() {
    authService = widget.authService;
    super.initState();
    getInitConnectivity();

    setValues();
  }

  Future<void> getInitConnectivity() async {
    initConnectivityState = await Connectivity().checkConnectivity();
  }

  Stream<ConnectivityResult> connectivityStream() async* {
    final Connectivity connectivity = Connectivity();
    await for (ConnectivityResult result
        in connectivity.onConnectivityChanged) {
      if (result != initConnectivityState) {
        initConnectivityState = result;
        yield result;
      }
    }
  }

  Widget btnText = const Text("تسجيل دخول");

  Future<void> setValues() async {
    final FlutterSecureStorage storage = FlutterSecureStorage();

    emailController.text = await storage.read(key: 'email') ?? "";
    passwordController.text = await storage.read(key: 'password') ?? "";
  }

  @override
  Widget build(BuildContext context) {
    connectivityStream().listen((event) {
      if (event == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text('أنت غير متصل بالإنترنت'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.wifi,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text('عاد الإتصال'),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  SvgPicture.asset(
                    'assets/logo2.svg',
                    width: 200,
                  ),
                  coloredLogo,
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: EdgeInsets.all(15),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: SizedBox(
                      child: StatefulBuilder(builder: (context, setState) {
                        return SafeArea(
                          bottom: true,
                          child: TextField(
                            decoration:
                                textfieldDecoration('البريد الإلكتروني'),
                            keyboardType: TextInputType.emailAddress,
                            controller: emailController,
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(
                    child: SafeArea(
                      bottom: true,
                      child: TextField(
                        decoration: textfieldDecoration("كلمة المرور"),
                        controller: passwordController,
                        obscureText: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FilledButton(
                        onPressed: () async {
                          setState(() {
                            btnText = CupertinoActivityIndicator(
                              color: Colors.white,
                            );
                          });
                          final email = emailController.text;
                          final password = passwordController.text;
                          try {
                            final user = await authService.authenticate(
                                email, password, context);
                            btnText = Icon(Icons.check);
                            Navigator.of(context).pushReplacementNamed('/home');
                            emailController.clear();
                            passwordController.clear();
                          } catch (e) {
                            setState(() {
                              btnText = const Text("تسجيل دخول");
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'حدث خطأ ما، الرجاء المحاولة لاحقاً')),
                            );
                          }
                        },
                        style: ButtonStyle(
                            backgroundColor:
                                MaterialStatePropertyAll(blackColor)),
                        child: btnText),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/signUp');
                        },
                        style: TextButtonStyle,
                        child: (const Text("إنشاء حساب")),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButtonStyle,
                        child: (const Text("نسيت كلمة المرور")),
                      )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
