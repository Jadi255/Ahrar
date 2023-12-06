import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qalam/user_data.dart';
import '../styles.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User>(context);
    return pagePadding(Column(
      children: [
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: ListTile(
            trailing: const Icon(Icons.drive_file_rename_outline),
            title: Text(
              'تفيير الإسم',
              style: defaultText,
            ),
            onTap: () {
              showBottomSheet(
                backgroundColor: Colors.transparent,
                enableDrag: true,
                context: context,
                builder: (context) => UpdateName(),
              );
            },
          ),
        ),
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: ListTile(
            trailing: const Icon(Icons.password),
            title: Text('تفيير كلمة المرور', style: defaultText),
            onTap: () {
              showBottomSheet(
                backgroundColor: Colors.transparent,
                enableDrag: true,
                context: context,
                builder: (context) => const ChangePassword(),
              );
            },
          ),
        ),
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: ListTile(
            trailing: const Icon(Icons.edit),
            title: Text('تعديل ملخص الصفحة الشخصية', style: defaultText),
            onTap: () {
              showBottomSheet(
                backgroundColor: Colors.transparent,
                enableDrag: true,
                context: context,
                builder: (context) => const UpdateBio(),
              );
            },
          ),
        ),
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: ListTile(
            trailing: const Icon(Icons.image),
            title: Text('تعديل الصورة الشخصية', style: defaultText),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AvatarSettings(user: user),
              );
            },
          ),
        ),
      ],
    ));
  }
}

class UpdateName extends StatefulWidget {
  UpdateName({super.key});

  @override
  State<UpdateName> createState() => UpdateNameState();
}

class UpdateNameState extends State<UpdateName> {
  TextEditingController fnameController = TextEditingController();
  TextEditingController lnameController = TextEditingController();
  TextDirection textDirection = TextDirection.rtl;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User>(context);
    TextDirection textDirection = TextDirection.ltr;

    return SafeArea(
      bottom: true,
      maintainBottomViewPadding: true,
      child: floatingInput(
        SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: SizedBox(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: StatefulBuilder(builder: (context, setState) {
                      return TextField(
                        textDirection: textDirection,
                        decoration: textfieldDecoration("الإسم الأول"),
                        onChanged: (value) {
                          if (fnameController.text == '') {
                            return;
                          } else {
                            setState(() {
                              textDirection =
                                  isArabic(fnameController.text.split('')[0])
                                      ? TextDirection.rtl
                                      : TextDirection.ltr;
                            });
                          }
                        },
                        controller: fnameController,
                      );
                    }),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: SizedBox(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: StatefulBuilder(builder: ((context, setState) {
                      return TextField(
                        textDirection: textDirection,
                        onChanged: (value) {
                          if (lnameController.text == '') {
                            return;
                          } else {
                            setState(() {
                              textDirection =
                                  isArabic(lnameController.text.split('')[0])
                                      ? TextDirection.rtl
                                      : TextDirection.ltr;
                            });
                          }
                        },
                        decoration: textfieldDecoration("إسم العائلة"),
                        controller: lnameController,
                      );
                    })),
                  ),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  String fname = fnameController.text.trim();
                  String lname = lnameController.text.trim();
                  if (fname == '' || lname == '') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('الرجاء إدخال جميع البيانات للمتابعة'),
                      ),
                    );
                    return;
                  }
                  bool updated = await user.updateName(fname, lname);
                  if (updated) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم الحفظ'),
                      ),
                    );
                  } else {
                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ ما، الرجاء المحاولة لاحقاً'),
                      ),
                    );
                  }
                },
                child: Text('حفظ'),
                style: FilledButtonStyle,
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  TextEditingController oldPassword = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController confirmPassword = TextEditingController();
  TextDirection textDirection = TextDirection.rtl;
  bool oldPasswordHidden = true;
  bool isPasswordHidden = true;
  bool isConfirmHidden = true;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User>(context);
    return floatingInput(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: SizedBox(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  textDirection: TextDirection.ltr,
                  obscureText: oldPasswordHidden,
                  decoration: InputDecoration(
                    labelText: "كلمة السر الحالية",
                    labelStyle: TextStyle(
                      color: Colors.black, // Set your desired color
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(30), // Circular/Oval border
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefix: IconButton(
                      onPressed: () {
                        setState(() {
                          oldPasswordHidden = !oldPasswordHidden;
                        });
                      },
                      icon: Icon(Icons.visibility),
                    ),
                  ),
                  controller: oldPassword,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: SizedBox(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  textDirection: TextDirection.ltr,
                  obscureText: isPasswordHidden,
                  decoration: InputDecoration(
                    labelText: "كلمة السر الجديدة",
                    labelStyle: TextStyle(
                      color: Colors.black, // Set your desired color
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(30), // Circular/Oval border
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffix: IconButton(
                      onPressed: () {
                        setState(() {
                          oldPasswordHidden = !oldPasswordHidden;
                        });
                      },
                      icon: Icon(Icons.visibility),
                    ),
                  ),
                  controller: password,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: SizedBox(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  textDirection: TextDirection.ltr,
                  obscureText: isConfirmHidden,
                  decoration: InputDecoration(
                    labelText: "تأكيد كلمة السر الجديدة",
                    labelStyle: TextStyle(
                      color: Colors.black, // Set your desired color
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(30), // Circular/Oval border
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffix: IconButton(
                      onPressed: () {
                        setState(() {
                          oldPasswordHidden = !oldPasswordHidden;
                        });
                      },
                      icon: Icon(Icons.visibility),
                    ),
                  ),
                  controller: confirmPassword,
                ),
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              String oldPasswordText = oldPassword.text;
              String passwordText = password.text;
              String confirmPasswordText = confirmPassword.text;
              if (passwordText != confirmPasswordText) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('الرجاء إدخال جميع البيانات للمتابعة'),
                  ),
                );
                return;
              }
              bool updated = await user.updatePassword(
                  oldPasswordText, passwordText, confirmPasswordText);
              if (updated) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم الحفظ'),
                  ),
                );
              } else {
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ ما، الرجاء المحاولة لاحقاً'),
                  ),
                );
              }
            },
            child: Text('حفظ'),
            style: FilledButtonStyle,
          )
        ],
      ),
    );
  }
}

