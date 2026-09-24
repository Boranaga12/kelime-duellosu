import 'package:flutter/foundation.dart';
import '../../data/models/friend.dart';
import '../../data/services/supabase_service.dart';

class FriendsController extends ChangeNotifier {
  final List<Friend> _friends = [];
  final List<Friend> _incomingRequests = [];

  List<Friend> get friends => List.unmodifiable(_friends);
  List<Friend> get incomingRequests => List.unmodifiable(_incomingRequests);
  int get onlineCount => _friends.where((f) => f.isOnline).length;

  /// Listeleri temizler (Çıkış yapıldığında)
  void clear() {
    _friends.clear();
    _incomingRequests.clear();
    notifyListeners();
  }

  /// Supabase'den arkadaş listesini çek
  Future<void> syncFriendsFromSupabase(String currentUserId) async {
    final remoteFriends = await SupabaseService.fetchFriends(userId: currentUserId);
    if (remoteFriends.isNotEmpty) {
      _friends.clear();
      _friends.addAll(remoteFriends);
      notifyListeners();
    }
  }

  /// Oyuncu kodu (#KW-XXXX) veya isim ile arkadaş ekleme
  bool addFriendByTag(
    String query, {
    String? currentUserId,
    String? currentUserName,
    String? currentUserTag,
  }) {
    final clean = query.trim();
    if (clean.isEmpty) return false;

    // Kendini arkadaş olarak ekleme kontrolü
    if ((currentUserName != null && clean.toLowerCase() == currentUserName.trim().toLowerCase()) ||
        (currentUserTag != null && clean.toLowerCase() == currentUserTag.trim().toLowerCase()) ||
        (currentUserId != null && clean.toLowerCase() == currentUserId.trim().toLowerCase())) {
      return false;
    }

    if (_friends.any((f) => f.tag.toLowerCase() == clean.toLowerCase() || f.name.toLowerCase() == clean.toLowerCase())) {
      return false;
    }

    final newFriend = Friend(
      id: 'friend_${DateTime.now().millisecondsSinceEpoch}',
      name: clean.startsWith('#') ? 'Oyuncu_${clean.replaceAll('#', '')}' : clean,
      tag: clean.startsWith('#') ? clean : '#KW-${1000 + _friends.length * 111}',
      avatarEmoji: '🎮',
      trophies: 1200,
      level: 5,
      isOnline: true,
    );

    _friends.insert(0, newFriend);

    // Supabase bağlıysa buluta da ekle
    if (currentUserId != null && SupabaseService.isInitialized) {
      SupabaseService.addFriend(
        currentUserId: currentUserId,
        targetTagOrUsername: clean,
      );
    }

    notifyListeners();
    return true;
  }

  void acceptRequest(Friend friend) {
    _incomingRequests.removeWhere((r) => r.id == friend.id);
    _friends.insert(0, friend.copyWith(isOnline: true));
    notifyListeners();
  }

  void rejectRequest(String friendId) {
    _incomingRequests.removeWhere((r) => r.id == friendId);
    notifyListeners();
  }

  void removeFriend(String friendId) {
    _friends.removeWhere((f) => f.id == friendId);
    notifyListeners();
  }
}
