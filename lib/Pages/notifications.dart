import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/chats.dart';
import 'package:qalam/Pages/fetchers.dart';
import 'package:qalam/Pages/renderers.dart';
import 'package:qalam/Pages/users_profiles.dart';
import 'package:qalam/Pages/writers.dart';
import 'package:qalam/styles.dart';
import 'package:qalam/user_data.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int count = 0;
  Color iconColor = blackColor;
  var notificationData;
  @override
  void initState() {
    super.initState();
    notificationListener();
    Future.delayed(Duration.zero, () async {
      await getNotifications();
    });
  }

  void notificationListener() {
    final user = Provider.of<User>(context, listen: false);
    final fetcher = Fetcher(pb: user.pb);
    if (!kIsWeb) {
      fetcher.notificationSubscriber(context).listen((notification) async {
        await getNotifications();
      });
    } else if (kIsWeb) {
      Timer.periodic(
        Duration(seconds: 15),
        (timer) async {
          try {
            await getNotifications();
          } catch (e) {
            print(e);
          }
        },
      );
    }
  }

  Future getNotifications() async {
    final user = Provider.of<User>(context, listen: false);
    final _fetcher = Fetcher(pb: user.pb);
    notificationData = await _fetcher.getNotificationCount(user.id);
    var newNotifications = [];
    for (var item in notificationData) {
      var notification = item.toJson();
      var seen = notification['seen'];
      if (!seen) {
        newNotifications.add(notification);
      }
    }
    if (newNotifications.length > 0) {
      setState(() {
        count = newNotifications.length;
        iconColor = redColor;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: ButtonStyle(
        foregroundColor: MaterialStatePropertyAll(iconColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.notifications),
          Text('$count'),
        ],
      ),
      onPressed: () {
        showModalBottomSheet(
            context: context,
            enableDrag: false,
            builder: (context) {
              final user = Provider.of<User>(context, listen: false);
              return ChangeNotifierProvider(
                create: (context) =>
                    Renderer(fetcher: Fetcher(pb: user.pb), pb: user.pb),
                child: NotificationsMenu(data: notificationData),
              );
            });

        setState(() {
          iconColor = blackColor;
          count = 0;
        });
      },
    );
  }
}

class NotificationsMenu extends StatefulWidget {
  final data;
  NotificationsMenu({super.key, required this.data});

  @override
  State<NotificationsMenu> createState() => _NotificationsMenuState();
}

class _NotificationsMenuState extends State<NotificationsMenu> {
  var items;
  @override
  void initState() {
    super.initState();
    items = widget.data;
  }

  String formatDate(DateTime date) {
    date = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);
    var hour = date.hour;
    var minutes = date.minute;
    if (aDate == today) {
      return '${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } else {
      return '${aDate.day}/${aDate.month}\n${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    }
  }

  Stream<List<Widget>> getNewNotifications(items) async* {
    final user = Provider.of<User>(context, listen: false);
    Fetcher fetcher = Fetcher(pb: user.pb);
    List<Widget> widgets = [];
    if (items.length == 0) {
      widgets.add(
        Center(
          child: Text('لا يوجد اشعارات', style: defaultText),
        ),
      );
      yield widgets;
      return;
    }

    for (var item in items) {
      var notification = item.toJson();
      var color = notification['seen'] ? Colors.white : Colors.green[50];
      var type = notification['type'];
      var msgTime = formatDate(DateTime.parse(notification['created']));

      switch (type) {
        case 'request':
          try {
            var sender = notification['expand']['linked_user'];
            if (sender == null) {
              user.pb.collection('notifications').delete(notification['id']);
              break;
            }
            var record = RecordModel.fromJson(sender);
            final avatarUrl =
                user.pb.getFileUrl(record, sender['avatar']).toString();

            Widget notificationCard = Card(
              color: color,
              surfaceTintColor: color,
              elevation: 0.5,
              child: pagePadding(
                ListTile(
                  onTap: () async {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return Directionality(
                          textDirection: TextDirection.rtl,
                          child: AlertDialog(
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.white,
                              content: Text(
                                  'أرسل لك المستخدم ${sender['full_name']} طلب صداقة',
                                  style: defaultText),
                              actions: [
                                TextButton(
                                  style: ButtonStyle(
                                      foregroundColor:
                                          MaterialStatePropertyAll(blackColor)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation,
                                                secondaryAnimation) =>
                                            UserProfile(
                                                id: sender['id'],
                                                fullName: sender['full_name']),
                                        transitionsBuilder: (context, animation,
                                            secondaryAnimation, child) {
                                          var begin = Offset(1.0, 0.0);
                                          var end = Offset.zero;
                                          var curve = Curves.ease;

                                          var tween = Tween(
                                                  begin: begin, end: end)
                                              .chain(CurveTween(curve: curve));

                                          return SlideTransition(
                                            position: animation.drive(tween),
                                            child: child,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  child: Text('عرض الصفحة الشخصية'),
                                ),
                                TextButton(
                                  style: ButtonStyle(
                                      foregroundColor:
                                          MaterialStatePropertyAll(greenColor)),
                                  onPressed: () async {
                                    fetcher.acceptRequest(
                                        user.id,
                                        notification['linked_id'],
                                        notification['id']);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تم قبول طلب الصداقة'),
                                      ),
                                    );
                                  },
                                  child: Text('قبول'),
                                ),
                                TextButton(
                                  style: ButtonStyle(
                                      foregroundColor:
                                          MaterialStatePropertyAll(redColor)),
                                  onPressed: () async {
                                    fetcher.ignoreRequest(notification['id']);
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('تجاهل'),
                                ),
                              ]),
                        );
                      },
                    );
                    Writer writer = Writer(pb: user.pb);
                    writer.markNotificationRead(notification['id']);
                  },
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey.shade100,
                    foregroundImage: CachedNetworkImageProvider(avatarUrl),
                    backgroundImage:
                        Image.asset('assets/placeholder.jpg').image,
                  ),
                  title: Text(
                    'طلب صداقة',
                    style: defaultText,
                    textDirection: TextDirection.rtl,
                  ),
                  subtitle: Text(
                      'أرسل لك المستخدم ${sender['full_name']} طلب صداقة',
                      textDirection: TextDirection.rtl),
                  trailing: Text(
                    msgTime,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.linear(0.75),
                  ),
                ),
              ),
            );

            widgets.add(notificationCard);
          } catch (e) {
            user.pb.collection('notifications').delete(notification['id']);
          }
          break;
        case 'alert':
          try {
            var sender = notification['expand']['linked_user'];
            if (sender == null) {
              user.pb.collection('notifications').delete(notification['id']);
              break;
            }

            var record = RecordModel.fromJson(sender);
            final avatarUrl =
                user.pb.getFileUrl(record, sender['avatar']).toString();

            Widget notificationCard = Card(
              color: color,
              surfaceTintColor: color,
              elevation: 0.5,
              child: pagePadding(
                ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            UserProfile(
                                id: sender['id'],
                                fullName: sender['full_name']),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
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
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey.shade100,
                    foregroundImage: CachedNetworkImageProvider(avatarUrl),
                    backgroundImage:
                        Image.asset('assets/placeholder.jpg').image,
                  ),
                  title: Text(
                    'قبل المستخدم ${sender['full_name']} طلب صداقتك',
                    style: defaultText,
                    textDirection: TextDirection.rtl,
                  ),
                  trailing: Text(
                    msgTime,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.linear(0.75),
                  ),
                ),
              ),
            );

