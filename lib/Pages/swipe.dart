import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pocketbase/pocketbase.dart';
import 'package:tahrir/Pages/profiles.dart';
import 'package:tahrir/Pages/styles.dart';
import 'package:tahrir/user_data.dart';
import 'package:url_launcher/url_launcher.dart';

class SwipeCards extends StatefulWidget {
  const SwipeCards({Key? key}) : super(key: key);

  @override
  _SwipeCardsState createState() => _SwipeCardsState();
}

class _SwipeCardsState extends State<SwipeCards> {
  List<Widget> _postWidgets = [];
  bool _allCardsSwiped = false;

  int _page = 1;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<String> getTopic(id) async {
    var request = await pb.collection('topics').getOne(id);
    var response = request.toJson();

    return response['topic'];
  }

  Future<void> _fetchPosts() async {
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    String formattedDate =
        DateFormat('yyyy-MM-dd 00:00:00').format(startOfWeek);

    final resultList = await pb.collection('circle_posts').getFullList(
          filter: 'is_public = true && created >= "$formattedDate"',
        );
    resultList.shuffle();
    var items = resultList.take(resultList.length).toList();

    // Render the fetched posts and update _postWidgets
    for (var post in items) {
      _postWidgets.add(await _renderPost(post));
    }

    List<Widget> newPosts = [];
    for (var post in items) {
      newPosts.add(await _renderPost(post));
    }
    _page++; // Increment _page by 1
    _postWidgets.addAll(newPosts);

    setState(() {});
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

  Future<Widget> _renderPost(RecordModel item) async {
    List<String> imageUrls = [];
    String topic;
    var postMap = item.toJson();
    var postTopic = postMap['topic'];
    if (postTopic.isEmpty) {
      topic = '';
    } else {
      topic = await getTopic(postTopic[0]);
    }

    // Get the user who posted
    var post = item.toJson();
    var posterRecord = await pb.collection('users').getOne(post['by']);
    Map userData = posterRecord.toJson();
    // Get the user's avatar
    var avatarUrl = pb.getFileUrl(posterRecord, userData['avatar']).toString();
    var posterAvatar;
    try {
      posterAvatar = Image.network('$avatarUrl?token=${pb.authStore.token}');
    } catch (e) {
      posterAvatar = Image.network(
          'https://png.pngtree.com/png-clipart/20210915/ourmid/pngtree-user-avatar-placeholder-png-image_3918418.jpg');
    }

    // Format the post time
    var postTime = timeAgo(DateTime.parse(post['created']).toLocal());

    // Get the user's name
    String by = '${userData['fname']} ${userData['lname']}';

    // Create the post widget
    if (post['pictures'].isNotEmpty) {
      var pictures = post['pictures'];
      RecordModel record = RecordModel.fromJson(post);
      for (var picture in pictures) {
        var url =
            '${pb.getFileUrl(record, picture)}?token=${pb.authStore.token}';
        imageUrls.add(url);
      }
    }
    Widget postWidget = themedCard(
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
                          child: GestureDetector(
                            onLongPress: () async {
                              await launchUrl(Uri.parse(imageUrls[0]));
                            },
                            child: Image.network(imageUrls[0]),
                          ),
                        ),
                      );
                    });
                setState(() {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('إضغط ضغطة طويلة على الصورة لحفظها')));
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: Center(
                  child: Image.network(
                    height: 350,
                    width: double.infinity,
                    imageUrls[0],
                    fit: BoxFit.fitWidth,
                  ),
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
                return FutureBuilder(
                  future: Future.delayed(Duration(milliseconds: 500), () async {
                    return GestureDetector(
                      onLongPress: () async {
                        await launchUrl(Uri.parse(imageUrl));
                      },
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                              child: InteractiveViewer(
                                child: Image.network(imageUrl),
                              ),
                            );
                          },
                        );
                        setState(() {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text('إضغط ضغطة طويلة على الصورة لحفظها')));
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5.0),
                        decoration:
                            const BoxDecoration(color: Colors.transparent),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(0),
                          child: Center(
                            child: Image.network(
                              height: 350,
                              width: double.infinity,
                              imageUrl,
                              fit: BoxFit.fitWidth,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CupertinoActivityIndicator()); // or your custom loader
                    } else if (snapshot.hasError) {
                      return Text(
                          'حدث خطأ نتيجة ضغط المستخدمين، الرجاء إعادة المحاولة');
                    } else {
                      return snapshot.data!;
                    }
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

    topic = '';

    return postWidget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'إكتشف منشورات',
          style: defaultText,
          textScaler: TextScaler.linear(0.8),
        ),
      ),
      floatingActionButton: _allCardsSwiped
          ? FloatingActionButton(
              backgroundColor: blackColor,
              foregroundColor: Colors.white,
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
                await _fetchPosts();
                setState(() {
                  _allCardsSwiped = false;
                });
                Navigator.of(context).pop();
              },
              child: Text('المزيد', style: defaultText),
            )
          : null,
      body: _postWidgets.isEmpty
          ? Column(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                        'لا تزال هذه الخاصية قيد الإنشاء، نعتذر لوجود أخطاء'),
                  ),
                ),
                shimmer,
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: CardSwiper(
                key: ValueKey(_postWidgets.length), // Add this line
                isLoop: false,
                cardsCount: _postWidgets.length,
                cardBuilder:
                    (context, index, percentThresholdX, percentThresholdY) {
                  if (index == _postWidgets.length - 1) {
                    Future.delayed(Duration.zero, () {
                      setState(() {
                        _allCardsSwiped = true;
                      });
                    });
                  }
                  return Container(child: _postWidgets[index]);
                },
              ),
            ),
    );
  }
}
