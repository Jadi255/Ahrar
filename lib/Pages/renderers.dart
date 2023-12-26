import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:animated_icon_button/animated_icon_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/my_profile.dart';
import 'package:qalam/Pages/topics.dart';
import 'package:qalam/Pages/users_profiles.dart';
import 'package:qalam/Pages/writers.dart';
import 'package:qalam/styles.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:detectable_text_field/detectable_text_field.dart';
import 'package:youtube_player_iframe_plus/youtube_player_iframe_plus.dart';
import 'fetchers.dart';
import '../user_data.dart';

class Renderer extends ChangeNotifier {
  final Fetcher _fetcher;
  final PocketBase pb;
  final StreamController<List<Widget>> _postsStreamController =
      StreamController.broadcast();

  final StreamController<List<Widget>> _commentsStreamController =
      StreamController.broadcast();

  final StreamController<List<Widget>> _notificationsStreamController =
      StreamController.broadcast();

  List postIDs = [];
  List<Widget> postWidgets = [];
  List commentIDs = [];
  List<Widget> commentWidgets = [];
  List<Widget> notificationWidgets = [];
  List<String> notificationIDs = [];
  Renderer({required Fetcher fetcher, required this.pb}) : _fetcher = fetcher;

  Stream<List<Widget>> get postsStream => _postsStreamController.stream;
  Stream<List<Widget>> get commentsStream => _commentsStreamController.stream;
  Stream<List<Widget>> get notificationsStream =>
      _notificationsStreamController.stream;

  void dispose() {
    super.dispose();
    _postsStreamController.close();
    _commentsStreamController.close();
    _notificationsStreamController.close();
  }

