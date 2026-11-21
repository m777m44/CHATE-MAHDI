class User {
  User({
    required this.id,
    required this.username,
    this.email,
    this.name = '',
    this.bio = '',
    this.avatarUrl = '',
    this.websiteUrl = '',
    this.isPrivate = false,
    this.followers = 0,
    this.following = 0,
    this.postsCount = 0,
    this.createdAt,
  });

  final String id;
  final String username;
  final String? email;
  final String name;
  final String bio;
  final String avatarUrl;
  final String websiteUrl;
  final bool isPrivate;
  final int followers;
  final int following;
  final int postsCount;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> j) {
    return User(
      id: j['id'] as String,
      username: (j['username'] ?? '') as String,
      email: j['email'] as String?,
      name: (j['name'] ?? '') as String,
      bio: (j['bio'] ?? '') as String,
      avatarUrl: (j['avatarUrl'] ?? '') as String,
      websiteUrl: (j['websiteUrl'] ?? '') as String,
      isPrivate: (j['isPrivate'] ?? false) as bool,
      followers: _asInt(j['followers']),
      following: _asInt(j['following']),
      postsCount: _asInt(j['postsCount']),
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'bio': bio,
        'avatarUrl': avatarUrl,
        'websiteUrl': websiteUrl,
        'isPrivate': isPrivate,
        'email': email,
      };
}

class Post {
  Post({
    required this.id,
    required this.authorId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption = '',
    this.location = '',
    this.isReel = false,
    this.aspectRatio = 1,
    required this.createdAt,
    this.author,
    this.viewerLiked = false,
    this.viewerSaved = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.bookmarked = false,
  });

  final String id;
  final String authorId;
  final String mediaUrl;
  final String mediaType; // IMAGE | VIDEO
  final String caption;
  final String location;
  final bool isReel;
  final double aspectRatio;
  final DateTime? createdAt;
  final User? author;
  final bool viewerLiked;
  final bool viewerSaved;
  final int likeCount;
  final int commentCount;
  final bool bookmarked;

  bool get isVideo => mediaType.toUpperCase() == 'VIDEO';

  factory Post.fromJson(Map<String, dynamic> j) {
    final authorRaw = j['author'];
    return Post(
      id: j['id'] as String,
      authorId: (j['authorId'] ?? '') as String,
      mediaUrl: (j['mediaUrl'] ?? '') as String,
      mediaType: (j['mediaType'] ?? 'IMAGE') as String,
      caption: (j['caption'] ?? '') as String,
      location: (j['location'] ?? '') as String,
      isReel: (j['isReel'] ?? false) as bool,
      aspectRatio: ((j['aspectRatio'] ?? 1) as num).toDouble(),
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      author: authorRaw is Map<String, dynamic> ? User.fromJson(authorRaw) : null,
      viewerLiked: (j['viewerLiked'] ?? false) as bool,
      viewerSaved: (j['viewerSaved'] ?? false) as bool,
      likeCount: _asInt(j['likeCount']),
      commentCount: _asInt(j['commentCount']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class Comment {
  Comment({
    required this.id,
    required this.text,
    required this.author,
    required this.createdAt,
  });
  final String id;
  final String text;
  final User author;
  final DateTime? createdAt;

  factory Comment.fromJson(Map<String, dynamic> j) {
    return Comment(
      id: j['id'] as String,
      text: (j['text'] ?? '') as String,
      author: User.fromJson(j['author'] as Map<String, dynamic>),
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
    );
  }
}

class Story {
  Story({
    required this.id,
    required this.mediaUrl,
    this.overlayText = '',
    required this.createdAt,
    this.viewed = false,
    this.viewCount = 0,
  });

  final String id;
  final String mediaUrl;
  final String overlayText;
  final DateTime? createdAt;
  final bool viewed;
  final int viewCount;

  bool get expired =>
      createdAt == null || DateTime.now().difference(createdAt!) > const Duration(hours: 24);

  factory Story.fromJson(Map<String, dynamic> j) {
    return Story(
      id: j['id'] as String,
      mediaUrl: (j['mediaUrl'] ?? '') as String,
      overlayText: (j['overlayText'] ?? '') as String,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      viewed: (j['viewed'] ?? false) as bool,
      viewCount: _asIntS(j['viewCount']),
    );
  }

  static int _asIntS(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class StoryGroup {
  StoryGroup({required this.author, required this.stories});
  final User author;
  final List<Story> stories;

  factory StoryGroup.fromJson(Map<String, dynamic> j) {
    return StoryGroup(
      author: User.fromJson(j['author'] as Map<String, dynamic>),
      stories: (j['stories'] as List).map((s) => Story.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class Conversation {
  Conversation({
    required this.id,
    required this.isGroup,
    required this.title,
    required this.participants,
    this.lastMessage,
  });

  final String id;
  final bool isGroup;
  final String title;
  final List<User> participants;
  final Message? lastMessage;

  factory Conversation.fromJson(Map<String, dynamic> j) {
    return Conversation(
      id: j['id'] as String,
      isGroup: (j['isGroup'] ?? false) as bool,
      title: (j['title'] ?? '') as String,
      participants: (j['participants'] as List).map((u) => User.fromJson(u as Map<String, dynamic>)).toList(),
      lastMessage: j['lastMessage'] is Map<String, dynamic> ? Message.fromJson(j['lastMessage'] as Map<String, dynamic>) : null,
    );
  }
}

class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.type,
    required this.content,
    this.sharedPost,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final User sender;
  final String type; // TEXT | IMAGE | VIDEO | POST_SHARE
  final String content;
  final Post? sharedPost;
  final DateTime? createdAt;

  factory Message.fromJson(Map<String, dynamic> j) {
    return Message(
      id: j['id'] as String,
      conversationId: (j['conversationId'] ?? '') as String,
      sender: User.fromJson(j['sender'] as Map<String, dynamic>),
      type: (j['type'] ?? 'TEXT') as String,
      content: (j['content'] ?? '') as String,
      sharedPost: j['sharedPost'] is Map<String, dynamic> ? Post.fromJson(j['sharedPost'] as Map<String, dynamic>) : null,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
    );
  }
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.actor,
    required this.entityId,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String type; // LIKE | COMMENT | FOLLOW | MENTION | MESSAGE
  final User actor;
  final String entityId;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: j['id'] as String,
      type: (j['type'] ?? '') as String,
      actor: User.fromJson(j['actor'] as Map<String, dynamic>),
      entityId: (j['entityId'] ?? '') as String,
      read: (j['read'] ?? false) as bool,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
    );
  }
}
