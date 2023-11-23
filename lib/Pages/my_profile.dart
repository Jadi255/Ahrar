import 'package:flutter/material.dart';
import '../user_data.dart';
import "styles.dart";
import "Settings.dart";

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  @override
  void initState() {
    super.initState();
    updateProfile();
  }

  void updateProfile() {
    ProfileSubscribe(userID, (userData) async {
      try {
        user = userData.toJson();
      } catch (e) {}
      fname = user['fname'];
      lname = user['lname'];
      userID = user['id'];
      var profilePicUrl = pb.getFileUrl(userData, user['avatar']).toString();
      profilePic = Image.network('$profilePicUrl?token=${pb.authStore.token}',
          width: 100);

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: InteractiveViewer(
                                    child: profilePic,
                                  ),
                                );
                              });
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(250),
                          child: profilePic,
                        ),
                      )
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (isVerified)
                      IconButton(
                        icon: Icon(Icons.check_circle),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('تم التحقق من هوية هذا الحساب'),
                          ));
                        },
                        color: greenColor,
                      ),
                    ListTile(
                      title: Center(
                        child: Text(
                          '$fname $lname',
                          style: defaultText,
                          textScaler: const TextScaler.linear(1.2),
                        ),
                      ),
                      subtitle: Center(
                        child: Text(user['about'],
                            textScaler: const TextScaler.linear(0.9),
                            style: defaultText),
                      ),
                    )
                  ],
                )
              ],
            ),
            const Divider(),
            const Settings()
          ],
        ),
      ),
    );
  }
}
