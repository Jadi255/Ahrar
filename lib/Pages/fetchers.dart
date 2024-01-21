import 'dart:async';

import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/renderers.dart';

List topics = [];
List topicIDs = [];

class Fetcher {
  final PocketBase pb;

  Fetcher({required this.pb});

  Future getUserPosts(context, id, pb, page, perPage) async {
    try {
      final request = await pb.collection('circle_posts').getList(
          page: page,
          perPage: perPage,
          expand: "by,comments.by, likes, dislikes",
          filter: 'by.id = "$id"',
          sort: '-created');

      var response = request.toJson();
      var posts = response['items'];
      return posts;
    } catch (e) {
      Future.delayed(Duration(seconds: 3), () async {
        getUserPosts(context, id, pb, page, perPage);
      });
    }
  }

  Future getProfilePosts(id, page, perPage) async {
    try {
      final request = await pb.collection('circle_posts').getList(
          page: page,
          perPage: perPage,
          expand: "by,comments.by, likes, dislikes",
          filter: 'by.id = "$id"',
          sort: '-created');

      var response = request.toJson();
      var posts = response['items'];
      return posts;
    } catch (e) {
      Future.delayed(Duration(seconds: 2), () async {
        getProfilePosts(id, page, perPage);
      });
    }
  }

  Future getTopicPosts(topic, page, perPage) async {
    try {
      final request = await pb.collection('circle_posts').getList(
          page: page,
          perPage: perPage,
          expand: "by,comments.by, likes, dislikes",
          filter: 'topic.id ?= "$topic"',
          sort: '-created');
      var response = request.toJson();
      var posts = response['items'];
      return posts;
    } catch (e) {
      Future.delayed(Duration(seconds: 2), () async {
        getTopicPosts(topic, page, perPage);
      });
    }
  }

  Future fetchTopics() async {
    try {
      topics.clear();
      topicIDs.clear();
      final records =
          await pb.collection('topics').getFullList(sort: '-created');
      for (var record in records) {
        var topic = record.toJson();
        topics.add(topic['topic']);
        topicIDs.add(topic['id']);
      }
    } catch (e) {
      Future.delayed(Duration(seconds: 2), () async {
        fetchTopics();
      });
    }
  }

  Future fetchTopic(String topicID) async {
    try {
      var request = await pb.collection('topics').getOne(topicID);
      var response = request.toJson();

      String topic = response['topic'];
      return topic;
    } catch (e) {
      Future.delayed(Duration(seconds: 2), () async {
        fetchTopic(topicID);
      });
    }
  }

  Future fetchComments(String id) async {
    try {
      var comments = await pb.collection('circle_comments').getFullList(
            filter: 'post.id = "$id"',
            expand: 'by',
          );
      return comments;
    } catch (e) {
      Future.delayed(Duration(seconds: 2), () async {
        fetchComments(id);
      });
    }
  }

  Future getPublicPosts(context, pb, page, perPage) async {
    try {
      final request = await pb.collection('circle_posts').getList(
            page: page,
            perPage: perPage,
            expand: "by,comments.by, likes, dislikes",
            filter: 'is_public = true',
            sort: '-created',
          );

      var response = request.toJson();
      var posts = response['items'];
      return posts;
    } catch (e) {
      Future.delayed(Duration(seconds: 1), () async {
        getPublicPosts(context, pb, page, perPage);
      });
    }
  }

