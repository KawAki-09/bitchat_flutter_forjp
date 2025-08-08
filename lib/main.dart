// ファイルパス: lib/main.dart
// ★ 全面的な更新

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/mesh_service.dart'; // MeshServiceをインポート

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});


class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final prefs = ref.read(sharedPreferencesProvider);
    final theme = prefs.getString('themeMode');
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    final languageCode = prefs.getString('languageCode');
    if (languageCode != null) {
      _locale = Locale(languageCode);
    }
  }

  void _changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    final prefs = ref.read(sharedPreferencesProvider);
    if (themeMode == ThemeMode.light) {
      prefs.setString('themeMode', 'light');
    } else if (themeMode == ThemeMode.dark) {
      prefs.setString('themeMode', 'dark');
    } else {
      prefs.remove('themeMode');
    }
  }

  void _changeLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    ref.read(sharedPreferencesProvider).setString('languageCode', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitChat Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''), // Japanese
        Locale('en', ''), // English
        Locale('ko', ''), // Korean
        Locale('zh', ''), // Chinese
      ],
      home: PermissionWrapper( // ★ CHANGE: PermissionWrapperを追加
        child: AuthWrapper(
          themeMode: _themeMode,
          onThemeChanged: _changeTheme,
          onLocaleChanged: _changeLocale,
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ★ ADD: アプリ起動時に権限を確認・リクエストするための新しいウィジェット
class PermissionWrapper extends StatefulWidget {
  final Widget child;
  const PermissionWrapper({super.key, required this.child});

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _hasPermissions = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    // 必要な権限をリストアップ
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
    ];

    // 各権限の状態を確認し、許可されていなければリクエスト
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // すべての権限が許可されたかチェック
    final allGranted = statuses.values.every((status) => status.isGranted);

    setState(() {
      _hasPermissions = allGranted;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasPermissions) {
      // 権限がない場合は、設定を開くよう促す画面を表示
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Bluetoothと位置情報の権限が必要です。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: openAppSettings,
                  child: const Text('設定を開く'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // 権限があれば、子ウィジェット（アプリ本体）を表示
    return widget.child;
  }
}


class AuthWrapper extends ConsumerStatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;
  final Function(Locale) onLocaleChanged;

  const AuthWrapper({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLocaleChanged,
  });

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  String? _userNickname;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _userNickname = prefs.getString('userNickname');
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNickname(String nickname) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('userNickname', nickname);
  }

  void _handleNicknameSet(String nickname) {
    setState(() {
      _userNickname = nickname;
    });
    _saveNickname(nickname);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_userNickname == null) {
      return NicknameSetupScreen(onNicknameSet: _handleNicknameSet);
    } else {
      // ★ ADD: ChatScreenが表示されるタイミングでMeshServiceを開始
      ref.read(meshServiceProvider).start();
      return ChatScreen(
        userNickname: _userNickname!,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onLocaleChanged: widget.onLocaleChanged,
      );
    }
  }
}


class NicknameSetupScreen extends StatefulWidget {
  final Function(String) onNicknameSet;
  const NicknameSetupScreen({super.key, required this.onNicknameSet});

