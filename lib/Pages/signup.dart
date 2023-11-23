import 'package:flutter/material.dart';
import '../user_data.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'styles.dart';

late String name;
late String id;

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final TextEditingController fnameController = TextEditingController();
  final TextEditingController lnameController = TextEditingController();
  TextEditingController birthdayController = TextEditingController();
  TextDirection textDirection = TextDirection.ltr;

  int _selectedValue = 0;

  Widget btnText = const Text("متابعة");

  Future<void> sign() async {
    setState(() {
      btnText = const CupertinoActivityIndicator(
        color: Colors.white,
      );
    });

    String sex = "female";
    if (_selectedValue != 1) {
      sex = "male";
    }

    final body = <String, dynamic>{
      "email": emailController.text,
      "emailVisibility": true,
      "password": passwordController.text,
      "passwordConfirm": passwordController.text,
      "fname": fnameController.text,
      "lname": lnameController.text,
      "sex": sex,
      "birthday": birthdayController.text,
    };

    body.forEach((key, value) {
      if (value == "") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال جميع البيانات')),
        );
        return;
      }
    });

    if (passwordController.text != confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء التأكد من كلمة المرور')),
      );
      return;
    }

    var request = await signUp(body);

    switch (request) {
      case 1:
        setState(() {
          btnText = const Icon(Icons.check);
        });
        var auth =
            await authenticate(emailController.text, passwordController.text);
        if (auth == 1) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      case 2:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('حدث خطأ ما، الرجاء المحاولة في وقت لاحق')),
        );
        return;
    }
  }

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
        birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إنشاء حساب', style: defaultText),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Stripes,
            Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    logo,
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: SizedBox(
                        child: TextField(
                          decoration: const InputDecoration(
                              hintText: "البريد الإلكتروني"),
                          keyboardType: TextInputType.emailAddress,
                          controller: emailController,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: SizedBox(
                        child: StatefulBuilder(builder: ((context, setState) {
                          return TextField(
                            onChanged: (value) {
                              setState(() {
                                textDirection =
                                    RegExp(r'[\u0600-\u06FF]').hasMatch(value)
                                        ? TextDirection.rtl
                                        : TextDirection.ltr;
                              });
                            },
                            decoration:
                                const InputDecoration(hintText: "الإسم الأول"),
                            controller: fnameController,
                          );
                        })),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: SizedBox(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              textDirection =
                                  RegExp(r'[\u0600-\u06FF]').hasMatch(value)
                                      ? TextDirection.rtl
                                      : TextDirection.ltr;
                            });
                          },
                          decoration:
                              const InputDecoration(hintText: "إسم العائلة"),
                          controller: lnameController,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Card(
                        borderOnForeground: true,
                        color: Colors.grey.shade300,
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              CupertinoSlidingSegmentedControl<int>(
                                children: const {
                                  0: Text('ذكر'),
                                  1: Text('أنثى'),
                                },
                                onValueChanged: (int? value) {
                                  setState(() {
                                    _selectedValue = value!;
                                  });
                                },
                                groupValue: _selectedValue,
                              ),
                              const Text(":الجنس"),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: SizedBox(
                        child: TextField(
                          decoration:
                              const InputDecoration(hintText: "كلمة المرور"),
                          controller: passwordController,
                          obscureText: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: SizedBox(
                        child: TextField(
                          decoration: const InputDecoration(
                              hintText: "تأكيد كلمة المرور"),
                          controller: confirmController,
                          obscureText: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: SizedBox(
                        child: TextField(
                          readOnly: true,
                          controller: birthdayController,
                          decoration: const InputDecoration(
                            hintText: 'تاريخ الميلاد',
                          ),
                          onTap: () => _selectDate(context),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FilledButton(
                        onPressed: sign,
                        style: ButtonStyle(
                            backgroundColor:
                                MaterialStatePropertyAll(blackColor)),
                        child: btnText,
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
