import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahrir/Pages/circle.dart';
import 'package:tahrir/home.dart';
import 'package:tahrir/user_data.dart';
import 'package:url_launcher/url_launcher.dart';
import "styles.dart";

// ignore: must_be_immutable
class ViewProfile extends StatefulWidget {
  String target;
  ViewProfile({super.key, required this.target});

  @override
  State<ViewProfile> createState() => _ViewProfileState();
}

class _ViewProfileState extends State<ViewProfile> {
  late Image avatar;
  bool pending = false;
  String? pendingID;
  Future getUser(id) async {
    final prefs = await SharedPreferences.getInstance();
    String me = prefs.getString('id')!;
    var record = await pb.collection('users').getOne(id);
    Map account = record.toJson();

    var isPending = await pb
        .collection('friend_requests')
        .getList(filter: 'from = "$me" && to = "${account['id']}"');
    if (isPending.toJson()['items'].length != 0) {
      pending = true;
      pendingID = isPending.toJson()['id'];
    }

    var avatarUrl = pb.files.getUrl(record, record.toJson()['avatar']);

    var avatar;
    try {
      avatar =
          Image.network('$avatarUrl?token=${pb.authStore.token}', width: 250);
    } catch (e) {
      avatar = Image.network(
          'https://png.pngtree.com/png-clipart/20210915/ourmid/pngtree-user-avatar-placeholder-png-image_3918418.jpg');
    }

    var username = '${account['fname']} ${account['lname']}';
    var bio = account['about'];
    var sex = 'female';
    if (account['sex'] == 'male') {
      sex = 'ذكر';
    }

    var birthday = account['birthday'].split(' ')[0];
    var age = DateTime.now().year - DateTime.parse(birthday).year;
    var joinDate = account['created'].split(' ')[0];
    List friends = account['friends'];
    bool isFriend = friends.contains(me);

    return Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: InteractiveViewer(
                            child: avatar,
                          ),
                        );
                      });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(250),
                  child: avatar,
                ),
              ),
            ),
            Text(
              username,
              style: defaultText,
              textScaler: const TextScaler.linear(1.25),
            ),
            Text(bio, style: defaultText),
            const Divider(),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0.5,
                    child: ListTile(
                      leading: const Icon(Icons.email),
                      subtitle: Text(
                        account['email'] ?? 'غير معرف',
                        style: defaultText,
                      ),
                      title: const Text('البريد الإلكتروني'),
                    ),
                  ),
                  Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0.5,
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      subtitle: Text(
                        sex,
                        style: defaultText,
                      ),
                      title: const Text('الجنس'),
                    ),
                  ),
                  Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0.5,
                    child: ListTile(
                      leading: const Icon(Icons.cake),
                      subtitle: Text(
                        '$age عام  ($birthday)',
                        style: defaultText,
                      ),
                      title: const Text('العمر'),
                    ),
                  ),
                  Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0.5,
                    child: ListTile(
                      leading: const Icon(Icons.date_range),
                      subtitle: Text(
                        joinDate,
                        style: defaultText,
                      ),
                      title: const Text('تاريخ الإشتراك'),
                    ),
                  ),
                  const Divider(),
                  Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0.5,
                    child: ListTile(
                      onTap: () {
                        if (!isFriend) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'يجب إضافة المشترك كصديق لرؤية منشوراته')));
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ShowPosts(
                                target: widget.target, name: username),
                          ),
                        );
                      },
                      leading: const Icon(Icons.view_carousel_outlined),
                      title: Text(
                        'عرض المنشورات',
                        style: defaultText,
                      ),
                    ),
                  ),
                  if (isFriend)
                    Card(
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      elevation: 0.5,
                      child: ListTile(
                        leading: const Icon(Icons.delete),
                        title: Text(
                          'إزالة صديق',
                          style: defaultText,
                        ),
                        onTap: () {
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
                                        account['friends'].remove(me);
                                        var record = await pb
                                            .collection('users')
                                            .getOne(me);
                                        var myFriends =
                                            record.toJson()['friends'];
                                        myFriends.remove(account['id']);

                                        var req = await pb
                                            .collection('users')
                                            .update(me,
                                                body: {"friends": myFriends});
                                        req = await pb
                                            .collection('users')
                                            .update(account['id'], body: {
                                          "friends": account['friends']
                                        });

                                        setState(() {});

                                        Navigator.of(context).pop();
                                      },
                                      icon:
                                          Icon(Icons.check, color: greenColor),
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
                        },
                      ),
                    ),
                  if (!isFriend && !pending)
                    Card(
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      elevation: 0.5,
                      child: ListTile(
                        onTap: () async {
                          var existingRequest = await pb
                              .collection('friend_requests')
                              .getList(
                                  filter:
                                      '(from = "$me" && to = "${account['id']}") || (from = "${account['id']}" && to = "$me")');

                          if (existingRequest.toJson()['items'].length != 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('تم إرسال طلب صداقة مسبقاً')));
                            return;
                          }

                          final body = <String, dynamic>{
                            "from": me,
                            "to": account['id']
                          };
                          final record = await pb
                              .collection('friend_requests')
                              .create(body: body);

                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تم إرسال طلب الصداقة')));
                        },
                        leading: const Icon(Icons.add),
                        title: Text(
                          'إضافة صديق',
                          style: defaultText,
                        ),
                      ),
                    ),
                ],
              ),
            )
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const VerticalDivider(),
                RichText(
                  text: TextSpan(
                    style: defaultText,
                    children: <InlineSpan>[
                      TextSpan(
                          text: 'أ',
                          style: TextStyle(color: blackColor, fontSize: 24)),
                      TextSpan(
                          text: 'ح',
                          style: TextStyle(color: redColor, fontSize: 24)),
                      TextSpan(
                          text: 'ر',
                          style: TextStyle(color: greenColor, fontSize: 24)),
                      TextSpan(
                          text: 'ا',
                          style: TextStyle(color: blackColor, fontSize: 24)),
                      TextSpan(
                          text: 'ر',
                          style: TextStyle(color: redColor, fontSize: 24)),
                    ],
                  ),
                )
              ],
            ),
            GestureDetector(
                child: SvgPicture.asset('assets/logo2.svg', width: 50),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AboutDialog(
                          applicationIcon:
                              SvgPicture.asset('assets/logo2.svg', width: 55),
                          applicationName: "أحرار",
                          applicationLegalese: "تصميم جهاد ناصر الدين",
                        );
                      });
                }),
          ],
        ),
      ),
      body: FutureBuilder(
          future: getUser(widget.target),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
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
                return SingleChildScrollView(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(left: 1.0, right: 1, top: 10),
                    child: data,
                  ),
                );
              }
            }
            return shimmer;
          }),
    );
  }
}

