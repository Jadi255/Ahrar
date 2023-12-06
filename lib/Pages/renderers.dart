import 'dart:async';
import 'package:animated_icon_button/animated_icon_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:qalam/styles.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:detectable_text_field/detectable_text_field.dart';
import 'fetchers.dart';
import '../user_data.dart';

class Renderer extends ChangeNotifier {
  final Fetcher _fetcher;
  final PocketBase pb;
  final StreamController<List<Widget>> _postsStreamController =
      StreamController.broadcast();

  Renderer({required Fetcher fetcher, required this.pb}) : _fetcher = fetcher;

  Stream<List<Widget>> get postsStream => _postsStreamController.stream;
  void dispose() {
    super.dispose();
    _postsStreamController.close();
  }

  void renderPosts(
      BuildContext context, User user, int page, int perPage, mode) async {
    var postsData;
    String fullName = user.fullName;
    String id = user.id;
    ImageProvider avatar = user.avatar!;
    final pb = user.pb;
    try {
      switch (mode) {
        case 'myPosts':
          fullName = user.fullName;
          id = user.id;
          avatar = user.avatar!;
          postsData =
              await _fetcher.getUserPosts(context, id, pb, page, perPage);
        case 'publicAll':
          postsData = await _fetcher.getPublicPosts(context, pb, page, perPage);
        default:
          fullName = "";
          avatar = CachedNetworkImageProvider('/assets/placeholder.jpg');
      }
      List<Widget> postWidgets = [];
      for (var postData in postsData) {
        if (mode != 'myPosts') {
          var getUserRecord =
              await pb.collection('users').getOne(postData['by']);
          var userMap = getUserRecord.toJson();
          fullName = userMap['full_name'];
          var avatarUrl =
              pb.getFileUrl(getUserRecord, userMap['avatar']).toString();
          avatar = CachedNetworkImageProvider(avatarUrl);
        }
        Widget postWidget =
            await createPostWidget(postData, fullName, avatar, context);
        postWidgets.add(postWidget);
      }
      _postsStreamController.add(postWidgets);
    } catch (e) {
      print(e);
      _postsStreamController.addError(e);
    }
  }

