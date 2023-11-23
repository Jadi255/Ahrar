// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:shared_preferences/shared_preferences.dart';
import '../user_data.dart';

import 'styles.dart';

class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  Widget btnText = const Text("تسجيل دخول");

  @override
  void initState() {
    Future.delayed(Duration.zero, () async {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString("email");
      final password = prefs.getString("password");

      setState(() {
        emailController.text = email ?? "";
        passwordController.text = password ?? "";
      });
    });
    super.initState();
  }

  Future<void> signIn() async {
    if (emailController.text == "" || passwordController.text == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تأكد من إدخال جميع المعلومات')),
      );
      return;
    }

    setState(() {
      btnText = const CupertinoActivityIndicator(
        color: Colors.white,
      );
    });

    var auth =
        await authenticate(emailController.text, passwordController.text);

    switch (auth) {
      case 1:
        pb.authStore.save(pb.authStore.token, pb.authStore.model);
        Navigator.pushReplacementNamed(context, '/home');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الدخول بنجاح')),
        );
        setState(() {
          btnText = const Icon(Icons.check);
        });

      case 2:
        setState(() {
          btnText = const Text("تسجيل دخول");
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'تأكد من كلمة السر والبريد الإلكتروني ثم حاول مرة أخرى')),
        );
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: SizedBox(
            child: StatefulBuilder(builder: (context, setState) {
              return TextField(
                decoration:
                    const InputDecoration(hintText: "البريد الإلكتروني"),
                keyboardType: TextInputType.emailAddress,
                controller: emailController,
              );
            }),
          ),
        ),
        SizedBox(
          child: TextField(
            decoration: const InputDecoration(hintText: "كلمة المرور"),
            controller: passwordController,
            obscureText: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: FilledButton(
              onPressed: signIn,
              style: ButtonStyle(
                  backgroundColor: MaterialStatePropertyAll(blackColor)),
              child: btnText),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
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
    );
  }
}