// ignore: must_be_immutable
class ShowPosts extends StatefulWidget {
  String target;
  String name;
  ShowPosts({super.key, required this.target, required this.name});

  @override
  State<ShowPosts> createState() => _ShowPostsState();
}

class _ShowPostsState extends State<ShowPosts> {
  int _page = 0;
  final List<Widget> _postsWidgets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  void fetchPosts() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      _page += 1;
      List<Widget> newPosts = await renderPosts(limit: 5, page: _page);
      setState(() {
        _postsWidgets.addAll(newPosts);
        _isLoading = false;
      });
    }
  }

  Future getPosts({int limit = 5, int page = 1}) async {
    final resultList = await pb.collection('circle_posts').getList(
          page: page,
          perPage: limit,
          sort: '-created',
          filter: 'by.id = "${widget.target}"',
        );
    return (resultList);
  }

  Future<List<Widget>> renderPosts({int limit = 5, int page = 1}) async {
    var records = await getPosts(limit: limit, page: page);
    Map data = await records.toJson();
    List<Widget> widgets = [];
    for (var post in data['items']) {
      var postTime = DateFormat('dd/MM/yyyy · HH:mm')
          .format(DateTime.parse(post['created']).toLocal());
      int ratio = post['likes'].length - post['dislikes'].length;

      Widget postWidget = ratio < 0
          ? themedCard(ExpansionTile(
              title: Center(
                  child: Text(
                      'هذا المنشور حصل على تصنيف متدني، أنقر هنا لمشاهدته',
                      style: defaultText)),
              children: [createPostWidget(post, postTime)],
            ))
          : createPostWidget(post, postTime);
      widgets.add(postWidget);
    }

    return widgets;
  }

  Widget createPostWidget(var post, String postTime) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: themedCard(
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
                      title: Text(
                        postTime,
                      ),
                    ),
                  ),
                ],
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
                    future:
                        Future.delayed(Duration(milliseconds: 500), () async {
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
            createPostActions(post, ratio),
          ],
        ),
      ),
    );
  }

  Widget createPostActions(var post, int ratio) {
    return StatefulBuilder(builder: (context, setState) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            createCommentButton(context, post),
            if (post['is_public']) createShareButton(post),
            createLikeDislikeButtons(post, setState),
          ],
        ),
      );
    });
  }

  Widget createShareButton(var post) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0),
      child: IconButton(
        style: BlackTextButton,
        onPressed: () async {
          final url = 'ahrar.up.railway.app/#/showCommentsExtern/${post['id']}';
          await Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم نسخ رابط المنشور للمشاركة')),
          );
        },
        icon: const Icon(Icons.share),
      ),
    );
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
      icon: Icon(Icons.thumb_up, color: isLiked ? greenColor : Colors.black),
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
      icon: Icon(Icons.thumb_down, color: isDisliked ? redColor : Colors.black),
    );
  }

  Widget createCommentButton(BuildContext context, var post) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0),
      child: IconButton(
        style: BlackTextButton,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ShowComments(
                post: post['id'],
              ),
            ),
          );
        },
        icon: const Row(children: [Icon(Icons.comment)]),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: true,
          title: Text('منشورات ${widget.name}', style: defaultText),
        ),
        body: Padding(
          padding: const EdgeInsets.all(5),
          child: ListView.builder(
            controller: ScrollController(),
            itemCount:
                _isLoading ? _postsWidgets.length + 1 : _postsWidgets.length,
            itemBuilder: (context, index) {
              if (index == _postsWidgets.length) {
                // Return loading indicator at the end of the list
                return shimmer;
              } else {
                return _postsWidgets[index];
              }
            },
          ),
        ));
  }
}

