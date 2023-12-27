import 'package:pocketbase/pocketbase.dart';

class Writer {
  final PocketBase pb;

  Writer({required this.pb});

  Future sendReport(reason, post, mode, report) async {
    final body;
    if (mode) {
      body = <String, dynamic>{"post": post, "report": report, "field": reason};
    } else {
      body = <String, dynamic>{
        "comment": post,
        "report": report,
        "field": reason
      };
    }

    try {
      final record = await pb.collection('reports').create(body: body);
    } catch (e) {}
    return;
  }

  Future likePost(id, likes) async {
    final data = {
      "likes": likes,
    };

    var request = await pb.collection('circle_posts').update(id, body: data);
  }

  Future dislikePost(id, dislikes) async {
    final data = {
      "dislikes": dislikes,
    };

    var request = await pb.collection('circle_posts').update(id, body: data);
  }

  Future updatePost(id, post) async {
    final body = {"post": post};

    await pb.collection('circle_posts').update(id, body: body);
  }

  Future updateComment(id, comment) async {
    final body = {"comment": comment};

    final request =
        await pb.collection('circle_comments').update(id, body: body);
  }

  Future deletePost(id, context) async {
    final record = await pb.collection('circle_posts').getOne(id);
    final map = record.toJson();
    final comments = map['comments'];

    if (comments.isNotEmpty) {
      for (var comment in comments) {
        await pb.collection('circle_comments').delete(comment);
      }
    }

    await pb.collection('circle_posts').delete(id);
  }

  Future deleteComment(id, context) async {
    await pb.collection('circle_comments').delete(id);
  }

  Future createPost(images, topics, user, isPublic, post, videoLink) async {
    var topicIDs = [];
    if (topics.isNotEmpty) {
      for (var topic in topics) {
        var topicRecord =
            await pb.collection('topics').getList(filter: 'topic ?~ "$topic"');
        if (topicRecord.items.isNotEmpty) {
          var item = topicRecord.items[0];
          var topicMap = item.toJson();
          topicIDs.add(topicMap['id']);
        } else {
          var newTopic =
              await pb.collection('topics').create(body: {"topic": "$topic"});

          var newTopicMap = newTopic.toJson();
          topicIDs.add(newTopicMap['id']);
        }
      }
    }

    final body = {
      "by": user,
      "post": post,
      "is_public": isPublic,
      "topic": topicIDs,
      "linked_video": videoLink
    };
    var record =
        await pb.collection('circle_posts').create(body: body, files: images);
    var newPost = record.toJson();
    var postID = newPost['id'];
    if (topicIDs.isNotEmpty) {
      for (var topic in topicIDs) {
        var request = await pb.collection('topics').getOne(topic);
        var response = request.toJson();
        var posts = response['posts'];
        posts.add(postID);

        final body = <String, dynamic>{
          "topic": response['topic'],
          "posts": posts
        };
        for (var post in posts) {}

        final record = await pb.collection('topics').update(topic, body: body);
      }
    }
  }

  Future writeComment(comment, post, user) async {
    final body = <String, dynamic>{
      "post": post,
      "by": user,
      "comment": comment
    };

    final record = await pb.collection('circle_comments').create(body: body);
    final recordMap = record.toJson();
    final commentID = recordMap['id'];
    final postRecord = await pb.collection('circle_posts').getOne(post);
    final postMap = await postRecord.toJson();
    final comments = postMap['comments'];
    comments.add(commentID);
    await pb
        .collection('circle_posts')
        .update(postMap['id'], body: {'comments': comments});
    return record;
  }

  Future markNotificationRead(id) async {
    final body = {"seen": true};

    final request = await pb.collection('notifications').update(id, body: body);
  }

  Future sendMessage(message, from, to) async {
    final body = <String, dynamic>{"to": to, "from": from, "text": message};

    final record = await pb.collection('messages').create(body: body);
    final response = record.toJson();
    return response;
  }

  Future messageNotifier(to, from) async {
    final body = <String, dynamic>{
      "user": to,
      "type": "message",
      "linked_id": from,
      "seen": false
    };

    final record = await pb.collection('notifications').create(body: body);
  }

  Future newCommentNotify(record, user) async {
    List toNotify = [];
    var comment = record.toJson();
    var post = (comment['post']);
    var commentors = await pb
        .collection('circle_comments')
        .getFullList(filter: 'post.id = "$post"');

    for (var record in commentors) {
      var commentor = record.toJson();
      var id = commentor['by'];
      if (id != user) {
        toNotify.add(id);
      }
    }
    var postRecord = await pb.collection('circle_posts').getOne(post);
    var postData = postRecord.toJson();
    toNotify.add(postData['by']);
    toNotify = toNotify.toSet().toList();
    print(toNotify);

    for (var user in toNotify) {
      final body = <String, dynamic>{
        "user": user,
        "type": "comment",
        "linked_id": comment['id'],
        "seen": false
      };
      final record = await pb.collection('notifications').create(body: body);
    }

    /*
     */
  }
}
