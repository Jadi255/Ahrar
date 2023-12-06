import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

List topics = [];
List topicIDs = [];

class Fetcher {
  final PocketBase pb;

  Fetcher({required this.pb});

  Future getUserPosts(context, id, pb, page, perPage) async {
    final request = await pb.collection('circle_posts').getList(
        page: page,
        perPage: perPage,
        filter: 'by.id = "$id"',
        sort: '-created');

    var response = request.toJson();
    var posts = response['items'];
    return posts;
  }

  Future fetchTopics() async {
    topics.clear();
    topicIDs.clear();
    final records = await pb.collection('topics').getFullList(sort: '-created');
    for (var record in records) {
      var topic = record.toJson();
      topics.add(topic['topic']);
      topicIDs.add(topic['id']);
    }
  }

  Future fetchTopic(String topicID) async {
    var request = await pb.collection('topics').getOne(topicID);
    var response = request.toJson();

    String topic = response['topic'];
    return topic;
  }

  Future fetchComments(String id) async {
    return pb.collection('circle_comments').getOne(id);
  }

  Future atSignHelper(String name) async {
    var request =
        await pb.collection('users').getList(filter: 'full_name ?~ "$name"');
    var response = request.items;
    return response;
  }

  Future getPublicPosts(context, pb, page, perPage) async {
    final request = await pb.collection('circle_posts').getList(
          page: page,
          perPage: perPage,
          sort: '-created',
        );

    var response = request.toJson();
    var posts = response['items'];
    return posts;
  }
}
