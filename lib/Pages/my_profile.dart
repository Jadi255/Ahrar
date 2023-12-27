import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/fetchers.dart';

import 'package:qalam/Pages/profile_settings.dart';
import 'package:qalam/Pages/renderers.dart';
import 'package:qalam/Pages/view_user_posts.dart';
import '../user_data.dart';
import '../styles.dart';

class MyProfile extends StatefulWidget {
  final bool isLeading;
  MyProfile({super.key, required this.isLeading});

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    Provider.of<User>(context);
    return Consumer<User>(
      builder: (context, user, child) {
        return ChangeNotifierProvider(
          create: (context) =>
              Renderer(fetcher: Fetcher(pb: user.pb), pb: user.pb),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: widget.isLeading,
              actions: [
                IconButton(
                  icon: Icon(Icons.logout_outlined),
                  onPressed: () async {
                    await authService.logout(context, user.id);
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),
                Visibility(
                  visible: !widget.isLeading,
                  child: IconButton(
                    onPressed: () {
                      showBottomSheet(
                        enableDrag: false,
                        context: context,
                        builder: (context) {
                          return Scaffold(
                            resizeToAvoidBottomInset: false,
                            appBar: AppBar(
                                title: titleText('إعدادات'),
                                centerTitle: true,
                                leading: IconButton(
                                  icon: Icon(Icons.arrow_downward),
                                  onPressed: () => Navigator.of(context).pop(),
                                )),
                            body: Settings(),
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.settings),
                  ),
                ),
              ],
            ),
            body: pagePadding(
              SingleChildScrollView(
                child: Column(
                  children: [
                    themedCard(
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          children: [
                            GestureDetector(
                              child: circularImage(user.avatar),
                              onTap: () {
                                showImage(context, user.avatar);
                              },
                            ),
                            if (user.isVerified)
                              IconButton(
                                icon: Icon(Icons.check_circle_rounded),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('تم التحقق من هوية هذا الحساب'),
                                    ),
                                  );
                                },
                                color: greenColor,
                              ),
                            ListTile(
                              title: Text(
                                user.fullName,
                                textScaler: TextScaler.linear(1.15),
                                style: defaultText,
                                textAlign: TextAlign.center,
                              ),
                              subtitle: Text(
                                user.bio,
                                textScaler: TextScaler.linear(0.85),
                                style: defaultText,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                        color: Colors.white,
                        surfaceTintColor: Colors.white,
                        elevation: 0.5,
                        child: ListTile(
                          trailing: const Icon(Icons.people),
                          title: Text('أصدقائي', style: defaultText),
                          onTap: () {
                            showModalBottomSheet(
                                enableDrag: false,
                                context: context,
                                builder: (context) {
                                  return Scaffold(
                                    appBar: AppBar(
                                      leading: IconButton(
                                        icon: Icon(Icons.arrow_downward),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ),
                                    body: MyFriends(
                                      user: user,
                                      chatMode: false,
                                    ),
                                  );
                                });
                          },
                        )),
                    Card(
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      elevation: 0.5,
                      child: ListTile(
                        trailing: const Icon(Icons.text_snippet_rounded),
                        title: Text('منشوراتي', style: defaultText),
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      ChangeNotifierProvider(
                                create: (context) => Renderer(
                                    fetcher: Fetcher(pb: user.pb), pb: user.pb),
                                child: ViewUserPosts(user: user),
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                var begin = Offset(1.0, 0.0);
                                var end = Offset.zero;
                                var curve = Curves.ease;

                                var tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));

                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