            widgets.add(notificationCard);
            fetcher.markAsRead(notification['id']);
          } catch (e) {
            user.pb.collection('notifications').delete(notification['id']);
          }
          break;
        case 'comment':
          var post =
              notification['expand']['linked_comment']['expand']['post']['id'];
          if (post == null) {
            user.pb.collection('notifications').delete(notification['id']);
            break;
          }
          try {
            var sender =
                notification['expand']['linked_comment']['expand']['by'];
            if (sender == null) {
              user.pb.collection('notifications').delete(notification['id']);
              break;
            }

            var record = RecordModel.fromJson(sender);
            final avatarUrl =
                user.pb.getFileUrl(record, sender['avatar']).toString();

            Widget notificationCard = Card(
              color: color,
              surfaceTintColor: color,
              elevation: 0.5,
              child: pagePadding(
                ListTile(
                  onTap: () async {
                    Writer writer = Writer(pb: user.pb);
                    writer.markNotificationRead(notification['id']);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ChangeNotifierProvider(
                          create: (context) => Renderer(
                              fetcher: Fetcher(pb: user.pb), pb: user.pb),
                          child: ShowFullPost(post: post),
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
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
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey.shade100,
                    foregroundImage: CachedNetworkImageProvider(avatarUrl),
                    backgroundImage:
                        Image.asset('assets/placeholder.jpg').image,
                  ),
                  title: Text('تعليق جديد',
                      style: defaultText, textDirection: TextDirection.rtl),
                  subtitle: Text(
                      'علق المستخدم ${sender['full_name']} على منشور تتابعه',
                      textDirection: TextDirection.rtl),
                  trailing: Text(
                    msgTime,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.linear(0.75),
                  ),
                ),
              ),
            );

            widgets.add(notificationCard);
            fetcher.markAsRead(notification['id']);
          } catch (e) {
            user.pb.collection('notifications').delete(notification['id']);
          }
          break;
        case 'message':
          try {
            var sender = notification['expand']['linked_user'];
            if (sender == null) {
              user.pb.collection('notifications').delete(notification['id']);
              break;
            }

            var record = RecordModel.fromJson(sender);
            final avatarUrl =
                user.pb.getFileUrl(record, sender['avatar']).toString();
            widgets.add(
              Card(
                color: color,
                surfaceTintColor: color,
                elevation: 0.5,
                child: pagePadding(
                  ListTile(
                    onTap: () async {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ConversationView(
                                      name: sender['full_name'],
                                      id: sender['id'],
                                      avatar: avatarUrl),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
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
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade100,
                      foregroundImage: CachedNetworkImageProvider(avatarUrl),
                      backgroundImage:
                          Image.asset('assets/placeholder.jpg').image,
                    ),
                    title: Text('لديك رسالة جديدة من ${sender['full_name']}',
                        style: defaultText, textDirection: TextDirection.rtl),
                    trailing: Text(
                      msgTime,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.linear(0.75),
                    ),
                  ),
                ),
              ),
            );
            fetcher.markAsRead(notification['id']);
          } catch (e) {
            print(e);
          }
          break;
      }
      yield widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
        icon: Icon(Icons.arrow_downward),
        onPressed: () {
          Navigator.of(context).pop();
        },
      )),
      body: SingleChildScrollView(
        child: StreamBuilder<List<Widget>>(
          stream: getNewNotifications(items),
          builder:
              (BuildContext context, AsyncSnapshot<List<Widget>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: shimmer); // or your custom loader
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
      ),
    );
  }
}