  @override
  State<NicknameSetupScreen> createState() => _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends State<NicknameSetupScreen> {
  final _nicknameController = TextEditingController();
  String? _errorText;

  void _submitNickname() {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() {
        _errorText = AppLocalizations.of(context)!.nicknameErrorEmpty;
      });
    } else {
      _showConfirmationDialog(nickname);
    }
  }

  void _showConfirmationDialog(String nickname) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l10n.confirmNicknameTitle),
          content: Text(l10n.confirmNicknameMessage(nickname)),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: Text(l10n.ok),
              onPressed: () {
                widget.onNicknameSet(nickname);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.welcome, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  Text(l10n.nicknameSetupDescription, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nicknameController,
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: l10n.username,
                      border: const OutlineInputBorder(),
                      errorText: _errorText,
                      counterText: "",
                    ),
                    onSubmitted: (_) => _submitNickname(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitNickname,
                    child: Text(l10n.startUsing),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// --- データモデル ---

enum MessageStatus { sending, sent, delivered, read, failed }

class Friend {
  final String id;
  final String name;
  bool isFavorite;
  bool hasUnread;

  Friend({required this.id, required this.name, this.isFavorite = false, this.hasUnread = false});
}

class ChatMessage {
  final String text;
  final DateTime timestamp;
  final bool isSentByMe;
  final MessageStatus status;

  ChatMessage({
    required this.text,
    required this.timestamp,
    required this.isSentByMe,
    this.status = MessageStatus.sending,
  });
}

class TimelineMessage {
  final Friend friend;
  final ChatMessage message;

  TimelineMessage({required this.friend, required this.message});
}

// --- Riverpodによる状態管理 ---

// フレンドリストを管理するNotifier
class FriendsNotifier extends StateNotifier<List<Friend>> {
  FriendsNotifier() : super([
    Friend(id: 'taro1', name: 'Taro', isFavorite: true),
    Friend(id: 'jiro', name: 'Jiro', hasUnread: true),
    Friend(id: 'saburo', name: 'Saburo'),
    Friend(id: 'hanako', name: 'Hanako', isFavorite: true, hasUnread: true),
    Friend(id: 'taro2', name: 'Taro#abcd'),
  ]);

  void toggleFavorite(String friendId) {
    state = [
      for (final friend in state)
        if (friend.id == friendId)
          Friend(id: friend.id, name: friend.name, isFavorite: !friend.isFavorite, hasUnread: friend.hasUnread)
        else
          friend,
    ];
  }

  void deleteFriend(String friendId) {
    state = state.where((friend) => friend.id != friendId).toList();
  }

  void setUnreadStatus(String friendId, bool hasUnread) {
    state = [
      for (final friend in state)
        if (friend.id == friendId)
          Friend(id: friend.id, name: friend.name, isFavorite: friend.isFavorite, hasUnread: hasUnread)
        else
          friend,
    ];
  }
}

// フレンドリストのProvider
final friendsProvider = StateNotifierProvider<FriendsNotifier, List<Friend>>((ref) {
  return FriendsNotifier();
});

// メッセージリストを管理するNotifier
class MessagesNotifier extends StateNotifier<List<TimelineMessage>> {
  final Ref ref;
  MessagesNotifier(this.ref) : super([]) {
    // 初期データを作成
    final friends = ref.read(friendsProvider);
    state = [
      TimelineMessage(
          friend: friends[0],
          message: ChatMessage(text: 'こんにちは！元気ですか？', timestamp: DateTime.now().subtract(const Duration(minutes: 5)), isSentByMe: false)
      ),
      TimelineMessage(
          friend: friends[1],
          message: ChatMessage(text: '例の件、了解です。進めておきます。', timestamp: DateTime.now().subtract(const Duration(hours: 1)), isSentByMe: true, status: MessageStatus.read)
      ),
      TimelineMessage(
          friend: friends[3],
          message: ChatMessage(text: '昨日はありがとうございました！とても助かりました。', timestamp: DateTime.now().subtract(const Duration(days: 1)), isSentByMe: false)
      ),
      TimelineMessage(
          friend: friends[4],
          message: ChatMessage(text: '初めまして！', timestamp: DateTime.now().subtract(const Duration(minutes: 45)), isSentByMe: false)
      ),
      TimelineMessage(
          friend: friends[0],
          message: ChatMessage(text: '明日の15時に例の場所でお願いします。', timestamp: DateTime.now().subtract(const Duration(minutes: 55)), isSentByMe: true, status: MessageStatus.delivered)
      ),
      TimelineMessage(
          friend: friends[1],
          message: ChatMessage(text: 'このメッセージは届いていません。', timestamp: DateTime.now().subtract(const Duration(minutes: 20)), isSentByMe: true, status: MessageStatus.failed)
      ),
    ];
  }

  void addMessage(String text, Friend friend) {
    final newMessage = TimelineMessage(
      friend: friend,
      message: ChatMessage(
        text: text,
        timestamp: DateTime.now(),
        isSentByMe: true,
        status: MessageStatus.sending,
      ),
    );
    state = [...state, newMessage];
  }

  void deleteMessagesForFriend(String friendId) {
    state = state.where((msg) => msg.friend.id != friendId).toList();
  }
}

// メッセージリストのProvider
final messagesProvider = StateNotifierProvider<MessagesNotifier, List<TimelineMessage>>((ref) {
  return MessagesNotifier(ref);
});

// --- 主要なUI ---

class ChatScreen extends ConsumerWidget {
  final String userNickname;
  final ThemeMode themeMode;
  final Function(ThemeMode) onThemeChanged;
  final Function(Locale) onLocaleChanged;

  ChatScreen({
    super.key,
    required this.userNickname,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLocaleChanged,
  });

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final selectedFriendProvider = StateProvider<Friend?>((ref) => null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    final allMessages = ref.watch(messagesProvider);
    final selectedFriend = ref.watch(selectedFriendProvider);
    final int unreadCount = friends.where((f) => f.hasUnread).length;
    final sortedMessages = [...allMessages]..sort((a, b) => a.message.timestamp.compareTo(b.message.timestamp));

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (selectedFriend != null) {
          if (details.primaryVelocity! > 300) {
            ref.read(selectedFriendProvider.notifier).state = null;
          } else if (details.primaryVelocity! < -300) {
            _scaffoldKey.currentState?.openEndDrawer();
          }
        } else {
          if (details.primaryVelocity! < -300) {
            _scaffoldKey.currentState?.openEndDrawer();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: selectedFriend == null
            ? _buildGeneralAppBar(context, unreadCount)
            : _buildPrivateAppBar(context, ref, unreadCount),
        endDrawer: _buildFriendListDrawer(context, ref),
        drawerEnableOpenDragGesture: false,
        endDrawerEnableOpenDragGesture: false,
        body: selectedFriend == null
            ? _buildGeneralChatBody(context, ref, sortedMessages)
            : _buildPrivateChatBody(context, ref, sortedMessages),
      ),
    );
  }

  AppBar _buildGeneralAppBar(BuildContext context, int unreadCount) {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      title: Text(l10n.mainChatTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      elevation: 0,
      scrolledUnderElevation: 0.0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        _buildThemeSwitcher(context),
        _buildLanguageSwitcher(context),
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: l10n.openFeatureExplanation,
          onPressed: () => _showFeatureExplanation(context),
        ),
        _buildFriendListButton(context, unreadCount),
        const SizedBox(width: 8),
      ],
    );
  }

  AppBar _buildPrivateAppBar(BuildContext context, WidgetRef ref, int unreadCount) {
    final l10n = AppLocalizations.of(context)!;
    final selectedFriend = ref.watch(selectedFriendProvider);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => ref.read(selectedFriendProvider.notifier).state = null,
      ),
      title: Text(selectedFriend?.name ?? l10n.privateChatTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      elevation: 0,
      scrolledUnderElevation: 0.0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        _buildThemeSwitcher(context),
        _buildLanguageSwitcher(context),
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: l10n.openFeatureExplanation,
          onPressed: () => _showFeatureExplanation(context),
        ),
        _buildFriendListButton(context, unreadCount),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildThemeSwitcher(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLight = themeMode == ThemeMode.light ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.light);

    return IconButton(
      icon: Icon(isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
      tooltip: l10n.toggleTheme,
      onPressed: () {
        final newTheme = isLight ? ThemeMode.dark : ThemeMode.light;
        onThemeChanged(newTheme);
      },
    );
  }

  Widget _buildLanguageSwitcher(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.language),
      tooltip: '言語を選択',
      onPressed: () => _showLanguagePicker(context),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                title: const Text('日本語'),
                onTap: () {
                  onLocaleChanged(const Locale('ja'));
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('English'),
                onTap: () {
                  onLocaleChanged(const Locale('en'));
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('한국어'),
                onTap: () {
                  onLocaleChanged(const Locale('ko'));
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('中文'),
                onTap: () {
                  onLocaleChanged(const Locale('zh'));
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildFriendListButton(BuildContext context, int unreadCount) {
    return Stack(
      children: [
        IconButton(
          iconSize: 36,
          icon: const Icon(Icons.people_outline),
          tooltip: AppLocalizations.of(context)!.openFriendList,
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGeneralChatBody(BuildContext context, WidgetRef ref, List<TimelineMessage> sortedMessages) {
    if (sortedMessages.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noMessages, style: const TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      reverse: true,
      itemCount: sortedMessages.length,
      itemBuilder: (context, index) {
        final reversedIndex = sortedMessages.length - 1 - index;
        final timelineMessage = sortedMessages[reversedIndex];
        return _buildChatBubble(context, ref, timelineMessage, isPrivateChat: false);
      },
    );
  }

  Widget _buildPrivateChatBody(BuildContext context, WidgetRef ref, List<TimelineMessage> allSortedMessages) {
    final selectedFriend = ref.watch(selectedFriendProvider);
    final privateMessages = allSortedMessages.where((m) => m.friend.id == selectedFriend?.id).toList();

    if (privateMessages.isEmpty) {
      return Column(
        children: [
          Expanded(child: Center(child: Text(AppLocalizations.of(context)!.noMessagesWith(selectedFriend?.name ?? ''), style: const TextStyle(color: Colors.grey, fontSize: 16)))),
          _TextComposer(
            onSubmitted: (text) {
              if (selectedFriend != null) {
                ref.read(messagesProvider.notifier).addMessage(text, selectedFriend);
              }
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: privateMessages.length,
            itemBuilder: (context, index) {
              final reversedIndex = privateMessages.length - 1 - index;
              final timelineMessage = privateMessages[reversedIndex];
              return _buildChatBubble(context, ref, timelineMessage, isPrivateChat: true);
            },
          ),
        ),
        _TextComposer(
          onSubmitted: (text) {
            if (selectedFriend != null) {
              ref.read(messagesProvider.notifier).addMessage(text, selectedFriend);
            }
          },
        ),
      ],
    );
  }

  Widget _buildChatBubble(BuildContext context, WidgetRef ref, TimelineMessage timelineMessage, {required bool isPrivateChat}) {
    final friend = timelineMessage.friend;
    final message = timelineMessage.message;
    final isSentByMe = message.isSentByMe;

    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isSentByMe ? colorScheme.primaryContainer : colorScheme.surfaceVariant;
    final textColor = isSentByMe ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () {
        if (!isPrivateChat) {
          ref.read(selectedFriendProvider.notifier).state = friend;
          ref.read(friendsProvider.notifier).setUnreadStatus(friend.id, false);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20.0),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          child: Column(
            crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isPrivateChat)
                Text(
                  isSentByMe ? 'To: ${friend.name}' : friend.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor.withOpacity(0.8)),
                ),
              if (!isPrivateChat) const SizedBox(height: 4),
              Text(
                message.text,
                style: TextStyle(fontSize: 16, color: textColor),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isSentByMe && friend.hasUnread)
                    Container(
                      margin: const EdgeInsets.only(right: 4.0),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                    ),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.6)),
                  ),
                  if (isSentByMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(message.status),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    IconData iconData;
    Color color;
    switch (status) {
      case MessageStatus.sending: iconData = Icons.access_time; color = Colors.grey; break;
      case MessageStatus.sent: iconData = Icons.done; color = Colors.grey; break;
      case MessageStatus.delivered: iconData = Icons.done_all; color = Colors.grey; break;
      case MessageStatus.read: iconData = Icons.done_all; color = Colors.blue; break;
      case MessageStatus.failed: iconData = Icons.error_outline; color = Colors.red; break;
    }
    return Icon(iconData, size: 14, color: color);
  }

  Widget _buildFriendListDrawer(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final friends = ref.watch(friendsProvider);

    final sortedFriends = [...friends]..sort((a, b) {
      if (a.hasUnread != b.hasUnread) return a.hasUnread ? -1 : 1;
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ListTile(
              leading: const Icon(Icons.account_circle, size: 36),
              title: Text(userNickname, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProfileScreen(userNickname: userNickname)));
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: sortedFriends.length,
              itemBuilder: (context, index) {
                final friend = sortedFriends[index];
                return GestureDetector(
                  onLongPress: () => _showFriendOptions(context, ref, friend),
                  child: ListTile(
                    leading: friend.hasUnread ? const Icon(Icons.mark_chat_unread, color: Colors.blue) : const Icon(Icons.person),
                    title: Text(friend.name),
                    trailing: friend.isFavorite ? const Icon(Icons.star, color: Colors.amber) : null,
                    onTap: () {
                      ref.read(selectedFriendProvider.notifier).state = friend;
                      ref.read(friendsProvider.notifier).setUnreadStatus(friend.id, false);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFriendOptions(BuildContext context, WidgetRef ref, Friend friend) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(friend.isFavorite ? Icons.star_border : Icons.star),
                title: Text(friend.isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites),
                onTap: () {
                  ref.read(friendsProvider.notifier).toggleFavorite(friend.id);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(l10n.deleteFriend, style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmation(context, ref, friend);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Friend friend) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l10n.deleteFriend),
          content: Text(l10n.deleteFriendConfirmation(friend.name)),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              onPressed: () {
                ref.read(friendsProvider.notifier).deleteFriend(friend.id);
                ref.read(messagesProvider.notifier).deleteMessagesForFriend(friend.id);

                if (ref.read(selectedFriendProvider)?.id == friend.id) {
                  ref.read(selectedFriendProvider.notifier).state = null;
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class _TextComposer extends StatefulWidget {
  final Function(String) onSubmitted;
  const _TextComposer({required this.onSubmitted});

  @override
  State<_TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<_TextComposer> {
  final _controller = TextEditingController();
  int _characterCount = 0;
  static const int _maxLength = 250;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _characterCount = _controller.text.length;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    widget.onSubmitted(text.trim());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(offset: const Offset(0, -1), blurRadius: 2, color: Colors.black.withOpacity(0.1))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: _maxLength,
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.typeMessage,
                      border: InputBorder.none,
                      counterText: "",
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _controller.text.trim().isEmpty ? null : () => _handleSubmitted(_controller.text),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0, right: 8.0),
              child: Text(
                '$_characterCount / $_maxLength',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class FeatureExplanationScreen extends StatelessWidget {
  const FeatureExplanationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyLarge;
    final titleStyle = textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    final subtitleStyle = textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.aboutThisApp),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.sectionTitleBasicMechanism, style: titleStyle),
              const SizedBox(height: 8),
              Text(l10n.sectionBodyBasicMechanism, style: bodyStyle),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text(l10n.sectionTitleScreenGuide, style: titleStyle),
              const SizedBox(height: 16),
              Text(l10n.subSectionTitleGeneralChat, style: subtitleStyle),
              const SizedBox(height: 8),
              Text(l10n.subSectionBodyGeneralChat, style: bodyStyle),
              const SizedBox(height: 16),
              Text(l10n.subSectionTitleFriendList, style: subtitleStyle),
              const SizedBox(height: 8),
              Text(l10n.subSectionBodyFriendList, style: bodyStyle),
              const SizedBox(height: 16),
              Text(l10n.subSectionTitleMessageStatus, style: subtitleStyle),
              const SizedBox(height: 12),
              _buildStatusExplanationRow(Icons.brightness_1, Colors.blue, l10n.statusUnread, l10n.statusUnreadDesc),
              _buildStatusExplanationRow(Icons.access_time, Colors.grey, l10n.statusSending, ''),
              _buildStatusExplanationRow(Icons.done, Colors.grey, l10n.statusSent, ''),
              _buildStatusExplanationRow(Icons.done_all, Colors.grey, l10n.statusDelivered, l10n.statusDeliveredDesc),
              _buildStatusExplanationRow(Icons.done_all, Colors.blue, l10n.statusRead, l10n.statusReadDesc),
              _buildStatusExplanationRow(Icons.error_outline, Colors.red, l10n.statusFailed, l10n.statusFailedDesc),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text(l10n.sectionTitlePower, style: titleStyle),
              const SizedBox(height: 16),
              Text(l10n.subSectionTitleDarkMode, style: subtitleStyle),
              const SizedBox(height: 8),
              Text(l10n.subSectionBodyDarkMode, style: bodyStyle),
              const SizedBox(height: 16),
              Text(l10n.subSectionTitleAppBehavior, style: subtitleStyle),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: bodyStyle,
                  children: <TextSpan>[
                    TextSpan(text: l10n.important, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800])),
                    TextSpan(text: l10n.importantBody1),
                    TextSpan(text: l10n.importantBody2, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800])),
                    TextSpan(text: l10n.importantBody3),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text(l10n.sectionTitleArchitecture, style: titleStyle),
              const SizedBox(height: 8),
              Text(l10n.sectionBodyArchitecture, style: bodyStyle),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text(l10n.sectionTitleSecurity, style: titleStyle),
              const SizedBox(height: 16),
              Text(l10n.subSectionTitleEncryption, style: subtitleStyle),
              const SizedBox(height: 8),
              Text(l10n.subSectionBodyEncryption, style: bodyStyle),
              const SizedBox(height: 16),
              Text(l10n.subSectionTitleDisclaimer, style: subtitleStyle),
              const SizedBox(height: 8),
              Text(l10n.subSectionBodyDisclaimer, style: bodyStyle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusExplanationRow(IconData icon, Color color, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showFeatureExplanation(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: const FeatureExplanationScreen(),
      );
    },
  );
}

class ProfileScreen extends StatelessWidget {
  final String userNickname;
  const ProfileScreen({super.key, required this.userNickname});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myUsername)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.currentUsername, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(userNickname, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 16),
              Text(l10n.usernameCannotBeChanged, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              Text(l10n.myQRCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Center(child: Container(width: 200, height: 200, color: Colors.grey[300], child: Center(child: Text(l10n.qrCodeArea)))),
              const SizedBox(height: 24),
              Center(child: ElevatedButton.icon(icon: const Icon(Icons.qr_code_scanner), label: Text(l10n.scanQRCode), onPressed: () {})),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 多言語対応 ---

abstract class AppLocalizations {
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  String get mainChatTitle;
  String get privateChatTitle;
  String get openFriendList;
  String get openFeatureExplanation;
  String get toggleTheme;
  String get noMessages;
  String noMessagesWith(String name);
  String get typeMessage;
  String get addToFavorites;
  String get removeFromFavorites;
  String get deleteFriend;
  String deleteFriendConfirmation(String name);
  String get cancel;
  String get delete;
  String get myUsername;
  String get currentUsername;
  String get usernameCannotBeChanged;
  String get myQRCode;
  String get qrCodeArea;
  String get scanQRCode;
  String get welcome;
  String get nicknameSetupDescription;
  String get username;
  String get nicknameErrorEmpty;
  String get startUsing;
  String get aboutThisApp;
  String get sectionTitleBasicMechanism;
  String get sectionBodyBasicMechanism;
  String get sectionTitleScreenGuide;
  String get subSectionTitleGeneralChat;
  String get subSectionBodyGeneralChat;
  String get subSectionTitleFriendList;
  String get subSectionBodyFriendList;
  String get subSectionTitleMessageStatus;
  String get statusUnread;
  String get statusUnreadDesc;
  String get statusSending;
  String get statusSent;
  String get statusDelivered;
  String get statusDeliveredDesc;
  String get statusRead;
  String get statusReadDesc;
  String get statusFailed;
  String get statusFailedDesc;
  String get sectionTitlePower;
  String get subSectionTitleDarkMode;
  String get subSectionBodyDarkMode;
  String get subSectionTitleAppBehavior;
  String get important;
  String get importantBody1;
  String get importantBody2;
  String get importantBody3;
  String get sectionTitleArchitecture;
  String get sectionBodyArchitecture;
  String get sectionTitleSecurity;
  String get subSectionTitleEncryption;
  String get subSectionBodyEncryption;
  String get subSectionTitleDisclaimer;
  String get subSectionBodyDisclaimer;
  String get confirmNicknameTitle;
  String confirmNicknameMessage(String name);
  String get ok;
}

class AppLocalizationsJa implements AppLocalizations {
  const AppLocalizationsJa();

  @override String get mainChatTitle => '総合チャット';
  @override String get privateChatTitle => 'プライベートチャット';
  @override String get openFriendList => 'フレンドリストを開く';
  @override String get openFeatureExplanation => '機能説明を開く';
  @override String get toggleTheme => 'テーマを切り替え';
  @override String get noMessages => 'メッセージ履歴がありません';
  @override String noMessagesWith(String name) => '$nameさんとのメッセージはありません';
  @override String get typeMessage => 'メッセージを入力...';
  @override String get addToFavorites => 'お気に入りに追加';
  @override String get removeFromFavorites => 'お気に入りから削除';
  @override String get deleteFriend => 'フレンドを削除';
  @override String deleteFriendConfirmation(String name) => '本当に「$name」をフレンドから削除しますか？\nこの操作は元に戻せません。';
  @override String get cancel => 'キャンセル';
  @override String get delete => '削除';
  @override String get myUsername => '自分のユーザー名';
  @override String get currentUsername => '現在のユーザー名';
  @override String get usernameCannotBeChanged => 'このユーザー名は変更できません。';
  @override String get myQRCode => '自分のQRコード';
  @override String get qrCodeArea => '（QRコード表示エリア）';
  @override String get scanQRCode => 'QRコードをスキャンしてフレンド追加';
  @override String get welcome => 'ようこそ！';
  @override String get nicknameSetupDescription => '最初に使用するユーザー名を設定してください。\nこの名前は後から変更できません。';
  @override String get username => 'ユーザー名';
  @override String get nicknameErrorEmpty => 'ユーザー名を入力してください';
  @override String get startUsing => '利用を開始する';
  @override String get aboutThisApp => '本アプリケーションについて';
  @override String get sectionTitleBasicMechanism => '基本的な仕組み：メッシュネットワーク';
  @override String get sectionBodyBasicMechanism => '本アプリケーションは、端末に搭載されたBluetoothおよびWi-Fi通信機能を利用し、ユーザー間で直接的な「メッシュネットワーク」を構築します。\n\n近くにいるユーザー端末が、受信したメッセージを他の端末へ自動的に中継（ホップ）する機能を備えており、この多段中継により、単一端末の電波到達範囲を超える、広域な通信網を形成します。';
  @override String get sectionTitleScreenGuide => '画面と操作の案内';
  @override String get subSectionTitleGeneralChat => '1. 総合チャット画面';
  @override String get subSectionBodyGeneralChat => 'これはアプリのメイン画面です。あなたと全フレンドとのプライベートな会話が、すべて一つのタイムラインに時系列で表示されます。これにより、個別のチャット画面を開くことなく、すべての会話の履歴をまとめて確認することができます。\n\n各メッセージをタップすると、その相手とのプライベートチャット画面に移動します。';
  @override String get subSectionTitleFriendList => '2. フレンドリストとプライベートチャット';
  @override String get subSectionBodyFriendList => '画面右上のアイコン、または画面を右から左へスワイプすることで「フレンドリスト」が開きます。リストから相手を選ぶと、その人との1対1のプライベートチャット画面に切り替わります。';
  @override String get subSectionTitleMessageStatus => '3. メッセージの状態を示すアイコン';
  @override String get statusUnread => '未読メッセージ';
  @override String get statusUnreadDesc => '受信メッセージの時刻の隣に青い点が表示されます。';
  @override String get statusSending => '送信中';
  @override String get statusSent => '送信完了';
  @override String get statusDelivered => '配達完了';
  @override String get statusDeliveredDesc => '相手の端末にメッセージが届いた状態です。';
  @override String get statusRead => '既読';
  @override String get statusReadDesc => '相手がメッセージを読みました。';
  @override String get statusFailed => '送信失敗';
  @override String get statusFailedDesc => 'メッセージを相手に届けられませんでした。';
  @override String get sectionTitlePower => '省電力とバックグラウンド動作';
  @override String get subSectionTitleDarkMode => 'ダークモードの利用';
  @override String get subSectionBodyDarkMode => '本アプリケーションはダークモードに対応しています。特に、有機EL（OLED）ディスプレイを搭載したスマートフォンでは、黒色を表示する際の消費電力がほぼゼロになります。ダークモードを利用することで、バッテリー消費を大幅に削減できる可能性があります。';
  @override String get subSectionTitleAppBehavior => 'アプリの動作とバッテリー';
  @override String get important => '【重要】';
  @override String get importantBody1 => ' 本ネットワークは、各ユーザーの端末が中継点として機能することで維持されます。メッセージの送受信および中継を行うためには、アプリケーションが常に起動している状態（バックグラウンド動作を含む）である必要があります。';
  @override String get importantBody2 => 'アプリケーションを完全に終了した場合、メッセージの受信は行われず、中継機能も停止いたします。';
  @override String get importantBody3 => 'このため、アプリ稼働中は通常の待機状態に比べてバッテリー消費が大きくなる傾向があります。また、スマートフォンのOSによる省電力機能やメモリ管理によっては、バックグラウンドでの動作が長時間続くと、まれに受信が停止することがありますので、ご留意ください。';
  @override String get sectionTitleArchitecture => '通信アーキテクチャ';
  @override String get sectionBodyArchitecture => '本アプリケーションは、通信相手のオペレーティングシステム（OS）を識別し、接続方法を動的に最適化する「インテリジェント・ハイブリッド方式」を採用しております。\n・ 同一OS間通信 (iOS ⇔ iOS, Android ⇔ Android): Wi-Fiを利用したP2P（Peer-to-Peer）接続を確立し、長距離かつ高速な通信を実現します。\n・ 異種OS間通信 (iOS ⇔ Android): 両OS間での互換性を確保するため、Bluetooth Low Energy (BLE) を用いた通信を行います。\nこのアーキテクチャにより、消費電力と通信性能のバランスを最適化し、ネットワーク全体の有効性を最大化します。';
  @override String get sectionTitleSecurity => 'セキュリティおよび免責事項';
  @override String get subSectionTitleEncryption => '暗号化について';
  @override String get subSectionBodyEncryption => 'プライベートチャットにおける通信は、Noise Protocol Frameworkに基づき、エンドツーエンドで暗号化されます。これにより、通信経路上における第三者によるメッセージの盗聴および解読は極めて困難です。';
  @override String get subSectionTitleDisclaimer => '免責事項';
  @override String get subSectionBodyDisclaimer => '本アプリケーションは「現状有姿で」提供されるものであり、明示または黙示を問わず、その機能、信頼性、正確性、特定目的への適合性について一切の保証をいたしません。本アプリケーションの利用は、ユーザー自身の判断と責任において行われるものとします。本アプリケーションを利用して送受信される情報の内容、およびその結果について、開発者は一切関与せず、責任を負いません。\n\n本アプリケーションの利用、または利用できなかったことによって生じたいかなる直接的、間接的、付随的、結果的損害（データの消失、通信の失敗、逸失利益を含むがこれに限らない）について、開発者は一切の責任を負いません。通信内容は保証されず、重要な情報の伝達に際しては、ユーザー自身の責任で他の手段も確保してください。\n\nまた、本アプリケーションは第三者機関によるセキュリティ監査を受けておりません。機密情報、その他漏洩によって重大な損害が生じる可能性のある情報の送受信には、本アプリケーションを使用しないでください。';
  @override String get confirmNicknameTitle => 'ユーザー名の確認';
  @override String confirmNicknameMessage(String name) => '「$name」に設定しますか？\nこの名前は後から変更できません。';
  @override String get ok => 'OK';
}

class AppLocalizationsEn implements AppLocalizations {
  const AppLocalizationsEn();

  @override String get mainChatTitle => 'General Chat';
  @override String get privateChatTitle => 'Private Chat';
  @override String get openFriendList => 'Open Friend List';
  @override String get openFeatureExplanation => 'Open Feature Explanation';
  @override String get toggleTheme => 'Toggle Theme';
  @override String get noMessages => 'No message history';
  @override String noMessagesWith(String name) => 'No messages with $name';
  @override String get typeMessage => 'Type a message...';
  @override String get addToFavorites => 'Add to favorites';
  @override String get removeFromFavorites => 'Remove from favorites';
  @override String get deleteFriend => 'Delete Friend';
  @override String deleteFriendConfirmation(String name) => 'Are you sure you want to delete "$name" from your friends?\nThis action cannot be undone.';
  @override String get cancel => 'Cancel';
  @override String get delete => 'Delete';
  @override String get myUsername => 'My Username';
  @override String get currentUsername => 'Current Username';
  @override String get usernameCannotBeChanged => 'This username cannot be changed.';
  @override String get myQRCode => 'My QR Code';
  @override String get qrCodeArea => '(QR Code Area)';
  @override String get scanQRCode => 'Scan QR Code to Add Friend';
  @override String get welcome => 'Welcome!';
  @override String get nicknameSetupDescription => 'Please set your username to start.\nThis name cannot be changed later.';
  @override String get username => 'Username';
  @override String get nicknameErrorEmpty => 'Please enter a username';
  @override String get startUsing => 'Start Using';
  @override String get aboutThisApp => 'About This Application';
  @override String get sectionTitleBasicMechanism => 'Basic Mechanism: Mesh Network';
  @override String get sectionBodyBasicMechanism => 'This application utilizes the device\'s built-in Bluetooth and Wi-Fi capabilities to construct a direct "mesh network" among users.\n\nNearby user devices automatically relay (hop) received messages to other devices. This multi-hop relaying forms a wide-area communication network that extends beyond the radio range of a single device.';
  @override String get sectionTitleScreenGuide => 'Screen and Operation Guide';
  @override String get subSectionTitleGeneralChat => '1. General Chat Screen';
  @override String get subSectionBodyGeneralChat => 'This is the main screen of the app. All your private conversations with all your friends are displayed in a single chronological timeline. This allows you to review the history of all conversations at once without opening individual chat screens.\n\nA tap on any message will take you to the private chat screen with that person.';
  @override String get subSectionTitleFriendList => '2. Friend List and Private Chat';
  @override String get subSectionBodyFriendList => 'The "Friend List" can be opened by tapping the icon in the top right corner or by swiping from right to left on the screen. Selecting a person from the list will switch to a one-on-one private chat screen with them.';
  @override String get subSectionTitleMessageStatus => '3. Message Status Icons';
  @override String get statusUnread => 'Unread Message';
  @override String get statusUnreadDesc => 'A blue dot next to the time of a received message indicates that it has not yet been opened in a private chat.';
  @override String get statusSending => 'Sending';
  @override String get statusSent => 'Sent';
  @override String get statusDelivered => 'Delivered';
  @override String get statusDeliveredDesc => 'The message has been delivered to the recipient\'s device.';
  @override String get statusRead => 'Read';
  @override String get statusReadDesc => 'The recipient has read the message.';
  @override String get statusFailed => 'Failed';
  @override String get statusFailedDesc => 'The message could not be delivered to the recipient.';
  @override String get sectionTitlePower => 'Power Saving and Background Operation';
  @override String get subSectionTitleDarkMode => 'Using Dark Mode';
  @override String get subSectionBodyDarkMode => 'This application supports dark mode. Especially on smartphones equipped with an Organic EL (OLED) display, the power consumption for displaying black is nearly zero. Using dark mode can significantly reduce battery consumption.';
  @override String get subSectionTitleAppBehavior => 'App Behavior and Battery';
  @override String get important => '[IMPORTANT]';
  @override String get importantBody1 => ' This network is maintained by each user\'s device acting as a relay point. To send, receive, and relay messages, the application must be running at all times (including in the background). ';
  @override String get importantBody2 => 'If you completely close the application, you will not receive messages, and the relay function will also stop. ';
  @override String get importantBody3 => 'For this reason, battery consumption tends to be higher than in a normal standby state while the app is running. Also, please be aware that depending on the smartphone\'s OS power-saving features and memory management, reception may occasionally stop if the app runs in the background for an extended period.';
  @override String get sectionTitleArchitecture => 'Communication Architecture';
  @override String get sectionBodyArchitecture => 'This application employs an "Intelligent Hybrid Method" that identifies the operating system (OS) of the communicating party and dynamically optimizes the connection method.\n・ Same OS Communication (iOS ⇔ iOS, Android ⇔ Android): Establishes a P2P (Peer-to-Peer) connection using Wi-Fi for long-range and high-speed communication.\n・ Cross-OS Communication (iOS ⇔ Android): Uses Bluetooth Low Energy (BLE) to ensure compatibility between both OSs.\nThis architecture maximizes the overall effectiveness of the network by optimizing the balance between power consumption and communication performance.';
  @override String get sectionTitleSecurity => 'Security and Disclaimer';
  @override String get subSectionTitleEncryption => 'About Encryption';
  @override String get subSectionBodyEncryption => 'Communication in private chats is end-to-end encrypted based on the Noise Protocol Framework. This makes it extremely difficult for third parties to intercept and decrypt messages on the communication path.';
  @override String get subSectionTitleDisclaimer => 'Disclaimer';
  @override String get subSectionBodyDisclaimer => 'This application is provided "as is," without warranty of any kind, express or implied, including but not limited to the warranties of functionality, reliability, accuracy, or fitness for a particular purpose. The use of this application is at the user\'s own judgment and risk. The developer is not involved in and is not responsible for the content of information sent or received using this application, nor for the results thereof.\n\nThe developer shall not be liable for any direct, indirect, incidental, or consequential damages (including, but not limited to, loss of data, communication failure, or lost profits) arising out of the use or inability to use this application. Communication content is not guaranteed, and users should secure other means of communication for important information at their own risk.\n\nFurthermore, this application has not undergone a security audit by a third-party organization. Please do not use this application for the transmission of confidential information or any other information that could result in significant damage if leaked.';
  @override String get confirmNicknameTitle => 'Confirm Username';
  @override String confirmNicknameMessage(String name) => 'Set username to "$name"?\nThis name cannot be changed later.';
  @override String get ok => 'OK';
}

class AppLocalizationsKo implements AppLocalizations {
  const AppLocalizationsKo();

  @override String get mainChatTitle => '전체 채팅';
  @override String get privateChatTitle => '개인 채팅';
  @override String get openFriendList => '친구 목록 열기';
  @override String get openFeatureExplanation => '기능 설명 열기';
  @override String get toggleTheme => '테마 전환';
  @override String get noMessages => '메시지 기록이 없습니다';
  @override String noMessagesWith(String name) => '$name님과의 메시지가 없습니다';
  @override String get typeMessage => '메시지 입력...';
  @override String get addToFavorites => '즐겨찾기에 추가';
  @override String get removeFromFavorites => '즐겨찾기에서 삭제';
  @override String get deleteFriend => '친구 삭제';
  @override String deleteFriendConfirmation(String name) => '정말로 "$name"님을 친구에서 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.';
  @override String get cancel => '취소';
  @override String get delete => '삭제';
  @override String get myUsername => '내 사용자 이름';
  @override String get currentUsername => '현재 사용자 이름';
  @override String get usernameCannotBeChanged => '이 사용자 이름은 변경할 수 없습니다.';
  @override String get myQRCode => '내 QR 코드';
  @override String get qrCodeArea => '(QR 코드 영역)';
  @override String get scanQRCode => 'QR 코드를 스캔하여 친구 추가';
  @override String get welcome => '환영합니다!';
  @override String get nicknameSetupDescription => '시작하려면 사용자 이름을 설정하십시오.\n이 이름은 나중에 변경할 수 없습니다.';
  @override String get username => '사용자 이름';
  @override String get nicknameErrorEmpty => '사용자 이름을 입력하십시오';
  @override String get startUsing => '사용 시작';
  @override String get aboutThisApp => '이 애플리케이션에 대하여';
  @override String get sectionTitleBasicMechanism => '기본 메커니즘: 메시 네트워크';
  @override String get sectionBodyBasicMechanism => '이 애플리케이션은 단말기에 내장된 Bluetooth 및 Wi-Fi 통신 기능을 이용하여 사용자 간에 직접적인 "메시 네트워크"를 구축합니다。\n\n가까운 사용자 단말기가 수신한 메시지를 다른 단말기로 자동으로 중계(홉)하는 기능을 갖추고 있으며, 이 다단계 중계를 통해 단일 단말기의 전파 도달 범위를 초과하는 광역 통신망을 형성합니다。';
  @override String get sectionTitleScreenGuide => '화면 및 조작 안내';
  @override String get subSectionTitleGeneralChat => '1. 전체 채팅 화면';
  @override String get subSectionBodyGeneralChat => '이것은 앱의 메인 화면입니다. 모든 친구와의 개인적인 대화가 하나의 타임라인에 시간순으로 표시됩니다. 이를 통해 개별 채팅 화면을 열지 않고도 모든 대화 기록을 한 번에 확인할 수 있습니다.\n\n각 메시지를 탭하면 해당 상대방과의 개인 채팅 화면으로 이동합니다.';
  @override String get subSectionTitleFriendList => '2. 친구 목록 및 개인 채팅';
  @override String get subSectionBodyFriendList => '화면 오른쪽 상단의 아이콘을 탭하거나 화면을 오른쪽에서 왼쪽으로 스와이프하여 "친구 목록"을 열 수 있습니다. 목록에서 상대를 선택하면 그 사람과의 일대일 개인 채팅 화면으로 전환됩니다.';
  @override String get subSectionTitleMessageStatus => '3. 메시지 상태 아이콘';
  @override String get statusUnread => '읽지 않은 메시지';
  @override String get statusUnreadDesc => '수신된 메시지 시간 옆에 파란색 점이 표시되면 아직 개인 채팅에서 열지 않았음을 나타냅니다.';
  @override String get statusSending => '전송 중';
  @override String get statusSent => '전송 완료';
  @override String get statusDelivered => '전달 완료';
  @override String get statusDeliveredDesc => '메시지가 상대방의 단말기에 도착했습니다.';
  @override String get statusRead => '읽음';
  @override String get statusReadDesc => '상대방이 메시지를 읽었습니다.';
  @override String get statusFailed => '전송 실패';
  @override String get statusFailedDesc => '메시지를 상대방에게 전달하지 못했습니다.';
  @override String get sectionTitlePower => '절전 및 백그라운드 작동';
  @override String get subSectionTitleDarkMode => '다크 모드 사용';
  @override String get subSectionBodyDarkMode => '이 애플리케이션은 다크 모드를 지원합니다. 특히 유기 EL(OLED) 디스플레이가 장착된 스마트폰에서는 검은색을 표시할 때의 전력 소비가 거의 0이 됩니다. 다크 모드를 사용하면 배터리 소모를 크게 줄일 수 있습니다.';
  @override String get subSectionTitleAppBehavior => '앱 동작 및 배터리';
  @override String get important => '[중요]';
  @override String get importantBody1 => ' 이 네트워크는 각 사용자의 단말기가 중계 지점 역할을 함으로써 유지됩니다. 메시지를 송수신하고 중계하려면 애플리케이션이 항상 실행 중이어야 합니다(백그라운드 포함). ';
  @override String get importantBody2 => '애플리케이션을 완전히 종료하면 메시지를 수신할 수 없으며 중계 기능도 중지됩니다. ';
  @override String get importantBody3 => '이 때문에 앱이 실행 중일 때는 일반 대기 상태보다 배터리 소모가 더 많은 경향이 있습니다. 또한 스마트폰 OS의 절전 기능이나 메모리 관리에 따라 백그라운드에서 장시간 작동하면 수신이 중단될 수 있으니 유의하시기 바랍니다.';
  @override String get sectionTitleArchitecture => '통신 아키텍처';
  @override String get sectionBodyArchitecture => '이 애플리케이션은 통신 상대의 운영 체제(OS)를 식별하고 연결 방법을 동적으로 최적화하는 "지능형 하이브리드 방식"을 채택하고 있습니다.\n・ 동일 OS 간 통신 (iOS ⇔ iOS, Android ⇔ Android): Wi-Fi를 이용한 P2P(Peer-to-Peer) 연결을 설정하여 장거리 및 고속 통신을 실현합니다。\n・ 이종 OS 간 통신 (iOS ⇔ Android): 두 OS 간의 호환성을 확보하기 위해 Bluetooth Low Energy(BLE)를 이용한 통신을 수행합니다。\n이 아키텍처는 전력 소비와 통신 성능의 균형을 최적화하여 네트워크 전체의 효율성을 극대화합니다。';
  @override String get sectionTitleSecurity => '보안 및 면책 조항';
  @override String get subSectionTitleEncryption => '암호화에 대하여';
  @override String get subSectionBodyEncryption => '개인 채팅에서의 통신은 Noise Protocol Framework에 기반하여 종단 간 암호화됩니다. 이를 통해 통신 경로상의 제3자에 의한 메시지 도청 및 해독이 극히 어렵습니다.';
  @override String get subSectionTitleDisclaimer => '면책 조항';
  @override String get subSectionBodyDisclaimer => '이 애플리케이션은 "있는 그대로" 제공되며, 명시적이든 묵시적이든 기능, 신뢰성, 정확성 또는 특정 목적에의 적합성에 대한 어떠한 보증도 하지 않습니다. 이 애플리케이션의 사용은 사용자 자신의 판단과 책임 하에 이루어집니다. 개발자는 이 애플리케이션을 사용하여 송수신되는 정보의 내용 및 그 결과에 관여하지 않으며 책임지지 않습니다.\n\n개발자는 이 애플리케이션의 사용 또는 사용 불능으로 인해 발생하는 어떠한 직접적, 간접적, 부수적 또는 결과적 손해(데이터 손실, 통신 실패 또는 이익 손실을 포함하되 이에 국한되지 않음)에 대해 책임을 지지 않습니다. 통신 내용은 보장되지 않으며, 중요한 정보 전달 시에는 사용자 자신의 책임 하에 다른 수단을 확보해야 합니다.\n\n또한 이 애플리케이션은 제3자 기관의 보안 감사를 받지 않았습니다. 기밀 정보나 유출될 경우 심각한 손해를 초래할 수 있는 기타 정보의 송수신에는 이 애플리케이션을 사용하지 마십시오.';
  @override String get confirmNicknameTitle => '사용자 이름 확인';
  @override String confirmNicknameMessage(String name) => '"$name"(으)로 설정하시겠습니까?\n이 이름은 나중에 변경할 수 없습니다.';
  @override String get ok => '확인';
}

class AppLocalizationsZh implements AppLocalizations {
  const AppLocalizationsZh();

  @override String get mainChatTitle => '综合聊天';
  @override String get privateChatTitle => '私人聊天';
  @override String get openFriendList => '打开好友列表';
  @override String get openFeatureExplanation => '打开功能说明';
  @override String get toggleTheme => '切换主题';
  @override String get noMessages => '没有消息记录';
  @override String noMessagesWith(String name) => '没有与$name的消息';
  @override String get typeMessage => '输入消息...';
  @override String get addToFavorites => '添加到收藏夹';
  @override String get removeFromFavorites => '从收藏夹中删除';
  @override String get deleteFriend => '删除好友';
  @override String deleteFriendConfirmation(String name) => '您确定要从好友中删除“$name”吗？\n此操作无法撤销。';
  @override String get cancel => '取消';
  @override String get delete => '删除';
  @override String get myUsername => '我的用户名';
  @override String get currentUsername => '当前用户名';
  @override String get usernameCannotBeChanged => '此用户名无法更改。';
  @override String get myQRCode => '我的二维码';
  @override String get qrCodeArea => '（二维码区域）';
  @override String get scanQRCode => '扫描二维码添加好友';
  @override String get welcome => '欢迎！';
  @override String get nicknameSetupDescription => '请设置您的用户名以开始。\n此名称以后无法更改。';
  @override String get username => '用户名';
  @override String get nicknameErrorEmpty => '请输入用户名';
  @override String get startUsing => '开始使用';
  @override String get aboutThisApp => '关于此应用程序';
  @override String get sectionTitleBasicMechanism => '基本机制：网状网络';
  @override String get sectionBodyBasicMechanism => '本应用程序利用设备内置的蓝牙和Wi-Fi通信功能，在用户之间直接构建一个“网状网络”。\n\n附近的用户设备会自动将收到的消息中继（跳）到其他设备。这种多跳中继形成了一个超出单个设备无线电范围的广域通信网络。';
  @override String get sectionTitleScreenGuide => '屏幕和操作指南';
  @override String get subSectionTitleGeneralChat => '1. 综合聊天屏幕';
  @override String get subSectionBodyGeneralChat => '这是应用程序的主屏幕。您与所有好友的所有私人对话都显示在一个按时间顺序排列的时间轴上。这使您可以一次性查看所有对话的历史记录，而无需打开单个聊天屏幕。\n\n点击任何消息将带您进入与该人的私人聊天屏幕。';
  @override String get subSectionTitleFriendList => '2. 好友列表和私人聊天';
  @override String get subSectionBodyFriendList => '可以通过点击右上角的图标或从右向左滑动屏幕来打开“好友列表”。从列表中选择一个人将切换到与该人的一对一私人聊天屏幕。';
  @override String get subSectionTitleMessageStatus => '3. 消息状态图标';
  @override String get statusUnread => '未读消息';
  @override String get statusUnreadDesc => '收到的消息时间旁边的一个蓝点表示该消息尚未在私人聊天中打开。';
  @override String get statusSending => '发送中';
  @override String get statusSent => '已发送';
  @override String get statusDelivered => '已送达';
  @override String get statusDeliveredDesc => '消息已送达收件人的设备。';
  @override String get statusRead => '已读';
  @override String get statusReadDesc => '收件人已阅读该消息。';
  @override String get statusFailed => '发送失败';
  @override String get statusFailedDesc => '无法将消息发送给收件人。';
  @override String get sectionTitlePower => '省电和后台操作';
  @override String get subSectionTitleDarkMode => '使用暗黑模式';
  @override String get subSectionBodyDarkMode => '本应用程序支持暗黑模式。特别是在配备有机EL（OLED）显示屏的智能手机上，显示黑色的功耗几乎为零。使用暗黑模式可以显著降低电池消耗。';
  @override String get subSectionTitleAppBehavior => '应用程序行为和电池';
  @override String get important => '【重要】';
  @override String get importantBody1 => ' 该网络由每个用户的设备充当中继点来维护。为了发送、接收和中继消息，应用程序必须始终在运行（包括在后台）。 ';
  @override String get importantBody2 => '如果您完全关闭应用程序，您将无法接收消息，中继功能也将停止。 ';
  @override String get importantBody3 => '因此，在应用程序运行时，电池消耗往往高于正常待机状态。此外，请注意，根据智能手机操作系统的省电功能和内存管理，如果应用程序在后台长时间运行，接收有时可能会停止。';
  @override String get sectionTitleArchitecture => '通信架构';
  @override String get sectionBodyArchitecture => '本应用程序采用“智能混合方法”，可识别通信方的操作系统（OS）并动态优化连接方法。\n・ 相同操作系统之间的通信（iOS ⇔ iOS，Android ⇔ Android）：使用Wi-Fi建立P2P（点对点）连接，以实现远程和高速通信。\n・ 跨操作系统通信（iOS ⇔ Android）：使用低功耗蓝牙（BLE）以确保两个操作系统之间的兼容性。\n这种架构通过优化功耗和通信性能之间的平衡来最大化网络的整体有效性。';
  @override String get sectionTitleSecurity => '安全和免責聲明';
  @override String get subSectionTitleEncryption => '关于加密';
  @override String get subSectionBodyEncryption => '私人聊天中的通信基于Noise协议框架进行端到端加密。这使得第三方极难在通信路径上拦截和解密消息。';
  @override String get subSectionTitleDisclaimer => '免責聲明';
  @override String get subSectionBodyDisclaimer => '本應用程式按「原樣」提供，不作任何明示或暗示的保證，包括但不限於功能性、可靠性、準確性或特定用途適用性的保證。用戶應自行判斷並承擔使用本應用程式的風險。開發者不參與且不負責使用本應用程式發送或接收的資訊內容及其結果。\n\n對於因使用或無法使用本應用程式而導致的任何直接、間接、附帶或後果性損害（包括但不限於數據丟失、通信失敗或利潤損失），開發者概不負責。通信內容不作保證，用戶在傳輸重要資訊時應自行承擔確保其他通信方式的責任。\n\n此外，本應用程式未經第三方組織的安全審計。請勿使用本應用程式傳輸機密資訊或任何其他如果洩露可能導致重大損害的資訊。';
  @override String get confirmNicknameTitle => '确认用户名';
  @override String confirmNicknameMessage(String name) => '要设置为“$name”吗？\n此名称以后无法更改。';
  @override String get ok => '确定';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'en':
        return const AppLocalizationsEn();
      case 'ja':
        return const AppLocalizationsJa();
      case 'ko':
        return const AppLocalizationsKo();
      case 'zh':
        return const AppLocalizationsZh();
      default:
        return const AppLocalizationsEn();
    }
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