class ViewProfileExtern extends StatefulWidget {
  String target;

  ViewProfileExtern({super.key, required this.target});

  @override
  State<ViewProfileExtern> createState() => _ViewProfileExternState();
}

class _ViewProfileExternState extends State<ViewProfileExtern> {
  Future<Widget> getUser() async {
    String id = widget.target;

    var record = await pb.collection('users').getOne(id);
    var account = record.toJson();

    var avatarUrl = pb.files.getUrl(record, record.toJson()['avatar']);

    var avatar;
    try {
      avatar =
          Image.network('$avatarUrl?token=${pb.authStore.token}', width: 250);
    } catch (e) {
      avatar = Image.network(
          'https://png.pngtree.com/png-clipart/20210915/ourmid/pngtree-user-avatar-placeholder-png-image_3918418.jpg');
    }

    var username = '${account['fname']} ${account['lname']}';
    var bio = account['about'];
    var sex = 'female';
    if (account['sex'] == 'male') {
      sex = 'ذكر';
    }

    var birthday = account['birthday'].split(' ')[0];
    var age = DateTime.now().year - DateTime.parse(birthday).year;
    var joinDate = account['created'].split(' ')[0];

    return Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: InteractiveViewer(
                            child: avatar,
                          ),
                        );
                      });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(250),
                  child: avatar,
                ),
              ),
            ),
            Text(
              username,
              style: defaultText,
              textScaler: const TextScaler.linear(1.25),
            ),
            Text(bio, style: defaultText),
            const Divider(),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0.5,
                    child: ListTile(
                      leading: const Icon(Icons.email),
                      subtitle: Text(
                        account['email'] ?? 'غير معرف',
                        style: defaultText,
                      ),
                      title: const Text('البريد الإلكتروني'),
                    ),
                  ),
                  Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0.5,
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      subtitle: Text(
                        sex,
                        style: defaultText,
                      ),
                      title: const Text('الجنس'),
                    ),
                  ),
                  Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0.5,
                    child: ListTile(
                      leading: const Icon(Icons.cake),
                      subtitle: Text(
                        '$age عام  ($birthday)',
                        style: defaultText,
                      ),
                      title: const Text('العمر'),
                    ),
                  ),
                  Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 0.5,
                    child: ListTile(
                      leading: const Icon(Icons.date_range),
                      subtitle: Text(
                        joinDate,
                        style: defaultText,
                      ),
                      title: const Text('تاريخ الإشتراك'),
                    ),
                  ),
                ],
              ),
            )
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(Icons.login),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) {
              return Home();
            }));
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const VerticalDivider(),
                RichText(
                  text: TextSpan(
                    style: defaultText,
                    children: <InlineSpan>[
                      TextSpan(
                          text: 'أ',
                          style: TextStyle(color: blackColor, fontSize: 24)),
                      TextSpan(
                          text: 'ح',
                          style: TextStyle(color: redColor, fontSize: 24)),
                      TextSpan(
                          text: 'ر',
                          style: TextStyle(color: greenColor, fontSize: 24)),
                      TextSpan(
                          text: 'ا',
                          style: TextStyle(color: blackColor, fontSize: 24)),
                      TextSpan(
                          text: 'ر',
                          style: TextStyle(color: redColor, fontSize: 24)),
                    ],
                  ),
                )
              ],
            ),
            GestureDetector(
                child: SvgPicture.asset('assets/logo2.svg', width: 50),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AboutDialog(
                          applicationIcon:
                              SvgPicture.asset('assets/logo2.svg', width: 55),
                          applicationName: "أحرار",
                          applicationLegalese: "تصميم جهاد ناصر الدين",
                        );
                      });
                }),
          ],
        ),
      ),
      bottomSheet: Container(
        width: double.infinity,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: TextButton(
            onPressed: () {
              
              context.go('/');
            },
            style: TextButtonStyle,
            child: Text(
              'إنضم لمنصة أحرار',
              textScaler: TextScaler.linear(1.15),
              style: defaultText,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            FutureBuilder(
                future: getUser(),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
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
                      return data!;
                    }
                  }
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(50.0),
                        child: Center(child: shimmer),
                      ),
                      Padding(padding: EdgeInsets.only(bottom: 100))
                    ],
                  );
                }),
          ],
        ),
      ),
    );
  }
}