  Future getFilteredPosts(context, pb, page, perPage, filter) async {
    try {
      String pbFilter = '';
      String pbSort = '-likes:length';
      DateTime now = DateTime.now();
      if (filter == 'all') {
        final request = await pb.collection('circle_posts').getList(
              page: page,
              perPage: perPage,
              expand: "by,comments.by, likes, dislikes",
              sort: pbSort,
            );
        var response = request.toJson();
        var posts = response['items'];
        return posts;
      } else {
        DateTime startDate;
        switch (filter) {
          case 'today':
            startDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            startDate = now.subtract(Duration(days: 7));
            break;
          case 'month':
            startDate = DateTime(now.year, now.month - 1, now.day);
            break;
          case 'year':
            startDate = DateTime(now.year - 1, now.month, now.day);
            break;
          default:
            startDate = DateTime.now();
        }

        String formattedStartDate =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate);
        pbFilter += 'created >= "$formattedStartDate"';
        final request = await pb.collection('circle_posts').getList(
              page: page,
              perPage: perPage,
              filter: pbFilter,
              sort: pbSort,
              expand: "by,comments.by, likes, dislikes",
            );
        var response = request.toJson();
        var posts = response['items'];
        return posts;
      }
    } catch (e) {
      Future.delayed(Duration(seconds: 5), () async {
        getFilteredPosts(context, pb, page, perPage, filter);
      });
    }
  }

  Future getFriendsPosts(context, pb, page, perPage) async {
    try {
      final request = await pb.collection('circle_posts').getList(
            page: page,
            perPage: perPage,
            expand: "by,comments.by, likes, dislikes",
            filter: 'is_public = false',
            sort: '-created',
          );

      var response = request.toJson();
      var posts = response['items'];
      return posts;
    } catch (e) {
      Future.delayed(Duration(seconds: 1), () async {
        getFriendsPosts(context, pb, page, perPage);
      });
    }
  }

  Future postSubscriber(context) async {
    final renderer = Provider.of<Renderer>(context, listen: false);
    pb.collection('circle_posts').subscribe("*", (e) async {
      var item = e.record!.toJson();
      var id = item['id'];
      var post = await pb.collection('circle_posts').getOne(
            id,
            expand: "by,comments.by, likes, dislikes",
          );
      renderer.updateSubscriber(e.action, post, context);
    });
  }

  Future getUser(user) async {
    try {
      var request = await pb.collection('users').getOne(user);

      return request;
    } catch (e) {
      Future.delayed(Duration(seconds: 2), () async {
        getUser(user);
      });
    }
  }

  Future searchUsers(user) async {
    try {
      final request =
          await pb.collection('users').getList(filter: 'full_name ?~ "$user"');
      return request.items;
    } catch (e) {
      Future.delayed(Duration(seconds: 3), () async {
        searchUsers(user);
      });
    }
  }

  Future getComment(comment) async {
    try {
      final request = await pb.collection('circle_comments').getOne(comment);

      return request;
    } catch (e) {
      Future.delayed(Duration(seconds: 3), () async {
        getComment(comment);
      });
    }
  }

  Future getPost(post) async {
    try {
      final request = await pb.collection('circle_posts').getOne(
            post,
            expand: "by,comments.by, likes, dislikes",
          );

      return request;
    } catch (e) {
      Future.delayed(Duration(seconds: 3), () async {
        getPost(post);
      });
    }
  }

  Future getNotificationCount(user) async {
    try {
      final records = await pb.collection('notifications').getFullList(
            filter: "seen = false && user.id='$user'",
            expand:
                'linked_user,linked_comment.post,linked_comment.post.comments, linked_comment.by',
            sort: '-created',
          );
      return records;
    } catch (e) {
      Future.delayed(Duration(seconds: 10), () async {
        getNotificationCount(user);
      });
    }
  }

  Future getNotifications(user) async {
    try {
      final records = await pb.collection('notifications').getList(
            page: 1,
            perPage: 15,
            filter: "user.id='$user'",
            expand:
                'linked_user,linked_comment.post,linked_comment.post.comments, linked_comment.by',
            sort: '-created',
          );
      return records.items;
    } catch (e) {
      Future.delayed(Duration(seconds: 5), () async {
        getNotifications(user);
      });
    }
  }

  Stream notificationSubscriber(context) async* {
    var controller = StreamController.broadcast();

    var map = {};
    pb.collection('notifications').subscribe('*', (e) {
      if (e.action == 'create') {
        map = e.record!.toJson();
        controller.add(map);
      }
    });
    yield* controller.stream;
  }

  Future sendRequest(target, id) async {
    var checkUnique = await pb
        .collection('notifications')
        .getList(filter: 'user = "$target" && linked_id = "$id"');

    if (checkUnique.items.length > 0) {
      return false;
    }
    final body = <String, dynamic>{
      "user": target,
      "type": 'request',
      "linked_id": id,
      "seen": false
    };
    var request = await pb.collection('notifications').create(body: body);

    return true;
  }

  Future acceptRequest(user, target, notification) async {
    try {
      var request = await pb.collection('users').getOne(user);
      var response = request.toJson();
      var friends = response['friends'];
      friends.add(target);

      var body = {"friends": friends};
      await pb.collection('users').update(user, body: body);

      request = await pb.collection('users').getOne(target);
      response = request.toJson();
      friends = response['friends'];
      friends.add(user);

      body = {"friends": friends};
      await pb.collection('users').update(target, body: body);

      await pb.collection('notifications').delete(notification);

      body = {
        "user": target,
        "type": "alert",
        "linked_id": user,
        "seen": false
      };
      await pb.collection('notifications').create(body: body);
    } catch (e) {
      Future.delayed(Duration(seconds: 3), () async {
        acceptRequest(user, target, notification);
      });
    }
  }

  Future ignoreRequest(notification) async {
    await pb.collection('notifications').delete(notification);
  }

  Future removeFriend(user, target) async {
    var request = await pb.collection('users').getOne(user);
    var response = request.toJson();
    var friends = response['friends'];
    friends.remove(target);

    var body = {"friends": friends};
    await pb.collection('users').update(user, body: body);

    request = await pb.collection('users').getOne(target);
    response = request.toJson();
    friends = response['friends'];
    friends.remove(user);

    body = {"friends": friends};
    await pb.collection('users').update(target, body: body);
  }

  Future markAsRead(target) async {
    try {
      final body = {'seen': true};

      await pb.collection('notifications').update(target, body: body);
    } catch (e) {
      Future.delayed(Duration(seconds: 5), () async {
        markAsRead(target);
      });
    }
  }

  Future deleteNotification(target) async {
    await pb.collection('notifications').delete(target);
  }

  Future fetchMessages(user) async {
    try {
      final request = await pb.collection('messages').getFullList(
            sort: '-created',
            expand: 'from, to',
            filter: 'to.id = "$user" || from.id = "$user"',
          );

      return request;
    } catch (e) {
      Future.delayed(Duration(seconds: 1), () async {
        fetchMessages(user);
      });
    }
  }

  Future getAlerts(user) async {
    var alerts = await pb.collection('alerts').getFullList(
          filter: 'seen = false && to.id = "$user"',
        );

    return alerts;
  }
}
