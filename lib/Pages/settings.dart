import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tahrir/Pages/profiles.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import '../user_data.dart';
import "styles.dart";
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

Image avatarImage = profilePic;

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: ListTile(
            trailing: const Icon(Icons.logout),
            title: const Text('تسجيل خروج'),
            onTap: () async {
              pb.authStore.clear();
              var prefs = await SharedPreferences.getInstance();

              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ),
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: ListTile(
            trailing: const Icon(Icons.edit),
            title: const Text('تعديل ملخص الصفحة الشخصية'),
            onTap: () {
              showModalBottomSheet(
                enableDrag: false,
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
            title: const Text('تعديل الصورة الشخصية'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AvatarSettings(callback: () {
                  setState(() {});
                }),
              );
            },
          ),
        ),
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: ListTile(
            trailing: const Icon(Icons.people),
            title: const Text('أصدقائي'),
            onTap: () {
              showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.grey.shade300,
                  elevation: 5,
                  enableDrag: true,
                  isDismissible: true,
                  builder: (context) {
                    return const FriendsList();
                  });
            },
          ),
        ),
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: ListTile(
            trailing: const Icon(Icons.people),
            title: const Text('طلبات الصداقة'),
            onTap: () {
              showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.grey.shade300,
                  elevation: 5,
                  enableDrag: true,
                  isDismissible: true,
                  builder: (context) {
                    return const FriendRequests();
                  });
            },
          ),
        ),
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: ListTile(
            trailing: const Icon(Icons.text_snippet_rounded),
            title: const Text('منشوراتي'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      ShowPosts(target: userID, name: '$fname $lname')));
            },
          ),
        ),
      ],
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
    setState(() {
      bioController.text = user['about'] ?? "";
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        centerTitle: true,
        title: Text(
          'تعديل ملخص الصفحة الشخصية',
          textScaler: const TextScaler.linear(0.75),
          style: defaultText,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
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
                      decoration: const InputDecoration(hintText: "الملخص"),
                      controller: bioController,
                    );
                  })),
                ),
                IconButton(
                  onPressed: () async {
                    await pb
                        .collection('users')
                        .update(userID, body: {'about': bioController.text});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم التحديث بنجاح')),
                    );

                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AvatarSettings extends StatefulWidget {
  final Function callback;
  const AvatarSettings({super.key, required this.callback});

  @override
  State<AvatarSettings> createState() => _AvatarSettingsState();
}

class _AvatarSettingsState extends State<AvatarSettings> {
  File? _avatarFile;

  void updateAvatarWeb(Uint8List newAvatar) async {
    var filename = 'avatar.jpg'; // Replace with your desired filename format
    http.MultipartFile multipartFile;

    multipartFile = http.MultipartFile.fromBytes(
      'avatar',
      newAvatar,
      filename: filename,
      contentType: MediaType(
          'image', 'jpeg'), // Replace with the appropriate content type
    );

    var record = await pb.collection('users').update(
      userID,
      files: [multipartFile],
    );
    var response = record.toJson();
    var avatarUrl =
        pb.getFileUrl(pb.authStore.model, user['avatar']).toString();
    profilePic = Image.network('$avatarUrl?token=${pb.authStore.token}');
    setState(() {}); // Add this line to trigger a UI refresh
  }

  void updateAvatarNonWeb(File newAvatar) async {
    var path = newAvatar.path;
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
      userID,
      files: [multipartFile],
    );
    var response = record.toJson();
    var avatarUrl =
        pb.getFileUrl(pb.authStore.model, user['avatar']).toString();
    profilePic = Image.network('$avatarUrl?token=${pb.authStore.token}');
    setState(() {}); // Add this line to trigger a UI refresh
  }

  Future<void> _pickAvatar() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      if (kIsWeb) {
        // On web, use bytes to create an image
        Uint8List? imageData = result.files.single.bytes;
        if (imageData != null) {
          updateAvatarWeb(imageData);
          avatarImage = Image.memory(imageData);
        }
      } else {
        // On other platforms, use the file path to create an image
        _avatarFile = File(result.files.single.path!);
        updateAvatarNonWeb(_avatarFile!);
        avatarImage = Image.file(_avatarFile!);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: avatarImage,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () async {
            if (!kIsWeb) {
              updateAvatarNonWeb(_avatarFile!);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم التحديث بنجاح')),
            );
            setState(() {});
            widget.callback();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.save),
        ),
      ],
    );
  }
}

