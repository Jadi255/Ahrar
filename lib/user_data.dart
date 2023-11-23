import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pb = PocketBase('https://ahrar.pockethost.io');

var userData;
var user;

late String fname;
late String lname;
late String about;
late String userID;
late Image profilePic;
bool isVerified = false;
ValueNotifier<Image> profilePicNotifier = ValueNotifier<Image>(profilePic);

Future authenticate(email, password) async {
  final prefs = await SharedPreferences.getInstance();

  late final RecordAuth authData;
  try {
    authData = await pb.collection('users').authWithPassword(email, password);

    userData = pb.authStore.model;
    user = userData.toJson();
    fname = user['fname'];
    lname = user['lname'];
    userID = user['id'];
    isVerified = user['verified'];

    var avatarUrl = pb.getFileUrl(userData, user['avatar']).toString();
    profilePic = Image.network('$avatarUrl?token=${pb.authStore.token}');
  } catch (e) {
    return 2;
  }
  var token = authData.token;
  prefs.setString('token', token);
  if (token.isNotEmpty) {
    prefs.setString('email', email);
    prefs.setString('id', pb.authStore.model.id);
    prefs.setString('password', password);
    return 1;
  }
}

Future signUp(Map<String, dynamic> body) async {
  try {
    await pb.collection('users').create(body: body);
    return 1;
  } catch (e) {
    return 2;
  }
}

Future<bool> checkUser() async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString("email");
  final password = prefs.getString("password");

  try {
    await authenticate(email, password);
  } catch (e) {
    return false;
  }
  return true;
}

Future ProfileSubscribe(id, Function callback) async {
  userData;
  pb.collection('users').subscribe(id, (e) {
    userData = e.record;
    callback(userData); // Call the callback function when data changes
  });

  user = userData.toJson();
  fname = user['fname'];
  lname = user['lname'];
  id = user['id'];

  var avatarUrl = pb.getFileUrl(userData, user['avatar']).toString();
  profilePic = Image.network('$avatarUrl?token=${pb.authStore.token}');
}

Future getCirclePosts(
    {int limit = 10, int page = 1, isPublic, selectedTopicId}) async {
  String filter = '';
  if (isPublic != null) {
    filter += 'is_public = $isPublic';
  }
  if (selectedTopicId != null && selectedTopicId.isNotEmpty) {
    if (filter.isNotEmpty) {
      filter += ' && ';
    }
    filter += 'topic.id = \'$selectedTopicId\'';
  }
  final resultList = await pb.collection('circle_posts').getList(
        page: page,
        perPage: limit,
        filter: filter,
        sort: '-created',
      );

  return resultList.toJson();
}

Future circleSubscribe(Function callback) async {
  await pb.collection('circle_posts').subscribe('*', (e) {
    if (e.action == 'create') {
      callback(e.record);
    }
  });
}

bool isArabic(String text) {
  final arabicRegex = RegExp(r'[\u0600-\u06FF]');
  return arabicRegex.hasMatch(text);
}

Future getFriends({int limit = 5, int page = 1, target}) async {
  final record = await pb.collection('users').getOne(
        target,
      );

  return record;
}

Future subscribeComments(Function callback) async {
  pb.collection('circle_comments').subscribe('*', (e) {
    if (e.action != 'delete') {
      callback(e.record);
    }
  });
}

Future subscribeRequests(Function callback) async {
  pb.collection('friend_requests').subscribe('*', (e) {
    if (e.action != 'delete') {
      callback(e.record);
    }
  });
}
