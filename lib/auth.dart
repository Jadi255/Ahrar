import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pocketbase/pocketbase.dart';
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
                            await authService.authenticate(
                                email, password, context);
                            btnText = Icon(Icons.check);
                            context.go('/home');
                            emailController.clear();
                            passwordController.clear();
                          } catch (e) {
                            print(e);
                            if (e ==
                                'FirebaseError: Messaging: The notification permission was not granted and blocked instead. (messaging/permission-blocked).') {
                              print('Firebase error');
                            } else {
                              setState(() {
                                btnText = const Text("تسجيل دخول");
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'حدث خطأ ما، الرجاء المحاولة لاحقاً')),
                              );
                            }
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
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (context) {
                            return SignUp(
                              pb: widget.authService.pb,
                            );
                          }));
                        },
                        style: TextButtonStyle,
                        child: (const Text("إنشاء حساب")),
                      ),
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

class SignUp extends StatefulWidget {
  final PocketBase pb;

  const SignUp({super.key, required this.pb});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final TextEditingController fnameController = TextEditingController();
  final TextEditingController lnameController = TextEditingController();
  TextEditingController birthdayController = TextEditingController();
  TextDirection textDirection = TextDirection.ltr;
  bool sexSelect = true;
  bool passwordHidden = true;
  bool confirmHidden = true;