class FriendsList extends StatefulWidget {
  const FriendsList({super.key});

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  List friends = user['friends'];
  List<Widget> page = [];
  late Image avatar;

  Future getFriends() async {
    List<Widget> page = [];
    for (var item in friends) {
      var target = await pb.collection('users').getOne(item);
      var friend = target.toJson();
      String name = '${friend['fname']} ${friend['lname']}';
      var avatarUrl = pb.getFileUrl(target, friend['avatar']).toString();

      page.add(Card(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ViewProfile(target: friend['id'])));
            },
            leading:
                ClipOval(child: Image.network(avatarUrl, fit: BoxFit.cover)),
            title: Text(name),
          ),
        ),
      ));
    }

    return page;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(
          'أصدقائي',
          style: defaultText,
        ),
        centerTitle: true,
      ),
      body: FutureBuilder(
          future: getFriends(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'An error occurred',
                  ),
                );

                // if we got our data
              } else if (snapshot.hasData) {
                // Extracting data from snapshot object
                final data = snapshot.data;
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(children: data),
                  ),
                );
              }
            }
            return shimmer;
          }),
    );
  }
}

class FriendRequests extends StatefulWidget {
  const FriendRequests({super.key});

  @override
  State<FriendRequests> createState() => _FriendRequestsState();
}

class _FriendRequestsState extends State<FriendRequests> {
  Future getRequests() async {
    List<Widget> pending = [];

    var requests = await pb.collection('friend_requests').getFullList();

    for (var request in requests) {
      var target = request.toJson();
      var getUser = await pb.collection('users').getOne(target['from']);
      var user = getUser.toJson();
      String name = '${user['fname']} ${user['lname']}';
      var avatarUrl = pb.getFileUrl(getUser, user['avatar']).toString();

      pending.add(Card(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ExpansionTile(
            title: ListTile(
              leading:
                  ClipOval(child: Image.network(avatarUrl, fit: BoxFit.cover)),
              title: Text(name),
            ),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) =>
                              ViewProfile(target: user['id'])));
                    },
                  ),
                  IconButton(
                    onPressed: () async {
                      var me = await pb
                          .collection('users')
                          .getOne(pb.authStore.model.id);
                      var him = await pb.collection('users').getOne(user['id']);

                      var myFriends = me.toJson()['friends'];
                      var hisFriends = him.toJson()['friends'];

                      hisFriends.add(userID);
                      myFriends.add(user['id']);

                      await pb
                          .collection('users')
                          .update(userID, body: {"friends": myFriends});
                      await pb
                          .collection('users')
                          .update(user['id'], body: {"friends": hisFriends});
                      await pb
                          .collection('friend_requests')
                          .delete(request.toJson()['id']);

                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم قبول طلب الصداقة')));

                      var prefs = await SharedPreferences.getInstance();
                      var username = await prefs.getString('email');
                      var password = await prefs.getString('password');
                      await authenticate(username, password);
                      setState(() {});
                    },
                    icon: Icon(Icons.check, color: greenColor),
                  ),
                  IconButton(
                    onPressed: () async {
                      await pb
                          .collection('friend_requests')
                          .delete(request.toJson()['id']);
                      setState(() {});
                    },
                    icon: Icon(Icons.close, color: redColor),
                  )
                ],
              )
            ],
          ),
        ),
      ));
    }

    return pending;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(
          'طلبات الصداقة',
          style: defaultText,
        ),
        centerTitle: true,
      ),
      body: FutureBuilder(
          future: getRequests(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'An error occurred',
                  ),
                );

                // if we got our data
              } else if (snapshot.hasData) {
                // Extracting data from snapshot object
                final data = snapshot.data;
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(children: data),
                  ),
                );
              }
            }
            return shimmer;
          }),
    );
  }
}
