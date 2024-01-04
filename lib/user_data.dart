import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/**
AuthService: This class encapsulates the authentication logic. It has the following methods:
authenticate(String email, String password): Authenticates the user with the provided email and password. If the authentication is successful, it stores the authentication token in secure storage and returns a User instance.
isAuthenticated(): Checks if the user is authenticated by checking if an authentication token exists in secure storage. Returns true if the token exists and false otherwise.
checkUser(): Checks if the user's email and password exist in secure storage. If they do, it attempts to authenticate the user with these credentials. Returns true if the authentication is successful and false otherwise.
logout(): Logs out the user by deleting the authentication token from secure storage.
 */

class AuthService {
  final PocketBase pb;
  final FlutterSecureStorage storage = FlutterSecureStorage();
  AuthService(this.pb);

  Future<User> authenticate(
      String email, String password, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await storage.deleteAll();
    var fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      if (kIsWeb) {
        fcmToken = await FirebaseMessaging.instance.getToken(
            vapidKey:
                "BBT1WN2eSXbRVYatPTKRbUGfoGE4RTpSoMwNqzkhaGMtQXjiKGyvTkRmmsLy54GWwlsVqun6H04eMrQArVSoSnI");
      }
    } catch (e) {
      fcmToken = 'null';
    }

    try {
      final authData =
          await pb.collection('users').authWithPassword(email, password);
      final token = pb.authStore.token;
      await storage.write(key: 'token', value: token);
      await storage.write(key: 'email', value: email);
      await storage.write(key: 'password', value: password);
      final authRecord = authData.toJson();
      final authMap = authRecord['record'];
      final userRecordModel =
          await pb.collection('users').getOne(authMap['id']);
      // Get the avatar URL
      final avatarUrl =
          pb.getFileUrl(userRecordModel, authMap['avatar']).toString();
      final avatar = CachedNetworkImageProvider(avatarUrl);
      if (authMap['fcm_token'] == "" || authMap['fcm_token'] != fcmToken) {
        var request = await pb.collection('users').update(
          authMap['id'],
          body: {"fcm_token": fcmToken},
        );
      }
      // Create a User instance
      User user = User(
          id: authMap['id'],
          fullName: authMap['full_name'],
          bio: authMap['about'],
          isVerified: authMap['is_verified'],
          avatar: avatar,
          pb: pb);

      await prefs.setString('user_id', user.id);
      await prefs.setString('user_fullName', user.fullName);
      await prefs.setString('user_bio', user.bio);
      await prefs.setString('user_avatarUrl', avatarUrl);
      await prefs.setBool('isVerified', user.isVerified);

      // Update the User object in the Provider
      Provider.of<User>(context, listen: false).updateUser(user);

      user.realTime();
      return user;
    } catch (e) {
      throw Exception('Failed to authenticate');
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await storage.read(key: 'token');
    return token != null;
  }

  Future<void> logout(context, id) async {
    await pb.collection('users').update(
      id,
      body: {"fcm_token": ""},
    );

    pb.authStore.clear();
    final prefs = await SharedPreferences.getInstance();
    final cache = CacheManager();
    await cache.clearMessages();
    await prefs.clear();
  }

  Future<void> authRefresh() async {
    final email = await storage.read(key: 'email');
    final password = await storage.read(key: "password");

    var fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      if (kIsWeb) {
        fcmToken = await FirebaseMessaging.instance.getToken(
            vapidKey:
                "BBT1WN2eSXbRVYatPTKRbUGfoGE4RTpSoMwNqzkhaGMtQXjiKGyvTkRmmsLy54GWwlsVqun6H04eMrQArVSoSnI");
      }
    } catch (e) {
      fcmToken = 'null';
    }

    final record =
        await pb.collection('users').authWithPassword(email!, password!);
    var userData = await record.record!.toJson();
    var lastToken = userData['fcm_token'];

    if (lastToken == "" || lastToken != fcmToken) {
      var request = await pb.collection('users').update(
        userData['id'],
        body: {"fcm_token": fcmToken},
      );
    }
  }
}

/**
User: This class represents a user. It has the following properties:
id: The user's ID.
firstName: The user's first name.
lastName: The user's last name.
bio: The user's bio.
avatar: An ImageProvider for the user's avatar.
pb: The PocketBase instance.
fullName: A getter that returns the user's full name by concatenating firstName and lastName.
subscribeToChanges(): A method that subscribes to updates to the user's record. When an update occurs, it updates firstName, lastName, and bio with the new data, and updates avatar with a new CachedNetworkImageProvider created from the updated avatar URL.

 */

class User extends ChangeNotifier {
  String id;
  String fullName;
  String bio;
  bool isVerified;
  ImageProvider? avatar;
  final PocketBase pb;

  User(
      {required this.id,
      required this.fullName,
      required this.bio,
      required this.isVerified,
      this.avatar,
      required this.pb});

  void updateUser(User newUser) {
    this.id = newUser.id;
    this.fullName = newUser.fullName;
    this.bio = newUser.bio;
    this.isVerified = newUser.isVerified;
    this.avatar = newUser.avatar;
    notifyListeners();
  }

  Future updateName(String fname, String lname) async {
    final data = {
      "full_name": "$fname $lname",
      "fname": "$fname",
      "lname": "$lname",
    };

    try {
      await pb.collection('users').update(this.id, body: data);
      // Update the user instance
      this.fullName = "$fname $lname";
      // Notify listeners to update the UI
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future updateBio(
    String bio,
  ) async {
    final data = {
      "about": bio,
    };

    try {
      await pb.collection('users').update(this.id, body: data);
      // Update the user instance
      this.bio = bio;
      // Notify listeners to update the UI
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updatePassword(oldPassword, password, confirmPassword) async {
    final data = {
      "password": password,
      "passwordConfirm": confirmPassword,
      "oldPassword": oldPassword,
    };

    try {
      await pb.collection('users').update(this.id, body: data);
      // Notify listeners to update the UI
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

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

    var userRecord = await pb.collection('users').getOne(this.id);
    var record = await pb.collection('users').update(
      this.id,
      files: [multipartFile],
    );
    var response = record.toJson();
    var avatarUrl = pb.getFileUrl(userRecord, response['avatar']).toString();
    this.avatar = CachedNetworkImageProvider(avatarUrl);
    notifyListeners();
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

    var userRecord = await pb.collection('users').getOne(this.id);
    var record = await pb.collection('users').update(
      this.id,
      files: [multipartFile],
    );
    var response = record.toJson();

    var avatarUrl = pb.getFileUrl(userRecord, response['avatar']).toString();
    this.avatar = CachedNetworkImageProvider(avatarUrl);
    notifyListeners();
  }

  void realTime() {
    pb.collection('users').subscribe(this.id, (e) async {
      final record = e.record;
      final authMap = record!.toJson();
      final avatarUrl = pb.getFileUrl(record, authMap['avatar']).toString();
      this.avatar = CachedNetworkImageProvider(avatarUrl);
      this.id = authMap['id'];
      this.fullName = authMap['full_name'];
      this.bio = authMap['about'];
      this.isVerified = authMap['is_verified'];
      this.avatar = avatar;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', this.id);
      await prefs.setString('user_fullName', this.fullName);
      await prefs.setString('user_bio', this.bio);
      await prefs.setString('user_avatarUrl', avatarUrl);
      await prefs.setBool('isVerified', this.isVerified);

      notifyListeners();
    });
  }

  Future getFriends() async {
    var record = await pb.collection('users').getOne(this.id);
    var map = record.toJson();

    List friends = map['friends'];
    return friends;
  }
}
