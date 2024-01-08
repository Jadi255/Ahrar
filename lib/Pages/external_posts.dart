import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pocketbase/pocketbase.dart';
import 'package:qalam/styles.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe_plus/youtube_player_iframe_plus.dart';

class ExternalLink extends StatefulWidget {
  final id;
  const ExternalLink({super.key, required this.id});

  @override
  State<ExternalLink> createState() => _ExternalLinkState();
}

class _ExternalLinkState extends State<ExternalLink> {
  Future<Widget> getPost() async {
    final PocketBase pb = await PocketBase('https://ahrar.pockethost.io');
    var postRecord = await pb.collection('circle_posts').getOne(widget.id);
    var post = postRecord.toJson();
    var posterRecord = await pb.collection('users').getOne(post['by']);
    var poster = posterRecord.toJson();
    var fullName = poster['full_name'];
    var avatarUrl = pb.getFileUrl(posterRecord, poster['avatar']).toString();
    var postWidget = await createPostWidget(post, pb, fullName, avatarUrl);
    return postWidget;
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

  Future createPostWidget(post, pb, fullName, avatar) async {
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: themedCard(
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
              crossAxisAlignment: isArabic(post['post'])
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade100,
                      foregroundImage: CachedNetworkImageProvider(avatar),
                      backgroundImage:
                          Image.asset('assets/placeholder.jpg').image,
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
                if (post['linked_video'] != '' && images.isEmpty)
                  YoutubePlayerIFramePlus(
                    controller: videoController,
                    aspectRatio: 16 / 9,
                  ),
                if (images.isNotEmpty) imageView,
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Text(
                    post['post'],
                    textDirection: isArabic(post['post'])
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                )
              ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: coloredLogo,
      ),
      bottomSheet: Container(
        width: double.infinity,
        child: floatingInput(
          GestureDetector(
            onTap: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    return Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                          actionsAlignment: MainAxisAlignment.center,
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.white,
                          content: SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10.0),
                                    child: logo,
                                  ),
                                  Text(
                                    '\nمنصة التواصل الاجتماعي العربية\n',
                                    style: defaultText,
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    '"قلم " منصة تواصل اجتماعي عربية تم تطويرها لتوفير مساحة حرة وآمنة للتعبير والتواصل بين المستخدمين العرب.\n\nتأسست "قلم" كرد فعل على الرقابة والقيود المفروضة على المنصات الاجتماعية الأخرى، وهي تهدف إلى توفير منصة حيث يمكن للأفراد التعبير عن آرائهم ومشاركة القضايا التي تهمهم بحرية تامة.\n\n"قلم" هو أيضاً منصة تكنولوجية عربية، تم تطويرها بواسطة مبرمجين عرب، وتهدف إلى توفير فرص للمبرمجين وصناع المحتوى العرب.',
                                  )
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            Text('احصل على التطبيق:', style: defaultText),
                            TextButton(
                                onPressed: () async {
                                  await launchUrl(Uri.parse(
                                      'https://github.com/Jadi255/Ahrar/releases/download/Apk/qalam.apk'));
                                },
                                child: Text('أجهزة Android'),
                                style: TextButtonStyle),
                            TextButton(
                                onPressed: () async {
                                  await launchUrl(Uri.parse(
                                      'https://qalam.up.railway.app/'));
                                },
                                child: Text('أجهزة iOS'),
                                style: TextButtonStyle),
                          ]),
                    );
                  });
            },
            child: Text(
              'تعرف على منصة قلم',
              style: GoogleFonts.notoSansArabic(
                  color: greenColor, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              textScaler: TextScaler.linear(1.15),
            ),
          ),
        ),
      ),
      body: FutureBuilder<Widget>(
        future: getPost(),
        builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CupertinoActivityIndicator(),
            ); // or your custom loader
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return SingleChildScrollView(
              child: Container(
                height: null,
                child: snapshot.data!,
              ),
            );
          }
        },
      ),
    );
  }
}