  Widget btnText = const Text("متابعة");

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900, 1),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData(
            colorScheme: ColorScheme.light(primary: blackColor),
            dialogBackgroundColor: Colors.black,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        birthdayController.text = intl.DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future signUp() async {
    showDialog(
        context: context,
        builder: (context) {
          return CupertinoActivityIndicator(color: Colors.white);
        });

    late String sex;
    if (sexSelect) {
      sex = "male";
    } else {
      sex = 'female';
    }

    var avatar = await rootBundle.load('assets/placeholder.jpg');
    var avatarBytes = avatar.buffer.asUint8List();
    var filename = 'avatar.jpg'; // Replace with your desired filename format

    http.MultipartFile multipartFile = http.MultipartFile.fromBytes(
      'avatar',
      avatarBytes,
      filename: filename,
      contentType: MediaType(
          'image', 'jpeg'), // Replace with the appropriate content type
    );

    var fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      if (kIsWeb) {
        fcmToken = await FirebaseMessaging.instance.getToken(
            vapidKey:
                "BBT1WN2eSXbRVYatPTKRbUGfoGE4RTpSoMwNqzkhaGMtQXjiKGyvTkRmmsLy54GWwlsVqun6H04eMrQArVSoSnI");
      }
    } catch (e) {
      fcmToken = 'null';
    }

    final body = <String, dynamic>{
      "email": emailController.text,
      "emailVisibility": true,
      "password": passwordController.text,
      "passwordConfirm": passwordController.text,
      "fname": fnameController.text,
      "lname": lnameController.text,
      "full_name": "${fnameController.text} ${lnameController.text}",
      "sex": sex,
      "birthday": birthdayController.text,
      "fcm_token": fcmToken
    };

    if (body["email"] == "" ||
        body["password"] == "" ||
        body["passwordConfirm"] == "" ||
        body["fname"] == "" ||
        body["lname"] == "" ||
        body["birthday"] == "") {
      setState(() {
        btnText = const Text("متابعة");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال جميع البيانات')),
        );
      });
      return;
    }

    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$")
        .hasMatch(body["email"])) {
      setState(() {
        btnText = const Text("متابعة");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال بريد إلكتروني حقيقي')),
        );
      });
    }
    if (passwordController.text != confirmController.text) {
      setState(() {
        btnText = const Text("متابعة");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء التأكد من كلمة المرور')),
        );
      });
      return;
    }

    setState(() {
      btnText = const Text("متابعة");
    });

    try {
      var request = await widget.pb.collection('users').create(
        body: body,
        files: [multipartFile],
      );
      var response = request.toJson();
      var id = response['id'];
      AuthService authService = AuthService(widget.pb);
      await authService.authenticate(
          emailController.text, passwordController.text, context);
      btnText = Icon(Icons.check);
      context.go('/home');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900, 1),
        lastDate: DateTime.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData(
              colorScheme: ColorScheme.light(primary: blackColor),
              dialogBackgroundColor: Colors.black,
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          birthdayController.text =
              intl.DateFormat('yyyy-MM-dd').format(picked);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            coloredLogo,
            Text(
              'إنشاء حساب',
              style: defaultText,
              textScaler: TextScaler.linear(0.85),
            ),
          ],
        ),
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: pagePadding(
          Column(
            children: [
              Container(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SvgPicture.asset(
                        'assets/logo2.svg',
                        width: 200,
                      ),
                      Center(
                        child:
                            Text('مرحبا بك في عائلة قلم', style: defaultText),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: SizedBox(
                  child: TextField(
                    decoration: textfieldDecoration(
                        "البريد الإلكتروني"), // use textfieldDecoration
                    keyboardType: TextInputType.emailAddress,
                    controller: emailController,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: SizedBox(
                  child: TextField(
                    decoration: textfieldDecoration(
                        "الإسم الأول"), // use textfieldDecoration
                    controller: fnameController,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: SizedBox(
                  child: TextField(
                    decoration: textfieldDecoration(
                        "اسم العائلة"), // use textfieldDecoration
                    controller: lnameController,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: SizedBox(
                  child: TextField(
                    decoration: InputDecoration(
                      label: Text('كلمة السر'),
                      labelStyle: TextStyle(
                        color: Colors.black, // Set your desired color
                      ),
                      suffix: Transform.scale(
                        scale: 0.85,
                        child: IconButton(
                            onPressed: () {
                              passwordHidden = !passwordHidden;
                              setState(() {});
                            },
                            icon: Icon(Icons.visibility)),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(30), // Circular/Oval border
                      ),
                    ), // use textfieldDecoration
                    obscureText: passwordHidden,
                    controller: passwordController,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: SizedBox(
                  child: TextField(
                    decoration: InputDecoration(
                      suffix: Transform.scale(
                        scale: 0.85,
                        child: IconButton(
                            onPressed: () {
                              setState(() {
                                confirmHidden = !confirmHidden;
                              });
                            },
                            icon: Icon(Icons.visibility)),
                      ),
                      label: Text('تأكيد كلمة السر'),
                      labelStyle: TextStyle(
                        color: Colors.black, // Set your desired color
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(30), // Circular/Oval border
                      ),
                    ), // use textfieldDecoration
                    obscureText: confirmHidden,
                    controller: confirmController,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: ElevatedButton(
                  style: ButtonStyle(
                    elevation: MaterialStatePropertyAll(0.5),
                    shape: MaterialStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(color: Colors.grey.shade600),
                      ),
                    ),
                    overlayColor:
                        MaterialStatePropertyAll(Colors.grey.shade200),
                    surfaceTintColor:
                        MaterialStatePropertyAll(Colors.grey.shade200),
                    backgroundColor:
                        MaterialStatePropertyAll(Colors.grey.shade200),
                    foregroundColor: MaterialStatePropertyAll(blackColor),
                  ),
                  onPressed: () {
                    setState(() {
                      sexSelect = !sexSelect;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(13.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        sexSelect ? Text('ذكر') : Text('أنثى'),
                        sexSelect
                            ? Icon(Icons.male, color: greenColor)
                            : Icon(Icons.female, color: redColor)
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: SizedBox(
                  child: TextField(
                    readOnly: true,
                    controller: birthdayController,
                    decoration: textfieldDecoration(
                      'تاريخ الميلاد',
                    ),
                    onTap: () => _selectDate(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: FilledButton(
                  onPressed: () async {
                    await signUp();
                  },
                  style: ButtonStyle(
                      backgroundColor: MaterialStatePropertyAll(blackColor)),
                  child: btnText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