  void renderPosts(BuildContext context, User user, int page, int perPage, mode,
      target, refresh) async {
    if (refresh) {
      postWidgets.clear();
      postIDs.clear();
    }
    var postsData;
    String fullName = user.fullName;
    String id = user.id;
    ImageProvider avatar = user.avatar!;
    final pb = user.pb;
    try {
      switch (mode) {
        case 'filter':
          postsData = await _fetcher.getFilteredPosts(
              context, pb, page, perPage, target);
          break;
        case 'topic':
          postsData = await _fetcher.getTopicPosts(target, page, perPage);
          break;
        case 'userPosts':
          postsData =
              await _fetcher.getUserPosts(context, target, pb, page, perPage);
          break;
        case 'profilePosts':
          postsData = await _fetcher.getProfilePosts(target, page, perPage);
          break;
        case 'friends':
          postsData =
              await _fetcher.getFriendsPosts(context, pb, page, perPage);
          break;
        case 'myPosts':
          fullName = user.fullName;
          id = user.id;
          avatar = user.avatar!;
          postsData =
              await _fetcher.getUserPosts(context, id, pb, page, perPage);
          break;
        case 'publicAll':
          postsData = await _fetcher.getPublicPosts(context, pb, page, perPage);
          break;
      }

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
        if (mode == 'filter') {
          postsData.sort((a, b) {
            int ratioA = a['likes'].length - a['dislikes'].length;
            int ratioB = b['likes'].length - b['dislikes'].length;
            return ratioB.compareTo(ratioA);
          });
        }
        Widget postWidget =
            await createPostWidget(postData, fullName, avatar, user);
        postWidgets.add(postWidget);
      }
      _postsStreamController.add(postWidgets);
      _fetcher.postSubscriber(context);
    } catch (e) {
      final Connectivity connectivity = Connectivity();
      final status = await connectivity.checkConnectivity();
      if (status == ConnectivityResult.none) {
        _postsStreamController.add([
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.black,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('أنت غير متصل بالإنترنت', style: defaultText),
              ),
            ],
          ),
        ]);
      } else {
        _postsStreamController.add([
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error,
                color: Colors.black,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  'نعتذر، حدث خطأ ما\nالرجاء المحاولة في وقت لاحق',
                  style: defaultText,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ]);
      }
      throw e;
    }
  }

  void updateSubscriber(event, record, context) async {
    var post = record.toJson();
    final user = Provider.of<User>(context, listen: false);
    switch (event) {
      case 'create':
        if (post['by'] == user.id && !postIDs.contains(post['id'])) {
          final newPost =
              await createPostWidget(post, user.fullName, user.avatar!, user);

          List<Widget> newPosts = [newPost];
          List newPostIDs = [post['id']];
          for (var existingPost in postWidgets) {
            var index = postWidgets.indexOf(existingPost);
            newPosts.add(existingPost);
            newPostIDs.add(postIDs[index]);
          }

          postWidgets.clear();
          postIDs.clear();

          postIDs = newPostIDs.toSet().toList();
          postWidgets = newPosts.toSet().toList();

          _postsStreamController.add(postWidgets);
          notifyListeners();
          break;
        }
      //TODO FIX HERE
      case 'update':
        var post = record.toJson();
        final posterRecord = await _fetcher.getUser(post['by']);
        final poster = posterRecord.toJson();
        var avatarUrl =
            pb.getFileUrl(posterRecord, poster['avatar']).toString();
        try {
          int index = postIDs.indexOf(post['id']);
          final newPost = await createPostWidget(post, poster['full_name'],
              CachedNetworkImageProvider(avatarUrl), user);
          postWidgets[index] = newPost;
          _postsStreamController.add(postWidgets);
          notifyListeners();
        } catch (e) {
          print('e');
        }
        break;
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
      ImageProvider avatar, User user) async {
    postIDs.add(post['id']);
    List<Widget> images = [];
    late YoutubePlayerController videoController;
    var id;
    if (post['linked_video'] != '') {
      List splitURL = post['linked_video'].split('/');
      if (splitURL.contains('shorts')) {
        id = (splitURL.last.split('?')[0]);
      } else {
        id = YoutubePlayerController.convertUrlToId(post['linked_video']);
      }
      videoController = YoutubePlayerController(
        initialVideoId: '$id',
        params: YoutubePlayerParams(
          autoPlay: false,
          showControls: true,
          showFullscreenButton: true,
        ),
      );
    }

    Widget imageView = Container();
    var postTime = timeAgo(DateTime.parse(post['created']).toLocal());
    if (post['pictures'].isNotEmpty) {
      var pictures = post['pictures'];
      var placeholder = await jsonEncode(post);
      var item = await jsonDecode(placeholder);
      RecordModel record = RecordModel.fromJson(item);
      for (var picture in pictures) {
        if (post['linked_video'] != '') {
          images.add(
            YoutubePlayerIFramePlus(
              controller: videoController,
              aspectRatio: 16 / 9,
            ),
          );
        }
        var url =
            '${pb.getFileUrl(record, picture)}?token=${pb.authStore.token}';
        images.add(Builder(builder: (context) {
          return Container(
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
          );
        }));
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

    return Consumer<Renderer>(builder: (context, renderer, child) {
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
                    child: GestureDetector(
                      onTap: () {
                        if (fullName != user.fullName) {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      UserProfile(
                                          id: post['by'],
                                          fullName: fullName,
                                          avatar: avatar),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                var begin = Offset(1.0, 0.0);
                                var end = Offset.zero;
                                var curve = Curves.ease;

                                var tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));

                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: child,
                                );
                              },
                            ),
                          );
                        } else if (fullName == user.fullName) {
                          Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        MyProfile(isLeading: true),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  var begin = Offset(1.0, 0.0);
                                  var end = Offset.zero;
                                  var curve = Curves.ease;

                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));

                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                              ));
                        }
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade100,
                            foregroundImage: avatar,
                            backgroundImage:
                                Image.asset('assets/placeholder.jpg').image,
                            radius: 25),
                        title: Text(fullName, style: defaultText),
                        subtitle: Row(
                          children: [
                            Transform.scale(
                              scale: 0.75,
                              child: Icon(post['is_public']
                                  ? Icons.public
                                  : Icons.people),
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
                  ),
                  if (post['by'] == user.id)
                    PopupMenuButton<String>(
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      onSelected: (String result) async {
                        if (result == 'Edit') {
                          //TODO
                        } else if (result == "Delete") {
                          deletePost(post, context);
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          onTap: () {
                            updatePost(post, context);
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
                              return ReportAbuse(
                                  mode: 'post',
                                  text: post['post'],
                                  id: post['id'],
                                  poster: ListTile(
                                    leading: CircleAvatar(
                                        backgroundColor: Colors.grey.shade100,
                                        foregroundImage: avatar,
                                        backgroundImage: Image.asset(
                                                'assets/placeholder.jpg')
                                            .image,
                                        radius: 25),
                                    title: Text(fullName, style: defaultText),
                                    subtitle: Row(
                                      children: [
                                        Transform.scale(
                                          scale: 0.75,
                                          child: Icon(post['is_public']
                                              ? Icons.public
                                              : Icons.people),
                                        ),
                                        Transform.scale(
                                          scale: 0.75,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                left: 3.0),
                                            child: Text(postTime),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ));
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
              if (post['linked_video'] != '' && images.isEmpty)
                YoutubePlayerIFramePlus(
                  controller: videoController,
                  aspectRatio: 16 / 9,
                ),
              if (images.isNotEmpty) imageView,
              GestureDetector(
                onLongPress: () async {
                  await Clipboard.setData(ClipboardData(text: post['post']));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('تم نسخ النص')));
                },
                child: StatefulBuilder(
                  builder: ((context, setState) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: DetectableText(
                            detectedStyle: topicText,
                            delimiter:
                                isArabic(post['post']) ? '...  ' : '  ...',
                            onTap: (tapped) async {
                              if (urlRegex.hasMatch(tapped)) {
                                try {
                                  await launchUrl(Uri.parse(tapped));
                                } catch (e) {
                                  await launchUrl(Uri.parse("https://$tapped"));
                                }
                              }
                              if (hashTagRegExp.hasMatch(tapped)) {
                                var topic = tapped.split('#')[1];
                                int index = topics.indexOf(topic);
                                String id = topicIDs[index];
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation,
                                            secondaryAnimation) =>
                                        ChangeNotifierProvider(
                                      create: (context) => Renderer(
                                          fetcher: Fetcher(pb: user.pb),
                                          pb: user.pb),
                                      child: Discover(
                                          user: user, id: id, topic: tapped),
                                    ),
                                    transitionsBuilder: (context, animation,
                                        secondaryAnimation, child) {
                                      var begin = Offset(1.0, 0.0);
                                      var end = Offset.zero;
                                      var curve = Curves.ease;

                                      var tween = Tween(begin: begin, end: end)
                                          .chain(CurveTween(curve: curve));

                                      return SlideTransition(
                                        position: animation.drive(tween),
                                        child: child,
                                      );
                                    },
                                  ),
                                );
                              }
                            },
                            trimExpandedText: "تصغير",
                            trimCollapsedText: "المزيد",
                            moreStyle: defaultText,
                            lessStyle: defaultText,
                            trimLines: 4,
                            trimMode: TrimMode.Line,
                            text: "${post['post']}\n",
                            textDirection: isArabic(post['post'])
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            detectionRegExp: detectionRegExp(
                                hashtag: true, url: true, atSign: false)!,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: createPostActions(post, context),
              )
            ],
          ),
        ),
      );
    });
  }

  Widget createPostActions(post, context) {
    final user = Provider.of<User>(context, listen: false);
    final writer = Writer(pb: pb);

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
                              return ChangeNotifierProvider<Renderer>(
                                create: (context) => Renderer(
                                    fetcher: Fetcher(pb: user.pb), pb: user.pb),
                                child: ShowComments(
                                  post: post,
                                  fetcher: _fetcher,
                                  comments: comments,
                                ),
                              );
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
                          onPressed: () async {
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
                            await writer.likePost(post['id'], post['likes']);
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
                          onPressed: () async {
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
                            await writer.dislikePost(
                                post['id'], post['dislikes']);
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

  Future renderComments(comments, context,
      StreamController<List<Widget>> commentsStreamController) async {
    final fetcher = Fetcher(pb: pb);
    if (comments.isEmpty) {
      commentWidgets = [
        Center(child: Text('لا يوجد تعليقات', style: defaultText))
      ];
      commentsStreamController.add(commentWidgets);
      return;
    }
    for (int i = 0; i < comments.length; i++) {
      var comment = comments[i];
      commentIDs.add(comment);
      var commentRecord = await fetcher.fetchComments(comment);

      var commentCard = await createCommentCard(commentRecord, context);
      commentWidgets.add(commentCard);
    }
    commentsStreamController.add(commentWidgets);
    notifyListeners();
  }

  Future<Widget> createCommentCard(var record, BuildContext context) async {
    final user = Provider.of<User>(context, listen: false);
    var post;
    if (record.runtimeType == RecordModel) {
      post = record.toJson();
    } else {
      post = record;
    }
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
                  foregroundImage: avatar,
                  backgroundImage: Image.asset('assets/placeholder.jpg').image,
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
                            onPressed: () async {
                              //MUST FIX HERE
                              Writer writer = Writer(pb: pb);
                              int index = commentIDs.indexOf(post['id']);
                              String id = commentIDs[index];
                              await writer.deleteComment(id, context);
                              commentIDs.removeAt(index);
                              commentWidgets.removeAt(index);
                              _commentsStreamController.add(commentWidgets);

                              notifyListeners();

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
                PopupMenuItem<String>(
                  value: 'Edit',
                  onTap: () {
                    updateComment(post, context);
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
                      return ReportAbuse(
                          mode: 'comment',
                          text: post['comment'],
                          id: post['id'],
                          poster: ListTile(
                            leading: CircleAvatar(
                                backgroundColor: Colors.grey.shade100,
                                foregroundImage: avatar,
                                backgroundImage:
                                    Image.asset('assets/placeholder.jpg').image,
                                radius: 25),
                            title: Text(name, style: defaultText),
                            subtitle: Text(
                              postTime,
                              textScaler: const TextScaler.linear(0.65),
                            ),
                          ));
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

    return Consumer<Renderer>(
      builder: (context, renderer, child) {
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
      },
    );
  }

  void deletePost(post, context) {
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
              TextButton(
                style: ButtonStyle(
                    foregroundColor: MaterialStatePropertyAll(greenColor)),
                onPressed: () async {
                  Writer writer = Writer(pb: pb);
                  int index = postIDs.indexOf(post['id']);
                  String id = postIDs[index];
                  await writer.deletePost(id, context);
                  postIDs.removeAt(index);
                  postWidgets.removeAt(index);
                  _postsStreamController.add(postWidgets);
                  notifyListeners();
                  Navigator.of(context).pop();
                },
                child: Text('متابعة',
                    style: GoogleFonts.notoSansArabic(
                        fontWeight: FontWeight.w500)),
              ),
              TextButton(
                style: ButtonStyle(
                    foregroundColor: MaterialStatePropertyAll(redColor)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('إلغاء',
                    style: GoogleFonts.notoSansArabic(
                        fontWeight: FontWeight.w500)),
              )
            ],
          );
        });
  }

  void updatePost(post, context) async {
    final user = Provider.of<User>(context, listen: false);
    var controller = DetectableTextEditingController(
        regExp: detectionRegExp(atSign: false),
        detectedStyle: TextStyle(
          color: greenColor,
        ));
    controller.text = post['post'];
    TextDirection textDirection = isArabic(controller.text.split('')[0])
        ? TextDirection.rtl
        : TextDirection.ltr;
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return Dialog(
              surfaceTintColor: Colors.white,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      children: [
                        StatefulBuilder(
                          builder: (context, setState) {
                            return DetectableTextField(
                              enableInteractiveSelection: true,
                              maxLines: 10,
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
                                label: Text('تعديل تعليق'),
                                labelStyle: TextStyle(
                                  color: Colors.black, // Set your desired color
                                ),
                                contentPadding: EdgeInsets.all(25),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      30), // Circular/Oval border
                                ),
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Row(
                            children: [
                              TextButton(
                                style: ButtonStyle(
                                    foregroundColor:
                                        MaterialStatePropertyAll(greenColor)),
                                onPressed: () async {
                                  Writer writer = Writer(pb: pb);
                                  post['post'] = controller.text;
                                  var postWidget = await createPostWidget(
                                      post, user.fullName, user.avatar!, user);
                                  postWidgets[postIDs.indexOf(post['id'])] =
                                      postWidget;
                                  setState(() {});
                                  notifyListeners();
                                  _postsStreamController.add(postWidgets);
                                  await writer.updatePost(
                                      post['id'], post['post']);
                                  Navigator.of(context).pop();
                                },
                                child: Text('حفظ',
                                    style: GoogleFonts.notoSansArabic(
                                        fontWeight: FontWeight.w500)),
                              ),
                              TextButton(
                                style: ButtonStyle(
                                    foregroundColor:
                                        MaterialStatePropertyAll(redColor)),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('إلغاء',
                                    style: GoogleFonts.notoSansArabic(
                                        fontWeight: FontWeight.w500)),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          });
        });
  }

  Future newComment(comment, context) async {
    var map = comment.toJson();
    final id = map['id'];
    final widget = await createCommentCard(comment, context);
    commentIDs.add(id);
    commentWidgets.add(widget);
    _commentsStreamController.add(commentWidgets);
    notifyListeners();
    Writer writer = Writer(pb: pb);
    final user = Provider.of<User>(context, listen: false);
    await writer.newCommentNotify(comment, user.id);
  }

  void updateComment(comment, context) {
    var controller = DetectableTextEditingController(
        regExp: detectionRegExp(atSign: false),
        detectedStyle: TextStyle(
          color: greenColor,
        ));
    controller.text = comment['comment'];
    TextDirection textDirection = isArabic(controller.text.split('')[0])
        ? TextDirection.rtl
        : TextDirection.ltr;
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return Dialog(
              surfaceTintColor: Colors.white,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                  child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    children: [
                      StatefulBuilder(
                        builder: (context, setState) {
                          return DetectableTextField(
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
                              label: Text('تعديل تعليق'),
                              labelStyle: TextStyle(
                                color: Colors.black, // Set your desired color
                              ),
                              contentPadding: EdgeInsets.all(25),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    30), // Circular/Oval border
                              ),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Row(
                          children: [
                            TextButton(
                              style: ButtonStyle(
                                  foregroundColor:
                                      MaterialStatePropertyAll(greenColor)),
                              onPressed: () async {
                                Writer writer = Writer(pb: pb);
                                var index = commentIDs.indexOf(comment['id']);
                                comment['comment'] = controller.text;
                                var updatedComment =
                                    await createCommentCard(comment, context);
                                commentWidgets[index] = updatedComment;
                                _commentsStreamController.add(commentWidgets);
                                await writer.updateComment(
                                    comment['id'], comment['comment']);
                                notifyListeners();
                                Navigator.of(context).pop();
                              },
                              child: Text('حفظ',
                                  style: GoogleFonts.notoSansArabic(
                                      fontWeight: FontWeight.w500)),
                            ),
                            TextButton(
                              style: ButtonStyle(
                                  foregroundColor:
                                      MaterialStatePropertyAll(redColor)),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('إلغاء',
                                  style: GoogleFonts.notoSansArabic(
                                      fontWeight: FontWeight.w500)),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            );
          });
        });
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
  var controller = DetectableTextEditingController(
    regExp: detectionRegExp(atSign: false),
    detectedStyle: TextStyle(
      color: greenColor,
    ),
  );
  TextDirection textDirection = TextDirection.ltr;
  Widget icon = Icon(Icons.send);
  List<Widget> commentWidgets = [];
  bool isSending = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Renderer renderer = Provider.of<Renderer>(context, listen: false);
    renderer.commentsStream.listen((newComments) {
      setState(() {
        commentWidgets.clear();
        commentWidgets.addAll(newComments);
      });
    });
    loadComments();
  }

  void loadComments() async {
    Renderer renderer = Provider.of<Renderer>(context, listen: false);
    await renderer.renderComments(
        widget.post['comments'], context, renderer._commentsStreamController);
    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Renderer renderer = Provider.of<Renderer>(context);
    Widget commentWidget;
    commentWidget = pagePadding(
      ListView(children: [
        Visibility(
          child: Center(child: CupertinoActivityIndicator()),
          visible: isLoading,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 100.0),
          child: Column(
            children: commentWidgets,
          ),
        )
      ]),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_downward),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      bottomSheet: Card(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        child: pagePadding(
          Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: ((context, setState) {
                return Row(
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: IconButton(
                        icon: icon,
                        onPressed: () async {
                          if (isSending) {
                            return;
                          }
                          setState(() {
                            icon = CupertinoActivityIndicator();
                            isSending = true;
                          });
                          final comment = controller.text;
                          final post = widget.post['id'];
                          final user =
                              Provider.of<User>(context, listen: false);
                          final id = user.id;
                          final writer = Writer(pb: user.pb);

                          final newComment =
                              await writer.writeComment(comment, post, id);
                          await renderer.newComment(newComment, context);
                          icon = Icon(Icons.send);
                          controller.text = "";
                          isSending = false;
                          setState(() {});
                        },
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                30), // Circular/Oval border
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
      body: commentWidget,
    );
  }
}

class CreatePost extends StatefulWidget {
  CreatePost({super.key});
  @override
  State<CreatePost> createState() => _CreatePostState();
}

class _CreatePostState extends State<CreatePost> {
  late final user;
  bool isPublic = true;
  List<http.MultipartFile> multipartFiles = [];
  List topics = [];
  List<Widget> previews = [];
  List paths = [];
  bool attachVideo = false;
  TextEditingController videoLink = TextEditingController();

  @override
  void initState() {
    super.initState();
    user = Provider.of<User>(context, listen: false);
  }

  FilePickerResult? images;

  var controller = DetectableTextEditingController(
    regExp: detectionRegExp(atSign: false),
    detectedStyle: GoogleFonts.notoSansArabic(
        textStyle: TextStyle(fontWeight: FontWeight.w700, color: greenColor),
        fontSize: 15),
  );
  TextDirection textDirection = TextDirection.rtl;

  void getTopic(value) {
    if (!hashTagRegExp.hasMatch(value)) {
      return;
    }
    var strings = value.split(' ');
    for (var string in strings) {
      if (hashTagRegExp.hasMatch(string)) {
        string = string.split('#')[1];
        string = string.replaceAll(RegExp(r'[^\w\s]+$'), '');
        topics.add(string);
      }
    }
  }

  Future getImageFile() async {
    if (images != null) {
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
    }
  }

  String labelText = 'كتابة منشور للأصدقاء فقط';

  @override
  Widget build(BuildContext context) {
    return floatingInput(
      SingleChildScrollView(
        child: Container(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Column(
              children: [
                Row(
                  children: [
                    Row(
                      children: [
                        PopupMenuButton<int>(
                          icon: Icon(Icons.attachment_rounded),
                          color: Colors.white,
                          surfaceTintColor: Colors.white,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 1,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(Icons.video_collection_rounded,
                                      color: Colors.black, size: 24),
                                  Text('إضافة فيديو من YouTube',
                                      textDirection: TextDirection.rtl),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 2,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(Icons.camera_alt,
                                      color: Colors.black, size: 24),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 5.0),
                                    child: Text('إضافة صورة'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 1) {
                              setState(() {
                                attachVideo = !attachVideo;
                              });
                            } else if (value == 2) {
                              FilePickerResult? result =
                                  await FilePicker.platform.pickFiles(
                                allowMultiple: true,
                                type: FileType.custom,
                                allowedExtensions: ['jpg', 'jpeg', 'png'],
                              );
                              if (result!.files.first.size > 5242880) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'نعتذر، حجم هذه الصورة أكبر من الحد الأقصى\nالرجاء اختيار صورة حجمها أقل من 5 ميغابايت')),
                                );
                                return;
                              }
                              images = result;
                              await getImageFile();
                              for (var pic in images!.files) {
                                paths.add(pic.name);
                                if (kIsWeb) {
                                  previews.add(
                                    Column(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            var target =
                                                paths.indexOf(pic.name);
                                            multipartFiles.removeAt(target);
                                            paths.removeAt(target);
                                            previews.removeAt(target);
                                            setState(() {});
                                          },
                                          icon: Icon(Icons.close),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return GestureDetector(
                                                      onTap: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      child: InteractiveViewer(
                                                        child: Image.memory(
                                                            pic.bytes!),
                                                      ),
                                                    );
                                                  });
                                            },
                                            child: Image.memory(pic.bytes!,
                                                height: 50),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  previews.add(
                                    Column(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            var target =
                                                paths.indexOf(pic.name);
                                            multipartFiles.removeAt(target);
                                            paths.removeAt(target);
                                            previews.removeAt(target);
                                            setState(() {});
                                          },
                                          icon: Icon(Icons.close),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return GestureDetector(
                                                      onTap: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      child: InteractiveViewer(
                                                        child: Image.file(
                                                          File(pic.path!),
                                                        ),
                                                      ),
                                                    );
                                                  });
                                            },
                                            child: Image.file(File(pic.path!),
                                                height: 50),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              }
                              setState(() {});
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: InkWell(
                            child: isPublic
                                ? Icon(Icons.public)
                                : Icon(Icons.people),
                            onTap: () {
                              isPublic = !isPublic;
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.rtl,
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
                                  var firstString =
                                      controller.text.split(' ')[0];
                                  if (hashTagRegExp.hasMatch(firstString)) {
                                    firstString = firstString.split('#')[1];
                                  }
                                  textDirection = isArabic(firstString)
                                      ? TextDirection.rtl
                                      : TextDirection.ltr;
                                },
                              );
                            }
                          },
                          controller: controller,
                          decoration: InputDecoration(
                            label: isPublic
                                ? Text('منشور عام')
                                : Text('منشور للأصدقاء'),
                            labelStyle: TextStyle(
                              color: Colors.black, // Set your desired color
                            ),
                            contentPadding: EdgeInsets.all(20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          List truthTable = [];
                          truthTable.add(controller.text == "");
                          truthTable.add(multipartFiles.isEmpty);
                          truthTable.add(videoLink.text == "");
                          if (!truthTable.contains(false)) {
                            Navigator.of(context).pop();
                            return;
                          }

                          var linkList = videoLink.text.split('/');
                          if (videoLink.text != "") {
                            if (linkList.contains('youtube.com') == false &&
                                linkList.contains('youtu.be') == false &&
                                linkList.contains('www.youtube.com') == false) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'يجب ان يكون رابط الفيديو من موقع YouTube',
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              );
                              videoLink.clear();
                              return;
                            }
                          }

                          getTopic(controller.text);

                          final user =
                              Provider.of<User>(context, listen: false);

                          final writer = Writer(pb: user.pb);
                          await writer.createPost(
                              multipartFiles,
                              topics,
                              user.id,
                              isPublic,
                              controller.text,
                              videoLink.text);

                          topics.clear();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: previews,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Visibility(
                    visible: attachVideo,
                    child: Container(
                      width: double.infinity,
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: TextField(
                          controller: videoLink,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            label: Text(
                              'رابط YouTube',
                              textDirection: TextDirection.rtl,
                            ),
                            labelStyle: TextStyle(
                              color: Colors.black, // Set your desired color
                            ),
                            contentPadding: EdgeInsets.all(20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ),
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

class ShowFullPost extends StatefulWidget {
  final post;
  ShowFullPost({super.key, required this.post});

  @override
  State<ShowFullPost> createState() => _ShowFullPostState();
}

class _ShowFullPostState extends State<ShowFullPost> {
  var controller = DetectableTextEditingController(
      regExp: detectionRegExp(atSign: false),
      detectedStyle: TextStyle(
        color: greenColor,
      ));
  TextDirection textDirection = TextDirection.ltr;

  Future getPost() async {
    var user = Provider.of<User>(context, listen: false);
    final fetcher = Fetcher(pb: user.pb);
    final Renderer renderer = Renderer(fetcher: fetcher, pb: user.pb);

    var record = await fetcher.getPost(widget.post);
    var post = record.toJson();
    var postWidget = await renderer.createPostWidget(
        post, user.fullName, user.avatar!, user);
    List<Widget> commentWidgets = [];
    for (var item in post['comments']) {
      var record = await fetcher.getComment(item);
      var commentWidget = await renderer.createCommentCard(record, context);
      commentWidgets.add(commentWidget);
    }
    var container = pagePadding(Column(
      children: [postWidget, pagePadding(Column(children: commentWidgets))],
    ));

    return container;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
      ),
      bottomSheet: Card(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        child: pagePadding(
          Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: ((context, setState) {
                return Row(
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () async {
                          final comment = controller.text;
                          final post = widget.post['id'];
                          final renderer =
                              Provider.of<Renderer>(context, listen: false);
                          final user =
                              Provider.of<User>(context, listen: false);
                          final id = user.id;
                          final writer = Writer(pb: user.pb);

                          final newComment =
                              await writer.writeComment(comment, post, id);
                          renderer.newComment(newComment, context);
                        },
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                30), // Circular/Oval border
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: FutureBuilder(
          future: getPost(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: [
                  Center(child: shimmer),
                ],
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                    'An unexpected error occurred, please try again later'),
              );
            }
            if (snapshot.hasData) {
              var data = snapshot.data;
              return Padding(
                  padding: EdgeInsets.only(bottom: 100), child: data!);
            } else {
              return shimmer;
            }
          },
        ),
      ),
    );
  }
}

enum ReportReason { nudity, spam, fakeNews, occupation }

class ReportAbuse extends StatefulWidget {
  final String text;
  final String id;
  final Widget poster;
  final String mode;

  const ReportAbuse(
      {super.key,
      required this.text,
      required this.id,
      required this.poster,
      required this.mode});

  @override
  State<ReportAbuse> createState() => _ReportAbuseState();
}

class _ReportAbuseState extends State<ReportAbuse> {
  ReportReason? _reason = ReportReason.nudity;
  TextEditingController controller = TextEditingController();

  Future sendReport() async {
    final pb = await PocketBase('https://ahrar.pockethost.io');
    String reason = (_reason.toString().split('.')[1]);
    var post = widget.id;
    final body;
    if (widget.mode == 'post') {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(
              'تبليغ  عن منشور',
              style: defaultText,
              textScaler: TextScaler.linear(0.75),
            ),
            automaticallyImplyLeading: true,
            leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pop();
                })),
        body: SingleChildScrollView(
          child: pagePadding(
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: isArabic(widget.text)
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      widget.poster,
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text(
                          textDirection: isArabic(widget.text)
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          textAlign: isArabic(widget.text)
                              ? TextAlign.end
                              : TextAlign.start,
                          widget.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('المشكلة:',
                            textDirection: TextDirection.rtl,
                            style: defaultText)
                      ],
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: StatefulBuilder(
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
                            Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: StatefulBuilder(
                                builder: ((context, setState) {
                                  return TextField(
                                    onChanged: (value) {
                                      setState(() {});
                                    },
                                    keyboardType: TextInputType.multiline,
                                    maxLines: null,
                                    textDirection: isArabic(controller.text)
                                        ? TextDirection.rtl
                                        : TextDirection.ltr,
                                    controller: controller,
                                    decoration: InputDecoration(
                                      hintText: "هل ترغب بإضافة معلومات أخرى؟",
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: ButtonStyle(
                            foregroundColor:
                                MaterialStatePropertyAll(blackColor),
                          ),
                          onPressed: () async {
                            await sendReport();
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
                ])
              ],
            ),
          ),
        ));
  }
}