  String timeAgo(DateTime date) {
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} د';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} س';
    } else {
      return intl.DateFormat('dd/MM/yyyy').format(date.toLocal());
    }
  }

  Future<Widget> createPostWidget(Map<String, dynamic> post, String fullName,
      ImageProvider avatar, BuildContext context) async {
    final user = Provider.of<User>(context, listen: false);
    List<Widget> images = [];
    List topicStrings = [];
    for (var topic in post['topic']) {
      var getTopic = await _fetcher.fetchTopic(topic);
      topicStrings.add(getTopic);
    }

    Widget imageView = Container();
    var postTime = timeAgo(DateTime.parse(post['created']).toLocal());
    if (post['pictures'].isNotEmpty) {
      var pictures = post['pictures'];
      RecordModel record = RecordModel.fromJson(post);
      for (var picture in pictures) {
        var url =
            '${pb.getFileUrl(record, picture)}?token=${pb.authStore.token}';
        images.add(Container(
          margin: const EdgeInsets.symmetric(horizontal: 5.0),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: Center(
                child: GestureDetector(
              onTap: () {
                showDialog(
                    barrierDismissible: true,
                    context: context,
                    builder: (context) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: InteractiveViewer(
                            child: Image(
                          image: CachedNetworkImageProvider(url),
                        )),
                      );
                    });
              },
              child: Image(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.fitWidth,
                height: 250,
                width: double.infinity,
              ),
            )),
          ),
        ));
      }
      if (images.length > 1) {
        imageView = CarouselSlider(
            options: CarouselOptions(
              height: 250,
              pageSnapping: true,
            ),
            items: images);
      } else if (images.length == 1) {
        imageView = images[0];
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
                    leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage: avatar,
                        radius: 25),
                    title: Text(fullName, style: defaultText),
                    subtitle: Row(
                      children: [
                        Transform.scale(
                          scale: 0.75,
                          child: Icon(
                              post['is_public'] ? Icons.public : Icons.people),
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
                if (post['by'] == user.id)
                  PopupMenuButton<String>(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    onSelected: (String result) async {
                      if (result == 'Edit') {
                        //TODO
                      } else if (result == "Delete") {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              actionsAlignment: MainAxisAlignment.spaceBetween,
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.white,
                              content: Text('هل أنت متأكد؟',
                                  style: defaultText,
                                  textAlign: TextAlign.center),
                              actions: [
                                IconButton(
                                  onPressed: () async {
                                    //TODO
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
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        onTap: () {
                          updatePost(post);
                        },
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
                if (post['by'] != user.id)
                  PopupMenuButton<String>(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    onSelected: (String result) async {
                      /**
                      //TODO
                        showDialog(
                          context: context,
                          builder: (context) {
                            return ReportAbuse(post: post, mode: false);
                          });
                       */
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) {
                              return Placeholder();
                            },
                          ),
                        );
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
            if (images.isNotEmpty) imageView,
            StatefulBuilder(
              builder: ((context, setState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: DetectableText(
                        detectedStyle: topicText,
                        delimiter: isArabic(post['post']) ? '...  ' : '  ...',
                        onTap: (tapped) async {
                          if (urlRegex.hasMatch(tapped)) {
                            await launchUrl(Uri.parse(tapped));
                          }
                          if (atSignRegExp.hasMatch(tapped)) {
                            print('user: $tapped');
                          }
                          if (hashTagRegExp.hasMatch(tapped)) {
                            print('topic: $tapped');
                          }
                        },
                        trimExpandedText: "تصغير",
                        trimCollapsedText: "المزيد",
                        moreStyle: defaultText,
                        lessStyle: defaultText,
                        trimLines: 5,
                        trimMode: TrimMode.Line,
                        text: "${post['post']}\n",
                        textDirection: isArabic(post['post'])
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        detectionRegExp: detectionRegExp(
                            hashtag: true, url: true, atSign: true)!,
                      ),
                    ),
                  ],
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: createPostActions(post, context),
            )
          ],
        ),
      ),
    );
  }

  Widget createPostActions(post, context) {
    final user = Provider.of<User>(context, listen: false);

    String ratio = (post['likes'].length - post['dislikes'].length).toString();
    int comments = post['comments'].length;
    Color likeBtnColor =
        post['likes'].contains(user.id) ? greenColor : Colors.grey.shade800;
    Color dislikeBtnColor =
        post['dislikes'].contains(user.id) ? redColor : Colors.grey.shade800;
    return StatefulBuilder(
      builder: ((context, setState) {
        return Column(
          children: [
            Container(
              height: 0.25,
              color: Colors.grey.shade900,
              margin: EdgeInsets.symmetric(horizontal: 10),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Transform.scale(
                    scale: 0.85,
                    child: TextButton(
                      style: ButtonStyle(
                          foregroundColor:
                              MaterialStatePropertyAll(Colors.black),
                          shadowColor: MaterialStatePropertyAll(Colors.white),
                          overlayColor: MaterialStatePropertyAll(Colors.white)),
                      onPressed: () async {
                        showModalBottomSheet(
                            enableDrag: false,
                            backgroundColor: Colors.transparent,
                            context: context,
                            builder: (context) {
                              return ShowComments(
                                  post: post,
                                  fetcher: _fetcher,
                                  comments: comments);
                            });
                      },
                      child: Row(
                        children: [
                          Icon(Icons.messenger_rounded),
                          Padding(
                            padding: const EdgeInsets.only(left: 5.0),
                            child: Text(comments.toString()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Transform.scale(
                        scale: 0.85,
                        child: AnimatedIconButton(
                          hoverColor: Colors.white,
                          focusColor: Colors.white,
                          highlightColor: Colors.white,
                          onPressed: () {
                            setState(() {
                              if (post['likes'].contains(user.id)) {
                                post['likes'].remove(user.id);
                                likeBtnColor = blackColor;
                              } else if (!post['likes'].contains(user.id)) {
                                post['likes'].add(user.id);
                                likeBtnColor = greenColor;
                              }
                              ratio = (post['likes'].length -
                                      post['dislikes'].length)
                                  .toString();
                            });
                          },
                          icons: [
                            AnimatedIconItem(
                              icon: Icon(Icons.thumb_up, color: likeBtnColor),
                              onPressed: () {},
                            ),
                            AnimatedIconItem(
                              icon: Icon(Icons.thumb_up, color: likeBtnColor),
                            ),
                          ],
                        ),
                      ),
                      Text(ratio),
                      Transform.scale(
                        scale: 0.85,
                        child: AnimatedIconButton(
                          hoverColor: Colors.white,
                          focusColor: Colors.white,
                          highlightColor: Colors.white,
                          onPressed: () {
                            setState(() {
                              if (post['dislikes'].contains(user.id)) {
                                post['dislikes'].remove(user.id);
                                dislikeBtnColor = blackColor;
                              } else if (!post['dislikes'].contains(user.id)) {
                                post['dislikes'].add(user.id);
                                dislikeBtnColor = redColor;
                              }
                              ratio = (post['likes'].length -
                                      post['dislikes'].length)
                                  .toString();
                            });
                          },
                          icons: [
                            AnimatedIconItem(
                              icon: Icon(Icons.thumb_down,
                                  color: dislikeBtnColor),
                            ),
                            AnimatedIconItem(
                              icon: Icon(Icons.thumb_down,
                                  color: dislikeBtnColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Stream renderComments(comments, context) async* {
    final fetcher = Fetcher(pb: pb);
    if (comments.isEmpty) {
      yield Center(child: Text('لا يوجد تعليقات', style: defaultText));
      return;
    }
    for (int i = 0; i < comments.length; i++) {
      var comment = comments[i];
      print(comment);
      var commentRecord = await fetcher.fetchComments(comment);

      yield await createCommentCard(commentRecord, i, context);
    }
  }

  Future<Widget> createCommentCard(
      var record, int index, BuildContext context) async {
    final user = Provider.of<User>(context, listen: false);

    var post = record.toJson();
    print(record);
    var posterRecord = await pb.collection('users').getOne(post['by']);
    Map userData = posterRecord.toJson();
    String name = '${userData['fname']} ${userData['lname']}';
    var avatarUrl = pb.getFileUrl(posterRecord, userData['avatar']).toString();
    var avatar = CachedNetworkImageProvider(avatarUrl);
    var postTime = timeAgo(DateTime.parse(post['created']).toLocal());
    Widget header = GestureDetector(
      onTap: () {
        if (post['by'] != user.id) {}
      },
      child: Row(
        children: [
          Flexible(
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: avatar,
                  radius: 25),
              title: Text(name, style: defaultText),
              subtitle: Text(
                postTime,
                textScaler: const TextScaler.linear(0.65),
              ),
            ),
          ),
          if (post['by'] == user.id)
            PopupMenuButton<String>(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              onSelected: (String result) async {
                if (result == 'Edit') {
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
                            onPressed: () async {},
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
                PopupMenuItem<String>(
                  value: 'Edit',
                  onTap: () {
                    updateComment(post);
                  },
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
          if (post['by'] != user.id)
            PopupMenuButton<String>(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              onSelected: (String result) async {
                showDialog(
                    context: context,
                    builder: (context) {
                      return //ReportAbuse(post: post, mode: false);
                          Placeholder();
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
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 1,
      child: Column(
        crossAxisAlignment: isArabic(post['comment'])
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Directionality(
              textDirection: isArabic(post['comment'])
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: SelectableText(post['comment']),
            ),
          ),
        ],
      ),
    );
  }

  void updatePost(post) {}

  void newComment() {}

  void updateComment(comment) {
    print(comment);
  }
}

class ShowComments extends StatefulWidget {
  final post;
  final fetcher;
  final comments;
  const ShowComments(
      {super.key,
      required this.post,
      required this.fetcher,
      required this.comments});

  @override
  State<ShowComments> createState() => _ShowCommentsState();
}

class _ShowCommentsState extends State<ShowComments> {
  late final Renderer renderer;
  List<Widget> children = [];
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<User>(context, listen: false);
    renderer = Renderer(fetcher: widget.fetcher, pb: user.pb);
  }

  var controller = DetectableTextEditingController(
      regExp: detectionRegExp(atSign: false),
      detectedStyle: TextStyle(
        color: greenColor,
      ));
  TextDirection textDirection = TextDirection.ltr;

  Stream<PopupMenuEntry> atSuggestionBuilder(value) async* {
    var suggestions = await widget.fetcher.atSignHelper(value);
    for (var item in suggestions) {
      var suggestedUser = item.toJson();
      yield PopupMenuItem(
        onTap: () {
          var currentText = controller.text.split('@');
          var tag = suggestedUser['full_name'].split(' ').join('_');
          var tagString = '@' + tag;
          print(currentText[1] = tagString);
          controller.text = currentText.join(' ');
          Navigator.of(context).pop();
        },
        child: Text(suggestedUser['full_name']),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_downward),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )),
      bottomSheet: Card(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        child: pagePadding(
          Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(builder: ((context, setState) {
              return Row(
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () {},
                    ),
                  ),
                  Expanded(
                    child: DetectableTextField(
                      enableSuggestions: true,
                      enableInteractiveSelection: true,
                      maxLines: null,
                      textDirection: textDirection,
                      onChanged: (value) async {
                        if (controller.text == '') {
                          return;
                        } else {
                          setState(
                            () {
                              textDirection =
                                  isArabic(controller.text.split('')[0])
                                      ? TextDirection.rtl
                                      : TextDirection.ltr;
                            },
                          );
                        }
                        if (hashTagRegExp.hasMatch(value)) {
                          print('topic: $value');
                        }
                      },
                      controller: controller,
                      decoration: InputDecoration(
                        label: Text('اضف تعليق'),
                        labelStyle: TextStyle(
                          color: Colors.black, // Set your desired color
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(30), // Circular/Oval border
                        ),
                      ),
                    ),
                  ),
                ],
              );
            })),
          ),
        ),
      ),
      body: SingleChildScrollView(
          child: pagePadding(
        StreamBuilder(
          stream: renderer.renderComments(widget.post['comments'], context),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CupertinoActivityIndicator()); // or your custom loader
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              children.add(snapshot.data!);
              return Column(
                children: [
                  Column(
                    children: children,
                  ),
                  if (children.length != widget.comments && widget.comments > 0)
                    Center(child: CupertinoActivityIndicator()),
                  Padding(
                    padding: EdgeInsets.only(bottom: 100),
                  )
                ],
              );
            }
          },
        ),
      )),
    );
    ;
  }
}