class UpdateBio extends StatefulWidget {
  const UpdateBio({super.key});

  @override
  State<UpdateBio> createState() => _UpdateBioState();
}

class _UpdateBioState extends State<UpdateBio> {
  TextEditingController bioController = TextEditingController();
  TextDirection textDirection = TextDirection.ltr;

  @override
  void initState() {
    setState(() {});

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User>(context);
    return floatingInput(
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
              child: Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(builder: ((context, setState) {
              return TextField(
                textDirection: textDirection,
                onChanged: (value) {
                  if (bioController.text == '') {
                    return;
                  } else {
                    setState(() {
                      textDirection = isArabic(bioController.text.split('')[0])
                          ? TextDirection.rtl
                          : TextDirection.ltr;
                    });
                  }
                },
                decoration: textfieldDecoration("الملخص"),
                controller: bioController,
              );
            })),
          )),
          IconButton(
            onPressed: () async {
              bool updated = await user.updateBio(bioController.text);
              if (updated) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم الحفظ'),
                  ),
                );
              } else {
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ ما، الرجاء المحاولة لاحقاً'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.save),
          )
        ],
      ),
    );
  }
}

class AvatarSettings extends StatefulWidget {
  final User user;
  AvatarSettings({super.key, required this.user});

  @override
  State<AvatarSettings> createState() => _AvatarSettingsState();
}

class _AvatarSettingsState extends State<AvatarSettings> {
  File? _avatarFile;

  Future<void> _pickAvatar() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      if (kIsWeb) {
        // On web, use bytes to create an image
        Uint8List? imageData = result.files.single.bytes;
        if (imageData != null) {
          widget.user.updateAvatarWeb(imageData);
        }
      } else {
        // On other platforms, use the file path to create an image
        _avatarFile = File(result.files.single.path!);
        widget.user.updateAvatarNonWeb(_avatarFile!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User>(context);
    return Consumer<User>(builder: (context, user, child) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Center(
          child: Text(
            'تعديل الصورة الشخصية',
            style: defaultText,
            textScaler: const TextScaler.linear(0.75),
          ),
        ),
        content: GestureDetector(
          onTap: _pickAvatar,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image(image: user.avatar!),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              if (!kIsWeb) {
                user.updateAvatarNonWeb(_avatarFile!);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم التحديث بنجاح')),
              );
              Navigator.pop(context);
              setState(() {});
            },
            icon: const Icon(Icons.save),
          ),
        ],
      );
    });
  }
}

class MyFriends extends StatefulWidget {
  final User user;
  const MyFriends({super.key, required this.user});

  @override
  State<MyFriends> createState() => _MyFriendsState();
}

class _MyFriendsState extends State<MyFriends> {
  Stream<List<Widget>> getFriends() async* {
    List friends = await widget.user.getFriends();
    if (friends.isEmpty) {
      yield [
        Center(
          child: Text(
            'لا يوجد أصدقاء',
            style: defaultText,
          ),
        )
      ];
      return;
    }
    List<Widget> friendWidgets = [];
    for (var item in friends) {
      var target = await widget.user.pb.collection('users').getOne(item);
      var friend = target.toJson();
      String name = '${friend['fname']} ${friend['lname']}';
      var avatarUrl =
          widget.user.pb.getFileUrl(target, friend['avatar']).toString();

      // Use CachedNetworkImageProvider for image caching
      ImageProvider avatarImage = CachedNetworkImageProvider(avatarUrl);

      friendWidgets.add(
        Card(
          surfaceTintColor: Colors.white,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: ListTile(
              onTap: () {
                //return ViewProfile(target: item);
              },
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade100,
                backgroundImage: avatarImage,
              ),
              title: Text(name),
            ),
          ),
        ),
      );
      yield friendWidgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: StreamBuilder<List<Widget>>(
        stream: getFriends(),
        builder: (BuildContext context, AsyncSnapshot<List<Widget>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return shimmer; // or your custom loader
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return Column(
              children: [
                pagePadding(
                  Column(
                    children: snapshot.data!,
                  ),
                ),
                Visibility(
                  child: Center(child: CupertinoActivityIndicator()),
                  visible: (snapshot.connectionState != ConnectionState.done),
                )
              ],
            );
          }
        },
      ),
    );
  }
}
