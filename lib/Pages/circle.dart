import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:tahrir/Pages/profiles.dart';
import 'package:http_parser/http_parser.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:tahrir/Pages/topics.dart';
import 'package:url_launcher/url_launcher.dart';

import '../user_data.dart';
import "styles.dart";

class Circle extends StatefulWidget {
  const Circle({super.key});

  @override
  State<Circle> createState() => _CircleState();
}

class _CircleState extends State<Circle> {
  int _page = 1;
  List<Widget> _postsWidgets = [];
  bool _isLoading = false;
  late String newestID;
  Map postItem = {};
  List commentsItem = [];
  bool? isPublic;
  List<String> topics = [];
  List<String> topicIDs = [];
  String? filter = "newest";
  String? timeRange = 'today';

  late String selectedTopic;
  String selectedTopicId = '';
  @override
  void initState() {
    super.initState();
    fetchPosts();
    getUpdates();
    fetchTopics();
  }

  void fetchPosts() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      fetchPosts();
      List<Widget> newPosts = await renderPosts(limit: 7, page: _page);

      setState(() {
        _postsWidgets.addAll(newPosts);
        _page += 1;
        _isLoading = false;
      });
    }
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

  Future<List<Widget>> renderPosts(
      {int limit = 7,
      int page = 1,
      bool isFiltering = false,
      String? selectedTopicId,
      List<String>? topics}) async {
    Map data;
    if (isFiltering) {
      data = await filterCirclePosts(
          limit: limit,
          page: page,
          filter: filter ?? '',
          timeRange: timeRange ?? '');
    } else {
      data = await getCirclePosts(limit: limit, page: page);
    }
    if (_postsWidgets.isEmpty) {
      newestID = data['items'][0]['id'];
    }
    List<Widget> widgets = [];
    for (var i = 0; i < data['items'].length; i++) {
      var post = data['items'][i];
      var posterRecord = await pb.collection('users').getOne(post['by']);
      Map userData = posterRecord.toJson();

      var avatarUrl =
          pb.getFileUrl(posterRecord, userData['avatar']).toString();
      var postTime = DateFormat('dd/MM/yyyy · HH:mm')
          .format(DateTime.parse(post['created']).toLocal());
      String by = '${userData['fname']} ${userData['lname']}';
      var posterAvatar =
          Image.network('$avatarUrl?token=${pb.authStore.token}');
      int ratio = post['likes'].length - post['dislikes'].length;

      Widget postWidget = ratio < 0
          ? themedCard(ExpansionTile(
              title: Center(
                  child: Text(
                      'هذا المنشور حصل على تصنيف متدني، أنقر هنا لمشاهدته',
                      style: defaultText)),
              children: [createPostWidget(post, by, posterAvatar, postTime, i)],
            ))
          : createPostWidget(post, by, posterAvatar, postTime, i);
      widgets.add(postWidget);
    }

    setState(() {});
    return widgets;
  }

  String timeAgo(DateTime date) {
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} د';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} س';
    } else {
      return DateFormat('dd/MM/yyyy').format(date.toLocal());
    }
  }

  Widget createPostWidget(
      var post, String by, var posterAvatar, String postTime, int index) {
    List<String> imageUrls = [];
    ValueNotifier<int> ratio =
        ValueNotifier<int>(post['likes'].length - post['dislikes'].length);

    postItem = post;
    List topicStrings = [];
    for (var item in post['topic']) {
      int index = topicIDs.indexOf(item);
      if (index != -1) {
        topicStrings.add(topics[index]);
      }
    }

    var postTime = timeAgo(DateTime.parse(post['created']).toLocal());
    if (post['pictures'].isNotEmpty) {
      var pictures = post['pictures'];
      RecordModel record = RecordModel.fromJson(post);
      for (var picture in pictures) {
        var url =
            '${pb.getFileUrl(record, picture)}?token=${pb.authStore.token}';
        imageUrls.add(url);
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: themedCard(
        Column(
          crossAxisAlignment: isArabic(post['post'])
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        if (post['by'] != userID) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ViewProfile(target: post['by']),
                            ),
                          );
                        }
                      },
                      child: ClipOval(
                          child: CircleAvatar(
                              backgroundColor: Colors.white,
                              child: posterAvatar,
                              radius: 25)),
                    ),
                    title: GestureDetector(
                        onTap: () {
                          if (post['by'] != userID) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    ViewProfile(target: post['by']),
                              ),
                            );
                          }
                        },
                        child: Text(by, style: defaultText)),
                    subtitle: Row(
                      children: [
                        Transform.scale(
                          scale: 0.75,
                          child: Tooltip(
                            message: post['is_public']
                                ? 'منشور عام'
                                : 'منشور للأصدقاء فقط',
                            child: Icon(post['is_public']
                                ? Icons.public
                                : Icons.people),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.75,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 3.0),
                            child: Text(postTime),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (post['by'] == userID)
                  PopupMenuButton<String>(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    onSelected: (String result) async {
                      if (result == 'Edit') {
                        showBottomSheet(
                            backgroundColor: Colors.transparent,
                            context: context,
                            builder: (context) => EditPost(post: post));
                      } else if (result == "Delete") {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                actionsAlignment:
                                    MainAxisAlignment.spaceBetween,
                                backgroundColor: Colors.white,
                                surfaceTintColor: Colors.white,
                                content: Text('هل أنت متأكد؟',
                                    style: defaultText,
                                    textAlign: TextAlign.center),
                                actions: [
                                  IconButton(
                                    onPressed: () async {
                                      await pb
                                          .collection('circle_posts')
                                          .delete(post['id']);
                                      _postsWidgets.removeAt(index);
                                      setState(() {
                                        _postsWidgets;
                                      });
                                      await fetchPosts;

                                      Navigator.of(context).pop();
                                    },
                                    icon: Icon(Icons.check, color: greenColor),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    icon: Icon(Icons.close, color: redColor),
                                  )
                                ],
                              );
                            });
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'Edit',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تعديل',
                              textAlign: TextAlign.center,
                            ),
                            Icon(Icons.edit),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'Delete',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'حذف',
                              textAlign: TextAlign.center,
                            ),
                            Icon(Icons.delete_forever),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (post['by'] != userID)
                  PopupMenuButton<String>(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    onSelected: (String result) async {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return ReportAbuse(post: post, mode: true);
                          });
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'Report',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تبليغ',
                              textAlign: TextAlign.center,
                            ),
                            Icon(Icons.report),
                          ],
                        ),
                      ),
                    ],
                  )
              ],
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10),
              child: Wrap(
                children: topicStrings.map(
                  (topic) {
                    return GestureDetector(
                      onTap: () {
                        var index = topics.indexOf(topic);
                        var id = topicIDs[index];
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => DiscoverTopics(topic: id)));
                      },
                      child: Text(
                        "#$topic",
                        style: topicText,
                        textDirection: isArabic(post['post'])
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
            if (imageUrls.length == 1)
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
                            child: Image.network(imageUrls[0]),
                          ),
                        );
                      });
                },
                child: Center(
                  child: Image.network(
                    imageUrls[0],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (imageUrls.length > 1)
              CarouselSlider(
                options: CarouselOptions(
                  height: 400.0,
                  pageSnapping: true,
                ),
                items: imageUrls.map((imageUrl) {
                  return Builder(
                    builder: (BuildContext context) {
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                                child: InteractiveViewer(
                                  child: Image.network(
                                    imageUrl,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5.0),
                          decoration:
                              const BoxDecoration(color: Colors.transparent),
                          child: Image.network(imageUrl, fit: BoxFit.cover),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: SelectableLinkify(
                onOpen: (link) async {
                  await launchUrl(Uri.parse(link.url));
                },
                text: post['post'],
                textDirection: isArabic(post['post'])
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              ),
            ),
            FutureBuilder<Widget>(
              future: createPostActions(post, ratio.value, index),
              builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return shimmer; // or your custom loader
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return snapshot.data!;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<Widget> createPostActions(var post, int ratio, int index) async {
    var records = await pb
        .collection('circle_comments')
        .getFullList(sort: 'created', filter: 'post="${post['id']}"');
    int commentCount = records.length;

    commentsItem.add(records);
    return StatefulBuilder(builder: (context, setState) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          createCommentButton(context, post, commentCount, index),
          createLikeDislikeButtons(post, setState),
        ],
      );
    });
  }

  Widget createLikeDislikeButtons(
      var post, void Function(void Function()) setState) {
    ValueNotifier<int> ratio =
        ValueNotifier<int>(post['likes'].length - post['dislikes'].length);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        createLikeButton(context, post, ratio),
        ValueListenableBuilder<int>(
          valueListenable: ratio,
          builder: (context, value, child) {
            return Text('$value');
          },
        ),
        createDislikeButton(context, post, ratio),
      ],
    );
  }

  Widget createLikeButton(
      BuildContext context, var post, ValueNotifier<int> ratio) {
    bool isLiked = post['likes'].contains(pb.authStore.model.id);
    bool isDisliked = post['dislikes'].contains(pb.authStore.model.id);
    return IconButton(
      onPressed: () async {
        if (!isLiked) {
          post['likes'].add(pb.authStore.model.id);
          if (isDisliked) {
            post['dislikes'].remove(pb.authStore.model.id);
          }
        } else {
          post['likes'].remove(pb.authStore.model.id);
        }
        await updatePostLikesAndDislikes(post);
        ratio.value = post['likes'].length - post['dislikes'].length;
      },
      icon:
          Icon(Icons.arrow_drop_up, color: isLiked ? greenColor : Colors.black),
    );
  }

  Widget createDislikeButton(
      BuildContext context, var post, ValueNotifier<int> ratio) {
    bool isLiked = post['likes'].contains(pb.authStore.model.id);
    bool isDisliked = post['dislikes'].contains(pb.authStore.model.id);
    return IconButton(
      onPressed: () async {
        if (!isDisliked) {
          post['dislikes'].add(pb.authStore.model.id);
          if (isLiked) {
            post['likes'].remove(pb.authStore.model.id);
          }
        } else {
          post['dislikes'].remove(pb.authStore.model.id);
        }
        await updatePostLikesAndDislikes(post);
        ratio.value = post['likes'].length - post['dislikes'].length;
      },
      icon: Icon(Icons.arrow_drop_down,
          color: isDisliked ? redColor : Colors.black),
    );
  }

  Widget createCommentButton(
      BuildContext context, var post, int commentCount, int index) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0),
      child: IconButton(
        style: BlackTextButton,
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ShowComments(
              post: post,
            ),
          ));
        },
        icon: Row(
          children: [
            const Icon(Icons.comment),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Text('$commentCount'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> updatePostLikesAndDislikes(var post) async {
    final body = <String, dynamic>{
      "likes": post['likes'],
      "dislikes": post['dislikes']
    };
    await pb.collection('circle_posts').update(post['id'], body: body);
  }

  void getUpdates() {
    if (kIsWeb) {
      Timer.periodic(const Duration(seconds: 3), (timer) async {
        var record = await pb
            .collection('circle_posts')
            .getList(page: 1, perPage: 1, sort: '-created');
        var data = record.toJson();
        if (newestID != data['items'][0]['id']) {
          newestID = data['items'][0]['id'];
          List<Widget> newPosts = await renderPosts();
          newPostAlert();
          setState(() {
            _postsWidgets += newPosts;
          });
        }
      });
    } else {
      circleSubscribe((event) async {
        var newPost = event.toJson();
        var posterRecord = await pb.collection('users').getOne(newPost['by']);
        Map userData = posterRecord.toJson();
        String by = '${userData['fname']} ${userData['lname']}';

        var avatarUrl =
            pb.getFileUrl(posterRecord, userData['avatar']).toString();
        var posterAvatar =
            Image.network('$avatarUrl?token=${pb.authStore.token}');

        var postTime = DateFormat('dd/MM/yyyy · HH:mm')
            .format(DateTime.parse(newPost['created']).toLocal());

        var postWidget =
            await createPostWidget(newPost, by, posterAvatar, postTime, 0);
        newPostAlert();

        setState(() {
          _postsWidgets.insert(0, postWidget);
        });
      });
    }
  }

  void newPostAlert() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('يوجد منشورات جديدة', style: defaultText),
              ],
            ),
          ),
        ),
      );
    });
  }

  String getTopicId(String topic) {
    int index = topics.indexOf(topic);
    if (index != -1) {
      return topicIDs[index];
    }
    return '';
  }

  Future<Map> filterCirclePosts(
      {int limit = 10,
      int page = 1,
      String? filter,
      String? timeRange,
      String? selectedTopicId}) async {
    print(isPublic);
    String pbFilter = '';
    String pbSort = '-created';
    if (filter != null && filter == 'top') {
      pbSort = '-likes:length';
    }
    if (isPublic != null) {
      if (pbFilter.isNotEmpty) {
        pbFilter += ' && ';
      }
      pbFilter += 'is_public = $isPublic';
    }
    if (selectedTopicId != null && selectedTopicId.isNotEmpty) {
      if (pbFilter.isNotEmpty) {
        pbFilter += ' || ';
      }
      pbFilter += 'topic.id = \'$selectedTopicId\'';
    }

    if (timeRange != null && timeRange != 'all') {
      DateTime now = DateTime.now();
      DateTime startDate;
      switch (timeRange) {
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
      if (pbFilter.isNotEmpty) {
        pbFilter += ' && ';
      }
      String formattedStartDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate);
      pbFilter += 'created >= "$formattedStartDate"';
    }

    final resultList = await pb.collection('circle_posts').getList(
          page: page,
          perPage: limit,
          filter: pbFilter,
          sort: pbSort,
        );
    return resultList.toJson();
  }

  @override
  Widget build(BuildContext context) {
    bool isVisible = false;
    if (filter == 'top') {
      isVisible = true;
    }

    if (_postsWidgets.isEmpty) {
      fetchPosts();
    }
    Widget filterOptions = StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: true,
            actions: [
              IconButton(
                onPressed: () async {
                  showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder: (context) {
                        return Center(
                          child: CupertinoActivityIndicator(
                            color: Colors.white,
                          ),
                        );
                      });

                  isPublic = null;
                  filter = null;
                  timeRange = null;
                  selectedTopicId = '';
                  var newPosts = await renderPosts(
                      limit: 7, page: 1, topics: [], isFiltering: false);
                  setState(() {
                    isVisible = false;
                    _postsWidgets = newPosts;
                  });
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.filter_alt_off_sharp),
              )
            ],
            centerTitle: true,
            title: Text(
              'فلترة ',
              style: defaultText,
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CupertinoSlidingSegmentedControl<bool>(
                    children: const {
                      true: Text('منشورات عامة'),
                      false: Text('أصدقائي'),
                    },
                    onValueChanged: (bool? value) {
                      setState(() {
                        print(value);
                        isPublic = value;
                      });
                    },
                    groupValue: isPublic,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: const Divider(),
                  ),
                  CupertinoSlidingSegmentedControl<String>(
                    children: const {
                      'newest': Text('الأحدث'),
                      'top': Text('الأعلى تصنيفاً'),
                    },
                    onValueChanged: (String? value) {
                      setState(() {
                        filter = value!;
                        if (value == 'top') {
                          isVisible = true;
                        } else {
                          isVisible = false;
                        }
                      });
                    },
                    groupValue: filter, // Your filter variable
                  ),
                  Visibility(
                    visible: isVisible,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: const Divider(),
                        ),
                        CupertinoSlidingSegmentedControl<String>(
                          children: const {
                            'today': Text('اليوم'),
                            'week': Text('هذا الأسبوع'),
                            'month': Text('هذا الشهر'),
                            'year': Text('هذا العام'),
                            'all': Text('كل الأوقات'),
                          },
                          onValueChanged: (String? value) {
                            setState(() {
                              timeRange = value!;
                            });
                          },
                          groupValue: timeRange, // Your time range variable
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: const Divider(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: FilledButton(
                        style: FilledButtonStyle,
                        onPressed: () async {
                          showDialog(
                              barrierDismissible: false,
                              context: context,
                              builder: (context) {
                                return Center(
                                  child: CupertinoActivityIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              });

                          var newPosts = await renderPosts(
                              topics: [selectedTopicId], isFiltering: true);
                          Navigator.of(context).pop(); // Add this line
                          setState(() {
                            _postsWidgets = newPosts;
                          });
                          Navigator.of(context).pop(); // Add this line
                        },
                        child: const Text('فلترة')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return Scaffold(
      floatingActionButton: FilledButton(
          onPressed: () {
            showBottomSheet(
              backgroundColor: Colors.transparent,
              context: context,
              builder: (context) => CreatePost(
                topics: topics,
                topicIDs: topicIDs,
                onNewTopic: (newTopic) {
                  setState(() {
                    topics.add(newTopic['topic']);
                    topicIDs.add(newTopic['id']);
                  });
                },
              ),
            );
          },
          style: FilledButtonStyle,
          child: const Icon(Icons.add)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.only(left: 5, right: 5, bottom: 3, top: 10),
              child: Container(
                child: ElevatedButton(
                  style: const ButtonStyle(
                      foregroundColor: MaterialStatePropertyAll(Colors.black),
                      overlayColor: MaterialStatePropertyAll(Colors.white),
                      backgroundColor: MaterialStatePropertyAll(Colors.white),
                      surfaceTintColor: MaterialStatePropertyAll(Colors.white)),
                  onPressed: () {
                    showModalBottomSheet(
                      backgroundColor: Colors.white,
                      context: context,
                      builder: (context) {
                        return filterOptions;
                      },
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('خيارات'),
                      const Icon(Icons.filter_alt),
                    ],
                  ),
                ),
              ),
            ),
            ..._postsWidgets,
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.all(5),
                child: Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: const ButtonStyle(
                        foregroundColor: MaterialStatePropertyAll(Colors.black),
                        overlayColor: MaterialStatePropertyAll(Colors.white),
                        backgroundColor: MaterialStatePropertyAll(Colors.white),
                        surfaceTintColor:
                            MaterialStatePropertyAll(Colors.white)),
                    onPressed: fetchPosts,
                    child: Text('المزيد', style: defaultText),
                  ),
                ),
              ),
            if (_isLoading) shimmer,
          ],
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class EditPost extends StatefulWidget {
  Map post;
  EditPost({super.key, required this.post});

  @override
  State<EditPost> createState() => _EditPostState();
}

class _EditPostState extends State<EditPost> {
  TextEditingController controller = TextEditingController();
  FilePickerResult? images;
  late String id;
  late String by;
  TextDirection textDirection = TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    controller.text = widget.post['post'];
    id = widget.post['id'];
    by = widget.post['by'];
  }

  Future<void> EditPost() async {
    if (controller.text == "") {
      return;
    }
    final body = <String, dynamic>{
      "by": by,
      "post": controller.text,
    };
    try {
      if (images != null) {
        List<http.MultipartFile> multipartFiles = [];
        for (var file in images!.files) {
          http.MultipartFile multipartFile;
          if (kIsWeb) {
            Uint8List fileBytes = file.bytes!;
            multipartFile = http.MultipartFile.fromBytes(
              'pictures',
              fileBytes,
              filename: file.name,
              contentType: MediaType(
                'image',
                'jpeg', // Replace with the appropriate content type
              ),
            );
          } else {
            multipartFile = await http.MultipartFile.fromPath(
              'pictures',
              file.path!,
            );
          }
          multipartFiles.add(multipartFile);
        }
        await pb
            .collection('circle_posts')
            .update(id, body: body, files: multipartFiles);
      } else {
        await pb.collection('circle_posts').update(id, body: body);
      }
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('حدث خطأ ما، الرجاء المحاولة في وقت لاحق')),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return themedCard(
      SingleChildScrollView(
        child: Container(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      color: images != null && images!.files.isNotEmpty
                          ? greenColor
                          : null,
                      onPressed: () async {
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles(
                          allowMultiple: true,
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png'],
                        );

                        images = result;
                        setState(() {});
                      },
                    ),
                    Expanded(
                      child: StatefulBuilder(builder: (context, setState) {
                        return TextField(
                          onChanged: (value) {
                            setState(() {
                              textDirection =
                                  RegExp(r'[\u0600-\u06FF]').hasMatch(value)
                                      ? TextDirection.rtl
                                      : TextDirection.ltr;
                            });
                          },
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: "إضافة منشور جديد",
                            suffixIcon: IconButton(
                              onPressed: EditPost,
                              icon: const Icon(Icons.send),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class CreatePost extends StatefulWidget {
  CreatePost(
      {super.key,
      required this.topics,
      required this.topicIDs,
      required this.onNewTopic});
  List<String> topicIDs;
  List<String> topics;
  final Function onNewTopic;

  @override
  State<CreatePost> createState() => _CreatePostState();
}

class _CreatePostState extends State<CreatePost> {
  TextEditingController controller = TextEditingController();
  FilePickerResult? images;
  bool isPublic = true;
  late List<String> topics;
  late List<String> topicIDs;
  String? selectedTopic;
  String? selectedTopicId;
  bool isTypeAheadVisible = false; // Add this line
  TextDirection textDirection = TextDirection.ltr;

  TextEditingController newTopicController = TextEditingController();
  Widget topicBtn = const Row(
    children: [
      Text('موضوع'),
      Icon(Icons.tag),
    ],
  );

  @override
  void initState() {
    super.initState();
    topics = widget.topics;
    topicIDs = widget.topicIDs;
  }

  Future<void> createPost() async {
    List posts = [];
    String postID;
    if (controller.text == "") {
      return;
    }

    if (selectedTopicId != null) {
      final record = await pb.collection('topics').getOne(
            '$selectedTopicId',
          );

      var topicRecord = record.toJson();
      for (var post in topicRecord['posts']) {
        posts.add(post);
      }
    }
    final body = <String, dynamic>{
      "by": userID,
      "is_public": isPublic,
      "post": controller.text,
      "topic": [selectedTopicId ??= ""],
    };
    try {
      if (images != null) {
        List<http.MultipartFile> multipartFiles = [];
        for (var file in images!.files) {
          http.MultipartFile multipartFile;
          if (kIsWeb) {
            Uint8List fileBytes = file.bytes!;
            multipartFile = http.MultipartFile.fromBytes(
              'pictures',
              fileBytes,
              filename: file.name,
              contentType: MediaType(
                'image',
                'jpeg', // Replace with the appropriate content type
              ),
            );
          } else {
            multipartFile = await http.MultipartFile.fromPath(
              'pictures',
              file.path!,
            );
          }
          multipartFiles.add(multipartFile);
        }
        var record = await pb
            .collection('circle_posts')
            .create(body: body, files: multipartFiles);
        var newPost = record.toJson();
        posts.add(newPost['id']);
        postID = newPost['id'];
      } else {
        final body = <String, dynamic>{
          "by": userID,
          "is_public": isPublic,
          "post": controller.text,
          "topic": selectedTopicId ??= "",
        };
        var record = await pb.collection('circle_posts').create(body: body);
        var newPost = record.toJson();
        posts.add(newPost['id']);
        postID = newPost['id'];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('حدث خطأ ما، الرجاء المحاولة في وقت لاحق')),
      );
      return;
    }
    if (selectedTopicId != "" && selectedTopicId != null) {
      final body = <String, dynamic>{
        "posts": [postID]
      };

      final record =
          await pb.collection('topics').update(selectedTopicId!, body: body);
    }
  }

  Future newTopic(topic) async {
    final body = <String, dynamic>{
      "topic": topic,
    };

    final record = await pb.collection('topics').create(body: body);
    var newTopic = record.toJson();
    selectedTopicId = newTopic['id'];

    return selectedTopicId;
  }

  String getTopicId(String topic) {
    int index = topics.indexOf(topic);
    if (index != -1) {
      return topicIDs[index];
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return themedCard(
      SingleChildScrollView(
        child: Container(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 5.0),
                      child: IconButton(
                        icon: const Icon(Icons.image),
                        color: images != null && images!.files.isNotEmpty
                            ? greenColor
                            : null,
                        onPressed: () async {
                          FilePickerResult? result =
                              await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            type: FileType.custom,
                            allowedExtensions: ['jpg', 'jpeg', 'png'],
                          );
                          images = result;
                          setState(() {});
                        },
                      ),
                    ),
                    Expanded(
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
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: "إضافة منشور جديد",
                            suffixIcon: IconButton(
                              onPressed: () async {
                                await createPost();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.send),
                            ),
                          ),
                        );
                      })),
                    ),
                  ],
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5.0, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          isTypeAheadVisible // Replace OutlinedButton with this
                              ? Flexible(
                                  child: TypeAheadField(
                                    debounceDuration:
                                        Duration(milliseconds: 200),
                                    textFieldConfiguration:
                                        TextFieldConfiguration(
                                      onChanged: (value) {
                                        setState(() {
                                          textDirection =
                                              RegExp(r'[\u0600-\u06FF]')
                                                      .hasMatch(value)
                                                  ? TextDirection.rtl
                                                  : TextDirection.ltr;
                                        });
                                      },
                                      autofocus: true,
                                      decoration: InputDecoration(
                                          border: OutlineInputBorder()),
                                    ),
                                    suggestionsCallback: (pattern) async {
                                      if (pattern.isEmpty) return [];
                                      var matches = topics
                                          .where((topic) =>
                                              topic.contains(pattern))
                                          .toList();
                                      if (matches.isEmpty)
                                        matches.add('$pattern');
                                      return matches;
                                    },
                                    itemBuilder: (context, suggestion) {
                                      return ListTile(
                                        title: Text(suggestion),
                                      );
                                    },
                                    onSuggestionSelected: (suggestion) async {
                                      selectedTopic = suggestion.trim();
                                      if (!topics.contains(selectedTopic)) {
                                        var newTopicId =
                                            await newTopic(selectedTopic);
                                        selectedTopicId = newTopicId;
                                      } else {
                                        int topicIndex =
                                            topics.indexOf(selectedTopic!);
                                        selectedTopicId = topicIDs[topicIndex];
                                      }
                                      setState(() {
                                        topicBtn = Row(
                                          children: [
                                            Text(selectedTopic!),
                                            Icon(Icons.tag),
                                          ],
                                        );
                                        isTypeAheadVisible = false;
                                      });
                                    },
                                  ),
                                )
                              : OutlinedButton(
                                  style: ButtonStyle(
                                    foregroundColor:
                                        MaterialStatePropertyAll(greenColor),
                                    overlayColor:
                                        const MaterialStatePropertyAll(
                                            Colors.white),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isTypeAheadVisible = true;
                                    });
                                  },
                                  child: topicBtn,
                                ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: CupertinoSlidingSegmentedControl<bool>(
                          children: const {
                            true: Text('منشور عام'),
                            false: Text('منشور للأصدقاء'),
                          },
                          onValueChanged: (bool? value) {
                            setState(() {
                              isPublic = value!;
                            });
                          },
                          groupValue: isPublic,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShowComments extends StatefulWidget {
  final Map post;

  ShowComments({
    super.key,
    required this.post,
  });

  @override
  _ShowCommentsState createState() => _ShowCommentsState();
}

class _ShowCommentsState extends State<ShowComments> {
  List<Widget> comments = [];
  TextEditingController controller = TextEditingController();
  bool _isLoading = true; // Add this line
  bool editMode = false;
  late String editID;
  late List records;
  String topic = '';
  TextDirection textDirection = TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    fetchComments();
  }

  Future<void> NotificationHandling() async {
    String id = widget.post['id'];

    var commentsRecord = await pb
        .collection('circle_comments')
        .getFullList(filter: 'post.id = "$id"', sort: '+created');

    var postRecord =
        await pb.collection('circle_posts').getOne(widget.post['id']);

    late String topicID;
    if (postRecord.toJson()['topic'].isNotEmpty) {
      topicID = postRecord.toJson()['topic'][0];
    } else {
      topicID = '';
    }
    records = commentsRecord;
    if (topicID != '') {
      var request = await pb.collection('topics').getOne(topicID);
      topic = request.toJson()['topic'];
    }
  }

  Future<void> fetchComments() async {
    comments.clear();

    await NotificationHandling();
    for (var i = 0; i < records.length; i++) {
      comments.add(await createCommentCard(records[i], i));
    }
    setState(() {
      _isLoading = false; // Add this line
    });
  }

  Future<Widget> createCommentCard(var record, int index) async {
    var post = record.toJson();
    var posterRecord = await pb.collection('users').getOne(post['by']);
    Map userData = posterRecord.toJson();

    String name = '${userData['fname']} ${userData['lname']}';
    var avatarUrl = pb.getFileUrl(posterRecord, userData['avatar']).toString();
    var postTime = timeAgo(DateTime.parse(post['created']).toLocal());

    Widget header = GestureDetector(
      onTap: () {
        if (post['by'] != userID) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => ViewProfile(target: post['by'])));
        }
      },
      child: Row(
        children: [
          Flexible(
            child: ListTile(
              leading: ClipOval(
                  child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 15,
                      child: Image.network(avatarUrl))),
              title: Text(name, style: defaultText),
              subtitle: Text(
                postTime,
                textScaler: const TextScaler.linear(0.65),
              ),
            ),
          ),
          if (post['by'] == userID)
            PopupMenuButton<String>(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              onSelected: (String result) async {
                if (result == 'Edit') {
                  controller.text = post['comment'];
                  editMode = true;
                  editID = post['id'];
                } else if (result == "Delete") {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.white,
                        content: Text('هل أنت متأكد؟',
                            style: defaultText, textAlign: TextAlign.center),
                        actions: [
                          IconButton(
                            onPressed: () async {
                              setState(() {
                                comments.removeAt(index);
                              });
                              await pb
                                  .collection('circle_comments')
                                  .delete(post['id']);
                              await fetchComments();
                              Navigator.of(context).pop();
                            },
                            icon: Icon(Icons.check, color: greenColor),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: Icon(Icons.close, color: redColor),
                          )
                        ],
                      );
                    },
                  );
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'Edit',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تعديل',
                        textAlign: TextAlign.center,
                      ),
                      Icon(Icons.edit),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Delete',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'حذف',
                        textAlign: TextAlign.center,
                      ),
                      Icon(Icons.delete_forever),
                    ],
                  ),
                ),
              ],
            ),
          if (post['by'] != userID)
            PopupMenuButton<String>(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              onSelected: (String result) async {
                showDialog(
                    context: context,
                    builder: (context) {
                      return ReportAbuse(post: post, mode: false);
                    });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'Report',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تبليغ',
                        textAlign: TextAlign.center,
                      ),
                      Icon(Icons.report),
                    ],
                  ),
                ),
              ],
            )
        ],
      ),
    );

    return Card(
      color: Colors.grey.shade100,
      surfaceTintColor: Colors.white,
      elevation: 1,
      child: Column(
        crossAxisAlignment: isArabic(post['post'])
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          header,
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: SelectableText(
                  post['comment'],
                  textAlign:
                      isArabic(post['post']) ? TextAlign.right : TextAlign.left,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> postComment() async {
    if (editMode) {
      final body = <String, dynamic>{"comment": controller.text};

      try {
        final record =
            await pb.collection('circle_comments').update(editID, body: body);
        controller.text = "";
        editID = "";
        editMode = false;
        setState(() {});

        return;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("حدث خطاً ما، الرجاء المحاولة لاحقاً"),
        ));
      }
    }

    if (controller.text.trim().isEmpty) {
      return;
    }

    final body = <String, dynamic>{
      "post": widget.post['id'],
      "by": userID,
      "comment": controller.text,
    };

    try {
      final record = await pb.collection('circle_comments').create(body: body);
      var newComment = await createCommentCard(record, comments.length - 1);
      setState(() {
        controller.text = "";
        comments.add(newComment);
      });
    } catch (e) {}
  }

  String timeAgo(DateTime date) {
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} د';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} س';
    } else {
      return DateFormat('dd/MM/yyyy').format(date.toLocal());
    }
  }

  Future getPost() async {
    var post = widget.post;
    var posterRecord = await pb.collection('users').getOne(post['by']);
    Map userData = posterRecord.toJson();

    var avatarUrl = pb.getFileUrl(posterRecord, userData['avatar']).toString();
    var postTime = timeAgo(DateTime.parse(post['created']).toLocal());
    String by = '${userData['fname']} ${userData['lname']}';
    var posterAvatar = Image.network('$avatarUrl?token=${pb.authStore.token}');

    return createPostWidget(post, by, posterAvatar, postTime);
  }

  Widget createPostWidget(
      var post, String by, var posterAvatar, String postTime) {
    int ratio = post['likes'].length - post['dislikes'].length;
    List<String> imageUrls = [];

    if (post['pictures'].isNotEmpty) {
      var pictures = post['pictures'];
      RecordModel record = RecordModel.fromJson(post);
      for (var picture in pictures) {
        var url =
            '${pb.getFileUrl(record, picture)}?token=${pb.authStore.token}';
        imageUrls.add(url);
      }
    }
    return themedCard(
      Column(
        crossAxisAlignment: isArabic(post['post'])
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (post['by'] != userID) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ViewProfile(target: post['by']),
                  ),
                );
              }
            },
            child: Row(
              children: [
                Flexible(
                  child: ListTile(
                    leading: ClipOval(
                        child: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: posterAvatar,
                            radius: 25)),
                    title: Text(by, style: defaultText),
                    subtitle: Text(postTime,
                        textScaler: const TextScaler.linear(0.65)),
                  ),
                ),
              ],
            ),
          ),
          if (topic != '')
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10),
              child: Text(
                "#$topic",
                style: topicText,
                textDirection: isArabic(post['post'])
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              ),
            ),
          if (imageUrls.length == 1)
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
                          child: Image.network(imageUrls[0]),
                        ),
                      );
                    });
              },
              child: Center(
                child: Image.network(
                  imageUrls[0],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (imageUrls.length > 1)
            CarouselSlider(
              options: CarouselOptions(
                height: 400.0,
                pageSnapping: true,
              ),
              items: imageUrls.map((imageUrl) {
                return Builder(
                  builder: (BuildContext context) {
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                              child: InteractiveViewer(
                                child: Image.network(
                                  imageUrl,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5.0),
                        decoration:
                            const BoxDecoration(color: Colors.transparent),
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SelectableLinkify(
              onOpen: (link) async {
                await launchUrl(Uri.parse(link.url));
              },
              text: post['post'],
              textDirection: isArabic(post['post'])
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
          ),
          createPostActions(post, ratio),
        ],
      ),
    );
  }

  Widget createPostActions(var post, int ratio) {
    return StatefulBuilder(builder: (context, setState) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          createLikeDislikeButtons(post, setState),
        ],
      );
    });
  }

  Widget createLikeDislikeButtons(
      var post, void Function(void Function()) setState) {
    ValueNotifier<int> ratio =
        ValueNotifier<int>(post['likes'].length - post['dislikes'].length);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        createLikeButton(context, post, ratio),
        ValueListenableBuilder<int>(
          valueListenable: ratio,
          builder: (context, value, child) {
            return Text('$value');
          },
        ),
        createDislikeButton(context, post, ratio),
      ],
    );
  }

  Widget createLikeButton(
      BuildContext context, var post, ValueNotifier<int> likes) {
    bool isLiked = post['likes'].contains(pb.authStore.model.id);
    bool isDisliked = post['dislikes'].contains(pb.authStore.model.id);
    return IconButton(
      onPressed: () async {
        if (!isLiked) {
          post['likes'].add(pb.authStore.model.id);
          if (isDisliked) {
            post['dislikes'].remove(pb.authStore.model.id);
          }
        } else {
          post['likes'].remove(pb.authStore.model.id);
        }
        await updatePostLikesAndDislikes(post);
        likes.value = post['likes'].length;
        setState(() {});
      },
      icon:
          Icon(Icons.arrow_drop_up, color: isLiked ? greenColor : Colors.black),
    );
  }

  Widget createDislikeButton(
      BuildContext context, var post, ValueNotifier<int> dislikes) {
    bool isLiked = post['likes'].contains(pb.authStore.model.id);
    bool isDisliked = post['dislikes'].contains(pb.authStore.model.id);
    return IconButton(
      onPressed: () async {
        if (!isDisliked) {
          post['dislikes'].add(pb.authStore.model.id);
          if (isLiked) {
            post['likes'].remove(pb.authStore.model.id);
          }
        } else {
          post['dislikes'].remove(pb.authStore.model.id);
        }
        await updatePostLikesAndDislikes(post);
        dislikes.value = post['dislikes'].length;
        setState(() {});
      },
      icon: Icon(Icons.arrow_drop_down,
          color: isDisliked ? redColor : Colors.black),
    );
  }

  Future<void> updatePostLikesAndDislikes(var post) async {
    final body = <String, dynamic>{
      "likes": post['likes'],
      "dislikes": post['dislikes']
    };
    await pb.collection('circle_posts').update(post['id'], body: body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: true),
      bottomSheet: Container(
        padding: const EdgeInsets.all(10),
        color: Colors.white,
        child: Row(
          children: [
            Flexible(
              child: StatefulBuilder(builder: (context, setState) {
                return TextField(
                  onChanged: (value) {
                    setState(() {
                      textDirection = RegExp(r'[\u0600-\u06FF]').hasMatch(value)
                          ? TextDirection.rtl
                          : TextDirection.ltr;
                    });
                  },

                  keyboardType: TextInputType.multiline, // Add this line
                  maxLines: null, // Add this line

                  controller: controller,
                  decoration:
                      const InputDecoration(hintText: "إضافة تعليق جديد"),
                );
              }),
            ),
            IconButton(
              onPressed: postComment,
              icon: const Icon(Icons.send),
            )
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: SingleChildScrollView(
          child: SafeArea(
            bottom: true,
            child: Column(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      FutureBuilder(
                          future: getPost(),
                          builder: (ctx, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
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
                                return Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: data);
                              }
                            }
                            return shimmer;
                          }),
                      if (_isLoading) // Replace this line
                        shimmer, // Replace this line

                      Padding(
                          padding: const EdgeInsets.only(
                              bottom: 25, left: 10, right: 10),
                          child: Column(
                            children: comments,
                          )),
                      Padding(padding: EdgeInsets.all(50))
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReportAbuse extends StatefulWidget {
  final Map post;
  final bool mode;
  ReportAbuse({super.key, required this.post, required this.mode});

  @override
  State<ReportAbuse> createState() => _ReportAbuseState();
}

enum ReportReason { nudity, spam, fakeNews, occupation }

class _ReportAbuseState extends State<ReportAbuse> {
  bool isLoading = true;
  TextEditingController controller = TextEditingController();
  ReportReason? _reason = ReportReason.nudity;
  TextDirection textDirection = TextDirection.ltr;

  Future postConstructor() async {
    Widget postWidget = Placeholder();
    if (widget.mode) {
      postWidget = await getPost();
    } else {
      postWidget = await createCommentCard(widget.post);
    }

    return postWidget;
  }

  Future sendReport() async {
    final pb = PocketBase('https://ahrar.pockethost.io');
    String reason = (_reason.toString().split('.')[1]);
    var post = widget.post['id'];
    final body;
    if (widget.mode) {
      body = <String, dynamic>{
        "post": post,
        "report": controller.text,
        "field": reason
      };
    } else {
      body = <String, dynamic>{
        "comment": post,
        "report": controller.text,
        "field": reason
      };
    }

    try {
      final record = await pb.collection('reports').create(body: body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إستلام البلاغ وسيتم التعامل معه في أسرع وقت'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ ما، الرجاء المحاولة في وقت لاحق'),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  String timeAgo(DateTime date) {
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} د';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} س';
    } else {
      return DateFormat('dd/MM/yyyy').format(date.toLocal());
    }
  }

  Future<Widget> getPost() async {
    var post = widget.post;
    var posterRecord = await pb.collection('users').getOne(post['by']);
    Map userData = posterRecord.toJson();

    var avatarUrl = pb.getFileUrl(posterRecord, userData['avatar']).toString();
    var postTime = timeAgo(DateTime.parse(post['created']).toLocal());
    String by = '${userData['fname']} ${userData['lname']}';
    var posterAvatar = Image.network('$avatarUrl?token=${pb.authStore.token}');

    return createPostWidget(post, by, posterAvatar, postTime);
  }

  Widget createPostWidget(
      var post, String by, var posterAvatar, String postTime) {
    List<String> imageUrls = [];

    if (post['pictures'].isNotEmpty) {
      var pictures = post['pictures'];
      RecordModel record = RecordModel.fromJson(post);
      for (var picture in pictures) {
        var url =
            '${pb.getFileUrl(record, picture)}?token=${pb.authStore.token}';
        imageUrls.add(url);
      }
    }
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      child: Column(
        crossAxisAlignment: isArabic(post['post'])
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: ListTile(
                  leading: ClipOval(
                      child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: posterAvatar,
                          radius: 25)),
                  title: Text(by, style: defaultText),
                  subtitle:
                      Text(postTime, textScaler: const TextScaler.linear(0.65)),
                ),
              ),
            ],
          ),
          if (imageUrls.length == 1)
            Center(
              child: Image.network(
                imageUrls[0],
                fit: BoxFit.cover,
              ),
            ),
          if (imageUrls.length > 1)
            CarouselSlider(
              options: CarouselOptions(
                height: 400.0,
                pageSnapping: true,
              ),
              items: imageUrls.map((imageUrl) {
                return Builder(
                  builder: (BuildContext context) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                      decoration:
                          const BoxDecoration(color: Colors.transparent),
                      child: Image.network(imageUrl, fit: BoxFit.cover),
                    );
                  },
                );
              }).toList(),
            ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SelectableLinkify(
              onOpen: (link) async {
                await launchUrl(Uri.parse(link.url));
              },
              text: post['post'],
              textDirection: isArabic(post['post'])
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }

  Future<Widget> createCommentCard(post) async {
    var posterRecord = await pb.collection('users').getOne(post['by']);
    Map userData = posterRecord.toJson();

    String name = '${userData['fname']} ${userData['lname']}';
    var avatarUrl = pb.getFileUrl(posterRecord, userData['avatar']).toString();
    var postTime = timeAgo(DateTime.parse(post['created']).toLocal());

    Widget header = GestureDetector(
      onTap: () {
        if (post['by'] != userID) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => ViewProfile(target: post['by'])));
        }
      },
      child: Row(
        children: [
          Flexible(
            child: ListTile(
              leading: ClipOval(
                  child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 15,
                      child: Image.network(avatarUrl))),
              title: Text(name, style: defaultText),
              subtitle: Text(
                postTime,
                textScaler: const TextScaler.linear(0.65),
              ),
            ),
          ),
        ],
      ),
    );

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      child: Column(
        crossAxisAlignment: isArabic(post['post'])
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          header,
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: SelectableText(
                  post['comment'],
                  textAlign:
                      isArabic(post['post']) ? TextAlign.right : TextAlign.left,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'تبليغ  عن منشور',
          style: defaultText,
          textScaler: TextScaler.linear(0.75),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('المنشور:',
                        textDirection: TextDirection.rtl, style: defaultText),
                  ],
                ),
              ),
              FutureBuilder(
                future: postConstructor(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return shimmer;
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                          'An unexpected error occurred, please try again later'),
                    );
                  }
                  if (snapshot.hasData) {
                    var data = snapshot.data;
                    return data!;
                  } else {
                    return shimmer;
                  }
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('المشكلة:',
                        textDirection: TextDirection.rtl, style: defaultText)
                  ],
                ),
              ),
              StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      ListTile(
                        title: const Text(
                            'محتوى غير أخلاقي (يروج للإباحية أو المخدرات)'),
                        leading: Radio<ReportReason>(
                          value: ReportReason.nudity,
                          groupValue: _reason,
                          onChanged: (ReportReason? value) {
                            setState(() {
                              _reason = value;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('رسائل إلكترونية مزعجة (Spam)'),
                        leading: Radio<ReportReason>(
                          value: ReportReason.spam,
                          groupValue: _reason,
                          onChanged: (ReportReason? value) {
                            setState(() {
                              _reason = value;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('أخبار ملفقة'),
                        leading: Radio<ReportReason>(
                          value: ReportReason.fakeNews,
                          groupValue: _reason,
                          onChanged: (ReportReason? value) {
                            setState(() {
                              _reason = value;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('داعم للاحتلال'),
                        leading: Radio<ReportReason>(
                          value: ReportReason.occupation,
                          groupValue: _reason,
                          onChanged: (ReportReason? value) {
                            setState(() {
                              _reason = value;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 15.0),
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
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "هل ترغب بإضافة معلومات أخرى؟",
                    ),
                  );
                })),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: ButtonStyle(
                        foregroundColor: MaterialStatePropertyAll(blackColor),
                      ),
                      onPressed: () {
                        sendReport();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('إرسال'),
                          Padding(
                            padding: const EdgeInsets.only(left: 5.0),
                            child: Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
