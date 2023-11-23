import 'package:flutter/material.dart';
import "package:tahrir/Pages/profiles.dart";
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import "package:tahrir/Pages/swipe.dart";
import "package:tahrir/Pages/topics.dart";
import "package:tahrir/main.dart";
import "package:tahrir/notifications.dart";
import "package:tahrir/user_data.dart";
import "package:url_launcher/url_launcher.dart";
import "Pages/styles.dart";
import "Pages/my_profile.dart";
import 'pages/circle.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;
  final List<Widget> _children = [
    const Circle(),
    const TopicSelection(),
    const SwipeCards(),
    const Profile(),
  ];

  String buildNo = "231123/3";

  @override
  void initState() {
    super.initState();
    checkConnection();
    checkAlerts();
    checkUpdates();
  }

  Future checkUpdates() async {
    var request = await pb
        .collection('version_control')
        .getFullList(filter: 'latest = true');

    if (request.isNotEmpty) {
      var response = request[0].toJson();
      if (response['build'] == buildNo) {
        return;
      }
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.black,
                iconColor: Colors.black,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'يوجد تحديث جديد',
                      textScaler: TextScaler.linear(0.75),
                    ),
                  ],
                ),
                content: Padding(
                  padding: EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                            'تم إطلاق نسخة محدثة من تطبيق أحرار. هل ترغب بتحمليها الآن؟')
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('لا'),
                      style: TextButtonStyle),
                  TextButton(
                      onPressed: () async {
                        await launchUrl(Uri.parse(response['repo']));
                      },
                      child: Text('نعم'),
                      style: TextButtonStyle),
                ]);
          });
    }
  }

  Future checkAlerts() async {
    var request = await pb.collection('alerts').getList(filter: 'seen = false');
    var response = request.toJson();
    if (response['items'].isEmpty) {
      return;
    }

    var alert = response['items'][0];
    String id = alert['id'];
    String alertText = alert['alert'];

    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.black,
              iconColor: Colors.black,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    alert['title'],
                    textScaler: TextScaler.linear(0.75),
                  ),
                ],
              ),
              content: Padding(
                padding: EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    children: [Text(alertText)],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      pb.collection('alerts').update(id, body: {"seen": true});
                      Navigator.of(context).pop();
                    },
                    child: Text('تم'),
                    style: TextButtonStyle)
              ]);
        });
  }

  Future<void> checkConnection() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    Timer.periodic(const Duration(seconds: 50), (timer) async {
      if (connectivityResult == ConnectivityResult.none) {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return NoConnection();
        }));
      }
    });
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                  context: context, builder: (context) => const SearchMenu());
            },
            icon: const Icon(Icons.search),
          ),
          Notifications()
        ],
      ),
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        onTap: onTabTapped,
        currentIndex: _currentIndex,
        selectedItemColor: greenColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "الرئيسية",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tag),
            label: "مواضيع",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swipe),
            label: "إكتشف",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "صفحتي",
          )
        ],
      ),
    );
  }
}

class SearchMenu extends StatefulWidget {
  const SearchMenu({super.key});

  @override
  State<SearchMenu> createState() => _SearchMenuState();
}

class _SearchMenuState extends State<SearchMenu> {
  TextEditingController controller = TextEditingController();
  Widget searchResults = Center(child: Text('', style: defaultText));
  TextDirection textFieldTextDirection = TextDirection.ltr;

  Future findFriends() async {
    List<Widget> page = [];
    if (controller.text == "") {
      return;
    }
    setState(() {
      searchResults = shimmer;
    });

    var request = await pb.collection('users').getList(
          filter:
              'email ?~ "${controller.text}" || fname ?~ "${controller.text}" || lname ?~ "${controller.text}"',
        );

    var result = request.toJson()['items'];

    if (result.isEmpty) {
      setState(() {
        searchResults = Center(
          child: Text(
            'لم نعثر على ${controller.text}',
            style: defaultText,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
        );
      });
      return;
    }
    for (var item in result) {
      var target = await pb.collection('users').getOne(item['id']);
      var friend = target.toJson();
      String name = '${friend['fname']} ${friend['lname']}';
      var avatarUrl = pb.getFileUrl(target, friend['avatar']).toString();

      page.add(Card(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ViewProfile(target: friend['id'])));
            },
            leading:
                ClipOval(child: Image.network(avatarUrl, fit: BoxFit.cover)),
            title: Text(name),
          ),
        ),
      ));
    }
    setState(() {
      searchResults = Column(
        children: page,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(
          'بحث عن أصدقاء',
          style: defaultText,
        ),
        centerTitle: true,
      ),
      body: searchResults,
      bottomSheet: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 5),
          child: Row(
            children: [
              Flexible(
                child: StatefulBuilder(builder: ((context, setState) {
                  return TextField(
                    onChanged: (value) {
                      setState(() {
                        textFieldTextDirection =
                            RegExp(r'[\u0600-\u06FF]').hasMatch(value)
                                ? TextDirection.rtl
                                : TextDirection.ltr;
                      });
                    },
                    textDirection: textFieldTextDirection,

                    keyboardType: TextInputType.emailAddress,
                    maxLines: null, // Add this line

                    controller: controller,
                    decoration: const InputDecoration(
                        hintText: "الإسم أو البريد الإلكتروني"),
                  );
                })),
              ),
              IconButton(
                onPressed: findFriends,
                icon: const Icon(Icons.search),
              )
            ],
          ),
        ),
      ),
    );
  }
}
