import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahrir/Pages/circle.dart';
import 'package:tahrir/Pages/settings.dart';
import 'package:tahrir/Pages/styles.dart';
import 'package:tahrir/user_data.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  int notificationCount = 0;
  List<Widget> notifications = [];
  Widget notificationsList = shimmer;
  @override
  void initState() {
    super.initState();
    loadNotifications();
    checkForMissedNotifications();
    subscriber();
  }

  Future<void> checkForMissedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastFetchedItemId = prefs.getString('lastFetchedItemId');
    var page = 1;
    bool hasMissedNotifications = true;

    while (hasMissedNotifications) {
      var latestCommentRecords = await pb
          .collection('circle_comments')
          .getList(page: page, perPage: 1, sort: '-created');

      var latestRequestRecords = await pb
          .collection('friend_requests')
          .getList(page: page, perPage: 1, sort: '-created');

      page++;
      if (latestCommentRecords.items.isNotEmpty &&
          latestCommentRecords.items[0].toJson()['id'] != lastFetchedItemId) {
        // Update the lastFetchedItemId in SharedPreferences
        await prefs.setString(
            'lastFetchedItemId', latestCommentRecords.items[0].toJson()['id']);
        sendNotification(latestCommentRecords.items[0].toJson(), 'comment');
      } else if (latestRequestRecords.items.isNotEmpty &&
          latestRequestRecords.items[0].toJson()['id'] != lastFetchedItemId) {
        // Update the lastFetchedItemId in SharedPreferences
        await prefs.setString(
            'lastFetchedItemId', latestRequestRecords.items[0].toJson()['id']);
        sendNotification(latestRequestRecords.items[0].toJson(), 'request');
      } else {
        hasMissedNotifications = false;
      }
      break;
    }
  }

  Future subscriber() async {
    String? newestCommentId;
    String? newestRequestId;

    try {
      if (kIsWeb) {
        Timer.periodic(const Duration(seconds: 60), (timer) async {
          var latestCommentRecords = await pb
              .collection('circle_comments')
              .getList(page: 1, perPage: 1, sort: '-created');
          var latestRequestRecords = await pb
              .collection('friend_requests')
              .getList(page: 1, perPage: 1, sort: '-created');

          if (latestCommentRecords.items.isNotEmpty &&
              latestCommentRecords.items[0].toJson()['id'] != newestCommentId) {
            newestCommentId = latestCommentRecords.items[0].toJson()['id'];
            sendNotification(latestCommentRecords.items[0].toJson(), 'comment');
          }
          if (latestRequestRecords.items.isNotEmpty &&
              latestRequestRecords.items[0].toJson()['id'] != newestRequestId) {
            newestRequestId = latestRequestRecords.items[0].toJson()['id'];
            sendNotification(latestRequestRecords.items[0].toJson(), 'request');
          }
        });
      } else {
        subscribeComments((event) {
          sendNotification(event.toJson(), 'comment');
        });
        subscribeRequests((event) {
          sendNotification(event.toJson(), 'request');
        });
      }
    } catch (e) {
      print('Notification has been deleted');
    }
  }

  Future loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedNotifications =
        prefs.getStringList('notifications') ?? [];

    try {
      for (String savedNotification in savedNotifications.reversed) {
        Map<String, dynamic> notificationData = jsonDecode(
            savedNotification); // Convert the JSON string back to a map
        Widget? notificationWidget = await createNotificationWidget(
            notificationData['item'],
            notificationData['type'],
            false); // Recreate the notification widget

        if (notificationWidget != null) {
          setState(() {
            notifications.add(notificationWidget);
          });
        }
      }
    } catch (e) {
      print('e');
    }
  }

  Future<Widget?> createNotificationWidget(
      Map<String, dynamic> item, String type, bool isNew) async {
    Widget? notificationWidget;

    Color cardColor = isNew ? greenColor : Colors.white;

    switch (type) {
      case 'comment':
        var comment = item;
        if (comment['by'] == userID) {
          return null;
        }
        var parentRecord =
            await pb.collection('circle_posts').getOne(comment['post']);
        var parent = parentRecord.toJson();

        var commentorRecord =
            await pb.collection('users').getOne(comment['by']);
        var postTime = DateFormat('dd/MM/yyyy · HH:mm')
            .format(DateTime.parse(comment['created']).toLocal());

        var commentorName =
            '${commentorRecord.toJson()['fname']} ${commentorRecord.toJson()['lname']}';
        notificationWidget = Card(
          color: Colors.white,
          surfaceTintColor: cardColor,
          child: ListTile(
            onTap: () {
              if (isNew) {
                setState(() {
                  isNew = false;
                });
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return ShowComments(post: parent['id']);
                  },
                ),
              );
            },
            subtitle: ListTile(
              title: Text(
                'تعليق جديد',
                style: defaultText,
              ),
              subtitle: Text(
                'علق $commentorName على المنشور ${parent['post']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            title: Text(
              postTime,
              textScaler: const TextScaler.linear(0.75),
            ),
          ),
        );
        break;
      case 'post':
        var post = item;

        if (post['by'] == userID) {
          return null;
        }

        var commentorRecord = await pb.collection('users').getOne(post['by']);
        var postTime = DateFormat('dd/MM/yyyy · HH:mm')
            .format(DateTime.parse(post['created']).toLocal());

        var commentorName =
            '${commentorRecord.toJson()['fname']} ${commentorRecord.toJson()['lname']}';

        notificationWidget = GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) {
                  return ShowComments(post: post['id']);
                },
              ),
            );
          },
          child: Card(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            child: ListTile(
              subtitle: ListTile(
                title: Text(
                  'منشور جديد',
                  style: defaultText,
                ),
                subtitle: Text(
                  'منشور جديد من $commentorName',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              title: Text(
                postTime,
                textScaler: const TextScaler.linear(0.75),
              ),
            ),
          ),
        );
        break;

      case 'request':
        var request = item;

        var postTime = DateFormat('dd/MM/yyyy · HH:mm')
            .format(DateTime.parse(request['created']).toLocal());

        notificationWidget = Card(
            color: Colors.white,
            surfaceTintColor: cardColor,
            child: ListTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return FriendRequests();
                    },
                  ),
                );
              },
              title: Text(postTime, textScaler: const TextScaler.linear(0.75)),
              subtitle: Text(
                'لديك طلب صداقة جديد',
                overflow: TextOverflow.ellipsis,
                style: defaultText,
              ),
            ));
        break;
    }

    return notificationWidget;
  }

  void sendNotification(Map<String, dynamic> item, String type) async {
    if (item['by'] == userID) {
      // If the event is by the logged in user, return without showing the notification
      return;
    }

    Widget? notificationWidget =
        await createNotificationWidget(item, type, true);

    if (notificationWidget != null) {
      notifications.insert(0,
          notificationWidget); // Insert the notification at the beginning of the list

      // Save notification data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      List<String> savedNotifications =
          prefs.getStringList('notifications') ?? [];
      Map<String, dynamic> notificationData = {'item': item, 'type': type};
      savedNotifications.add(jsonEncode(
          notificationData)); // Convert the notification data to a JSON string before storing
      await prefs.setStringList('notifications', savedNotifications);

      // Save the ID of the last fetched item
      await prefs.setString('lastFetchedItemId', item['id']);
    }

    setState(() {
      notificationCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget notificationBar = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('الإشعارات', style: defaultText),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: Column(children: notifications),
              )),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: TextButton(
        onPressed: () {
          showModalBottomSheet(
              context: context,
              builder: (context) {
                return notificationBar;
              }).then((value) {
            setState(() {
              notificationCount = 0;
            });
          });
        },
        child: Row(
          children: [
            Icon(Icons.notifications,
                color: notificationCount > 0 ? redColor : blackColor),
            Text('$notificationCount',
                style: TextStyle(
                    color: notificationCount > 0 ? redColor : blackColor))
          ],
        ),
      ),
    );
  }
}
