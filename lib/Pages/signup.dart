import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../user_data.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'styles.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
  File? _avatarFile;
  Uint8List? _avatarBytes;
  late Image avatarImage;
  Widget leading = Icon(Icons.image);
  bool webcheck = false;

  int _selectedValue = 0;

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
        birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future updateAvatarWeb() async {
    if (_avatarBytes == null) {
      print('No file was selected');
      return;
    }

    var filename = 'avatar.jpg'; // Replace with your desired filename format
    http.MultipartFile multipartFile;

    multipartFile = http.MultipartFile.fromBytes(
      'avatar',
      _avatarBytes!,
      filename: filename,
      contentType: MediaType(
          'image', 'jpeg'), // Replace with the appropriate content type
    );
    try {
      await pb.collection('users').update(
        userID,
        files: [multipartFile],
      );
    } catch (e) {
      throw e;
    }
  }

  Future updateAvatarNonWeb() async {
    if (_avatarFile == null) {
      print('No file was selected');
      return;
    }

    var path = _avatarFile!.path;
    var filename = 'avatar.jpg'; // Replace with your desired filename format
    http.MultipartFile multipartFile;

    multipartFile = await http.MultipartFile.fromPath(
      'avatar',
      path,
      filename: filename,
      contentType: MediaType(
          'image', 'jpeg'), // Replace with the appropriate content type
    );

    var record = await pb.collection('users').update(
      pb.authStore.model.id,
      files: [multipartFile],
    );
  }

  Future signUp() async {
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

    if (body["email"] == "" ||
        body["password"] == "" ||
        body["passwordConfirm"] == "" ||
        body["fname"] == "" ||
        body["lname"] == "" ||
        body["sex"] == "" ||
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
          const SnackBar(content: Text('الرجاء إدخال بريد إلكتروني صالح')),
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

    if (kIsWeb) {
      if (_avatarBytes == null) {
        setState(() {
          btnText = const Text("متابعة");

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء اضافة صورة شخصية')),
          );
        });
        return;
      }
    } else {
      if (_avatarFile == null) {
        setState(() {
          btnText = const Text("متابعة");

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء اضافة صورة شخصية')),
          );
        });
        return;
      }
    }

    try {
      var request = await pb.collection('users').create(body: body);
      var authResponse = await pb
          .collection('users')
          .authWithPassword(body['email'], body['password']);

      var prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', emailController.text);
      await prefs.setString('id', pb.authStore.model.id);
      await prefs.setString('password', passwordController.text);
      userID = pb.authStore.model.id;

      if (kIsWeb) {
        if (_avatarBytes != null) {
          await updateAvatarWeb();
        }
      } else {
        if (_avatarFile != null) {
          await updateAvatarNonWeb();
        }
      }

      await authenticate(emailController.text, passwordController.text);
      context.go('/');
    } catch (e) {
      throw e;
    }
  }

  Future<void> _pickAvatar() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      Uint8List? imageData = await result.files.single.bytes;
      if (!kIsWeb) {
        _avatarFile = await File(result.files.single.path!);
      }

      if (imageData != null) {
        setState(() {
          avatarImage = Image.memory(imageData);
          leading = avatarImage;
        });
        if (kIsWeb) {
          _avatarBytes = imageData;
        }
      }
      if (_avatarFile != null) {
        if (!kIsWeb) {
          print(_avatarFile);
          setState(() {
            avatarImage = Image.file(_avatarFile!);
            leading = avatarImage;
          });

          setState(() {});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إنشاء حساب', style: defaultText),
        automaticallyImplyLeading: true,
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
                        color: Colors.grey.shade200,
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
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: ListTile(
                          title: Text('الصورة الشخصية'),
                          leading: leading,
                          onTap: () async {
                            await _pickAvatar();
                          }),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FilledButton(
                        onPressed: () async {
                          await signUp();
                        },
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
