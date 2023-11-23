import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pocketbase/pocketbase.dart';
import 'package:tahrir/Pages/circle.dart';
import 'package:tahrir/Pages/profiles.dart';
import 'package:tahrir/Pages/styles.dart';
import 'package:tahrir/user_data.dart';
import 'package:url_launcher/url_launcher.dart';

class TopicSelection extends StatefulWidget {
  const TopicSelection({super.key});

  @override
  State<TopicSelection> createState() => _TopicSelectionState();
}

class _TopicSelectionState extends State<TopicSelection> {
  var topics = [];
  var topicIDs = [];
  var topicLengths = [];
  var topicTimes = [];

  Future fetchTopics() async {
    topics.clear();
    topicIDs.clear();
    final records = await pb.collection('topics').getFullList(
          sort: '-updated',
        );
    for (var record in records) {
      var topic = record.toJson();
      topics.add(topic['topic']);
      topicIDs.add(topic['id']);
      topicLengths.add(topic['posts'].length);
      topicTimes.add(topic['updated']);
    }
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

  Future<Widget> renderTopics() async {
    List<Widget> topicCards = [];
    await fetchTopics();
    for (int i = 0; i < topics.length; i++) {
      var topic = topics[i];
      var editTime = DateTime.parse(topicTimes[i]).toLocal();
      var lastEdit = timeAgo(editTime);
      topicCards.add(
        Card(
          surfaceTintColor: Colors.white,
          color: Colors.white,
          child: ListTile(
              onTap: () {
                int index = topics.indexOf(topic);
                var id = topicIDs[index];
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => DiscoverTopics(topic: id)));
              },
              leading: Icon(Icons.tag),
              title: Text(topic, style: defaultText),
              subtitle:
                  Text('منشور ${topicLengths[i]} · أحدث منشور:  ${lastEdit}'),
              trailing: Icon(Icons.arrow_forward_ios)),
        ),
      );
    }
    return Column(children: topicCards);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إختر موضوع',
          style: defaultText,
          textScaler: TextScaler.linear(0.75),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: FutureBuilder(
            future: renderTopics(),
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
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class DiscoverTopics extends StatefulWidget {
  late String topic;
  DiscoverTopics({super.key, required this.topic});

  @override
  State<DiscoverTopics> createState() => _DiscoverTopicsState();
}

class _DiscoverTopicsState extends State<DiscoverTopics> {
  int _page = 1;
  List<Widget> _postsWidgets = [];
  bool _isLoading = false;
  late String newestID;
  Map postItem = {};
  List commentsItem = [];
  bool? isPublic;
  late String topic;
  String? filter = 'newest';
  String? timeRange;
  bool _isTopicLoaded = false; // Add this line

  void initState() {
    super.initState();
    fetchPosts();
  }

  void fetchPosts() async {
    var request = await pb.collection('topics').getOne(widget.topic);
    var response = request.toJson();
    topic = response['topic'];

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
        _isTopicLoaded = true; // Set the flag to true once the Future completes
      });
    }
  }

  Future getCirclePosts(
      {int limit = 10, int page = 1, isPublic, selectedTopicId}) async {
    String filter = '';

    final resultList = await pb.collection('circle_posts').getList(
          page: page,
          perPage: limit,
          filter: 'topic.id = "${widget.topic}"',
          sort: '-created',
        );

    return resultList.toJson();
  }

  Future<List<Widget>> renderPosts(
      {int limit = 7,
      int page = 1,
      bool isFiltering = false,
      bool? isPublic,
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
                                      setState(() {
                                        _postsWidgets.removeAt(index);
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
    if (!_isTopicLoaded) {
      return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: true,
          ),
          body: shimmer);
    }
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
                  var newPosts = await renderPosts(
                      limit: 7,
                      page: 1,
                      isPublic: isPublic,
                      topics: [],
                      isFiltering: false);
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
                              isPublic: isPublic, isFiltering: true);
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
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              topic,
              style: topicText,
              textDirection: TextDirection.rtl,
            ),
            Icon(Icons.tag, color: greenColor)
          ],
        ),
        centerTitle: true,
      ),
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
