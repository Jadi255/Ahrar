import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/fetchers.dart';
import 'package:qalam/Pages/my_profile.dart';
import 'package:qalam/Pages/users_profiles.dart';
import 'package:qalam/styles.dart';
import 'package:qalam/user_data.dart';

class SearchMenu extends StatefulWidget {
  const SearchMenu({super.key});

  @override
  State<SearchMenu> createState() => _SearchMenuState();
}

class _SearchMenuState extends State<SearchMenu> {
  TextEditingController controller = TextEditingController();
  TextDirection textDirection = TextDirection.rtl;

  Future searchUsers() async {
    List<Widget> cards = [];
    final provider = Provider.of<User>(context, listen: false);
    final fetcher = Fetcher(pb: provider.pb);
    var users = await fetcher.searchUsers(controller.text);
    for (var item in users) {
      var user = item.toJson();
      final avatarUrl = fetcher.pb.getFileUrl(item, user['avatar']).toString();

      cards.add(
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          child: pagePadding(
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  foregroundImage: CachedNetworkImageProvider(avatarUrl),
                  backgroundImage: Image.asset('assets/placeholder.jpg').image,
                  radius: 25),
              title: Text(user['full_name'], style: defaultText),
              onTap: () {
                Widget targetPage = Placeholder();

                if (user['id'] != provider.id) {
                  targetPage =
                      UserProfile(id: user['id'], fullName: user['full_name']);
                } else if (user['id'] == provider.id) {
                  targetPage = MyProfile(
                    isLeading: true,
                  );
                }
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        targetPage,
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
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
              },
            ),
          ),
        ),
      );
    }

    return cards;
  }

  Widget bodyWidget = Center(
    child: Text('بحث عن مستخدم', style: defaultText),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
      ),
      bottomSheet: Card(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Flexible(
                  child: TextField(
                    cursorColor: blackColor,
                    controller: controller,
                    textDirection: textDirection,
                    onChanged: (value) {
                      if (value == "") {
                        return;
                      }
                      setState(() {
                        textDirection = isArabic(value.split('')[0])
                            ? TextDirection.rtl
                            : TextDirection.ltr;
                      });
                    },
                    decoration: InputDecoration(
                      label: Text('الإسم'),
                      labelStyle: TextStyle(
                        color: Colors.black, // Set your desired color
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20),
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
              ),
              IconButton(
                icon: Icon(Icons.search),
                onPressed: () async {
                  setState(() {
                    bodyWidget = shimmer;
                  });
                  var results = await searchUsers();

                  setState(() {
                    bodyWidget = Padding(
                      padding: const EdgeInsets.only(bottom: 100.0),
                      child: Column(children: results),
                    );
                  });
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          child: pagePadding(bodyWidget),
        ),
      ),
    );
  }
}
