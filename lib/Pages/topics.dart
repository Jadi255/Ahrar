import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qalam/Pages/fetchers.dart';
import 'package:qalam/Pages/renderers.dart';
import 'package:qalam/styles.dart';
import 'package:qalam/user_data.dart';

class Topics extends StatefulWidget {
  const Topics({super.key});

  @override
  State<Topics> createState() => _TopicsState();
}

class _TopicsState extends State<Topics> {
  var topics = [];
  var topicIDs = [];
  var topicLengths = [];

  Future fetchTopics() async {
    final user = Provider.of<User>(context, listen: false);
    topics.clear();
    topicIDs.clear();
    final records = await user.pb.collection('topics').getFullList(
          sort: '-updated',
        );
    for (var record in records) {
      var topic = record.toJson();
      topics.add(topic['topic']);
      topicIDs.add(topic['id']);
      topicLengths.add(topic['posts'].length);
    }
  }

  Future<Widget> renderTopics() async {
    List<Widget> topicCards = [];
    await fetchTopics();
    for (int i = 0; i < topics.length; i++) {
      var topic = topics[i];
      if (topicLengths[i] > 0) {
        topicCards.add(
          Card(
            surfaceTintColor: Colors.white,
            color: Colors.white,
            child: ListTile(
                onTap: () {
                  final user = Provider.of<User>(context, listen: false);
                  int index = topics.indexOf(topic);
                  var id = topicIDs[index];
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChangeNotifierProvider(
                        create: (context) => Renderer(
                            fetcher: Fetcher(pb: user.pb), pb: user.pb),
                        child: Discover(user: user, id: id, topic: topic),
                      ),
                    ),
                  );
                },
                leading: Icon(Icons.tag),
                title: Text(topic, style: defaultText),
                subtitle: Text('عدد المنشورات: ${topicLengths[i]}'),
                trailing: Icon(Icons.arrow_forward_ios)),
          ),
        );
      }
    }
    return Column(children: topicCards);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                return data!;
              } else {
                return Column(
                  children: [
                    Center(child: shimmer),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class Discover extends StatefulWidget {
  final User user;
  final String id;
  final String topic;
  const Discover(
      {super.key, required this.user, required this.id, required this.topic});

  @override
  State<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<Discover> {
  ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  List<Widget> _allPosts = [];
  bool _isLoading = false;
  bool refresh = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        loadPosts();
      }
    });

    loadPosts();
  }

  void addPosts(List<Widget> newPosts) {
    setState(() {
      _allPosts.clear();
      _allPosts.addAll(newPosts);
      _isLoading = false;
    });
  }

  Future loadPosts() async {
    Renderer renderer = Provider.of<Renderer>(context, listen: false);
    renderer.renderPosts(
        context, widget.user, _currentPage, 7, 'topic', widget.id, refresh);
    if (refresh) {
      refresh = false;
    }
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      _currentPage++;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPosts() async {
    _allPosts.clear();
    _currentPage = 1;
    refresh = true;
    await loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    Renderer renderer = Provider.of<Renderer>(context);
    renderer.postsStream.listen((newPosts) {
      addPosts(newPosts);
    });
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.topic}', style: defaultText),
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        color: greenColor,
        onRefresh: _refreshPosts,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return StreamBuilder<List<Widget>>(
              stream: renderer.postsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: shimmer);
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_allPosts.isEmpty && !_isLoading)
                            Center(
                                child: Text('لا يوجد منشورات',
                                    style: defaultText)),
                          Column(
                            children: _allPosts,
                          ),
                          if (_isLoading) Center(child: shimmer)
                        ],
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}
