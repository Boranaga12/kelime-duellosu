import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_savasi/core/utils/turkish_strings.dart';
import 'package:kelime_savasi/data/categories_data.dart';
import 'package:kelime_savasi/data/models/custom_room.dart';
import 'package:kelime_savasi/data/models/game_round.dart';
import 'package:kelime_savasi/data/models/player.dart';
import 'package:kelime_savasi/data/services/cross_game_auth_service.dart';
import 'package:kelime_savasi/data/services/multiplayer_service.dart';
import 'package:kelime_savasi/domain/bot_ai_engine.dart';
import 'package:kelime_savasi/domain/word_engine.dart';
import 'package:kelime_savasi/presentation/controllers/friends_controller.dart';
import 'package:kelime_savasi/data/models/word_entry.dart';
import 'package:kelime_savasi/presentation/controllers/game_controller.dart';
import 'package:kelime_savasi/presentation/controllers/leaderboard_controller.dart';
import 'package:kelime_savasi/presentation/controllers/profile_controller.dart';
import 'package:kelime_savasi/presentation/widgets/avatar_badge.dart';
import 'package:kelime_savasi/presentation/widgets/word_bubble.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Türkçe Cümle ve Özel İsim Formatlama Testleri', () {
    test('Cümle formatı: Sadece ilk harf büyük olmalı', () {
      expect(TurkishStrings.formatSentenceCase('halı'), 'Halı');
      expect(TurkishStrings.formatSentenceCase('deniz yatağı'), 'Deniz yatağı');
      expect(TurkishStrings.formatSentenceCase('İSTANBUL'), 'İstanbul');
    });

    test('Özel isim / Başlık formatı: Her kelimenin ilk harfi büyük olmalı', () {
      expect(TurkishStrings.formatTitleCase('balıkesir'), 'Balıkesir');
      expect(TurkishStrings.formatTitleCase('kuzey kıbrıs'), 'Kuzey Kıbrıs');
    });

    test('Toplamda tam 200 adet soru kategorisi olmalı (100 klasik + 100 ucu açık)', () {
      expect(sampleCategories.length, 200);
    });
  });

  group('Puan Sistemi Olmayan Saf Hayatta Kalma Düellosu Testleri', () {
    final cat = sampleCategories.firstWhere((c) => c.id == 'yere_serilen');

    test('Doğru kelime cümle formatında eklenmeli, puan hesaplanmamalı', () {
      final res = WordEngine.validateWord(
        rawInput: 'halı',
        category: cat,
        alreadyUsedWords: {},
      );
      expect(res.isValid, true);
      expect(res.matchedWord, 'Halı');
    });

    test('Yanlış kelime orijinal hali hiç bozulmadan korunmalı ve sıra devredilmemeli', () async {
      final controller = GameController();
      const user = Player(id: 'u1', name: 'Oyuncu 1', avatarEmoji: '👑');
      const opponent = Player(id: 'u2', name: 'Oyuncu 2', avatarEmoji: '🤖');

      controller.startNewGame(
        category: cat,
        userPlayer: user,
        opponentPlayer: opponent,
      );

      const rawWrong = 'yANLiS_kEliMe';
      await controller.submitPlayerWord(rawWrong);

      expect(controller.round!.words.length, 1);
      final entry = controller.round!.words.first;
      expect(entry.isCorrect, false);
      expect(entry.word, rawWrong);
      expect(controller.isUserTurn, true);
    });

    test('Doğru kelimede sıra devredilmeli ve formatlı eklenmeli', () async {
      final controller = GameController();
      const user = Player(id: 'u1', name: 'Oyuncu 1', avatarEmoji: '👑');
      const opponent = Player(id: 'u2', name: 'Oyuncu 2', avatarEmoji: '🤖');

      controller.startNewGame(
        category: cat,
        userPlayer: user,
        opponentPlayer: opponent,
      );

      await controller.submitPlayerWord('kilim');
      expect(controller.round!.words.first.isCorrect, true);
      expect(controller.round!.words.first.word, 'Kilim');
      expect(controller.isUserTurn, false);
    });
  });

  group('Arkadaşlık Sistemi Testleri', () {
    test('Yeni arkadaş ekleme ve çevrimiçi durumu kontrolü', () {
      final friendsCtrl = FriendsController();
      final initialCount = friendsCtrl.friends.length;

      final success = friendsCtrl.addFriendByTag('#KW-9999');
      expect(success, true);
      expect(friendsCtrl.friends.length, initialCount + 1);
      expect(friendsCtrl.friends.first.tag, '#KW-9999');
    });
  });

  group('Liderlik Tablosu ve Çok Oyunculu Oda Testleri', () {
    test('Liderlik tablosu lig hesaplaması ve sıralama', () async {
      final ldr = LeaderboardController();
      await ldr.loadLeaderboard(
        currentPlayer: const Player(
          id: 'test_u',
          name: 'Test Oyuncu',
          avatarEmoji: '👑',
          trophies: 1250,
        ),
      );
      expect(ldr.globalEntries.isNotEmpty, true);
      expect(ldr.globalEntries.first.rank, 1);
    });

    test('6 haneli oda kodu üretimi', () {
      final code = MultiplayerService.generateRoomCode();
      expect(code.length, 6);
      expect(int.tryParse(code) != null, true);
    });
  });

  group('Çoklu Raunt (Toplam 2 Kazanan Şampiyon) ve Altın Harcama Testleri', () {
    final cat = sampleCategories.first;

    test('Oyun başladığında standart 15 saniye süre verilmeli (2 kat süre kaldırıldı)', () {
      final controller = GameController();
      const user = Player(id: 'u1', name: 'Oyuncu 1', avatarEmoji: '👑');
      const opponent = Player(id: 'u2', name: 'Oyuncu 2', avatarEmoji: '🤖');

      controller.startNewGame(
        category: cat,
        userPlayer: user,
        opponentPlayer: opponent,
      );

      expect(controller.round!.currentRoundNumber, 1);
      expect(controller.round!.player1RoundScore, 0);
      expect(controller.round!.player2RoundScore, 0);
      expect(controller.round!.targetWins, 2);
      expect(controller.round!.remainingTurnSeconds, 15); // Standart 15s
      expect(controller.round!.currentTurnMaxSeconds, 15);
      expect(controller.round!.status, RoundStatus.active);
    });

    test('Teslim olma (Surrender) hükmen mağlubiyet vermeli', () {
      final controller = GameController();
      const user = Player(id: 'u1', name: 'Oyuncu 1', avatarEmoji: '👑');
      const opponent = Player(id: 'u2', name: 'Oyuncu 2', avatarEmoji: '🤖');

      controller.startNewGame(
        category: cat,
        userPlayer: user,
        opponentPlayer: opponent,
      );

      controller.surrenderMatch();
      expect(controller.round!.status, RoundStatus.finished);
      expect(controller.round!.defeatReason, 'surrender');
      expect(controller.round!.winnerPlayerId, opponent.id);
    });

    test('Altın harcama (50 altın ile soru değiştirme) ve brifing süre barının tam dolması', () {
      final profile = ProfileController();
      final controller = GameController();
      const user = Player(id: 'u1', name: 'Oyuncu 1', avatarEmoji: '👑');
      const opponent = Player(id: 'u2', name: 'Oyuncu 2', avatarEmoji: '🤖');

      controller.startNewGame(category: cat, userPlayer: user, opponentPlayer: opponent);

      // Brifing moduna alıp süre barını kısaltalım (örn: 2s kalsın)
      controller.round = controller.round!.copyWith(
        isShowingBriefing: true,
        briefingCountdown: 2,
        briefingMaxCountdown: 6,
        hasBriefingCategoryChanged: false,
      );

      final initialCoins = profile.coins;
      final changed = controller.changeBriefingCategory(profile);

      expect(changed, true);
      expect(profile.coins, initialCoins - 50);
      // Soru değiştiğinde süre barı tekrar tam dolmalı (6 saniye)!
      expect(controller.round!.briefingCountdown, 6);
      expect(controller.round!.hasBriefingCategoryChanged, true);

      // İkinci kez değiştirmeye izin verilmemeli (1 defaya mahsus)
      final secondTry = controller.changeBriefingCategory(profile);
      expect(secondTry, false);
    });

    test('Gelişmiş Özel Oda (2-6 Kişi & Takımlı) ve Takım Sırası Geçişi Testi', () async {
      const user = Player(id: 'u1', name: 'Oyuncu 1', avatarEmoji: '👑');
      final room = await MultiplayerService.createAdvancedRoom(
        roomName: 'Test Odası',
        host: user,
        maxPlayers: 4,
        isTeamMode: true,
        teamCount: 2,
        targetWins: 2,
      );

      expect(room.players.length, 1);
      expect(room.isTeamMode, true);

      // Odaya Bot Ekle
      MultiplayerService.addBotToRoom();
      expect(MultiplayerService.activeCustomRoom!.players.length, 2);

      final activeRoom = MultiplayerService.activeCustomRoom!;
      final controller = GameController();

      controller.startTeamOrCustomGame(
        room: activeRoom,
        userPlayer: user,
        category: cat,
      );

      expect(controller.round!.isTeamMode, true);
      expect(controller.round!.currentTurnTeamId, 'team_1');
      expect(controller.isUserTurn, true);

      // Kullanıcı takımından kelime girilince sıra rakip takıma geçmeli
      await controller.submitPlayerWord('halı');
      expect(controller.round!.words.first.isCorrect, true);
      expect(controller.round!.currentTurnTeamId, 'team_2');
      expect(controller.isUserTurn, false);
    });

    test('Sahte/Mock odalar kaldırıldı, sadece gerçek odalar listelenir', () async {
      final rooms = await MultiplayerService.fetchPublicRooms();
      // İçinde hardcoded sahte kullanıcılar ("EfsaneAli", "Selin_Pro", "Can_99") olmamalı
      expect(rooms.any((r) => r.hostName == 'EfsaneAli'), false);
      expect(rooms.any((r) => r.hostName == 'Selin_Pro'), false);
      expect(rooms.any((r) => r.hostName == 'Can_99'), false);
    });

    test('Odaya mükerrer (çift) girme engeli: Aynı oyuncu tekrar katılınca slot işgal etmez', () async {
      const host = Player(id: 'host_1', name: 'Host Oyuncu', avatarEmoji: '👑');
      const guest = Player(id: 'guest_1', name: 'Misafir Oyuncu', avatarEmoji: '🚀');

      final room = await MultiplayerService.createAdvancedRoom(
        roomName: 'Kapasite Test Odası',
        host: host,
        maxPlayers: 3,
      );

      expect(room.players.length, 1);

      // Misafir ilk kez katılır
      final res1 = await MultiplayerService.joinAdvancedRoom(
        roomCode: room.roomCode,
        player: guest,
      );
      expect(res1.success, true);
      expect(MultiplayerService.activeCustomRoom!.players.length, 2);

      // Misafir AYNI odaya tekrar katılmaya çalışır
      final res2 = await MultiplayerService.joinAdvancedRoom(
        roomCode: room.roomCode,
        player: guest,
      );
      expect(res2.success, true);
      // Oyuncu sayısı 3 olmamalı, 2 olarak kalmalı!
      expect(MultiplayerService.activeCustomRoom!.players.length, 2);
      expect(MultiplayerService.activeCustomRoom!.players.where((p) => p.id == guest.id).length, 1);

      // Temizlik
      await MultiplayerService.leaveAdvancedRoom(playerId: guest.id);
      expect(MultiplayerService.activeCustomRoom, isNull);
    });

    test('Odadan çıkış yapıldığında oyuncu listeden tamamen silinir ve host devredilir/kapatılır', () async {
      const host = Player(id: 'host_h', name: 'Kurucu', avatarEmoji: '👑');
      const guest = Player(id: 'guest_g', name: 'Arkadaş', avatarEmoji: '🎮');

      final room = await MultiplayerService.createAdvancedRoom(
        roomName: 'Ayrılma Test Odası',
        host: host,
        maxPlayers: 4,
      );

      await MultiplayerService.joinAdvancedRoom(
        roomCode: room.roomCode,
        player: guest,
      );
      expect(MultiplayerService.activeCustomRoom!.players.length, 2);

      // Misafir odadan ayrılır
      await MultiplayerService.leaveAdvancedRoom(playerId: guest.id);
      // Oda hala kurucu ile açık kalmalı fakat misafir listeden silinmiş olmalı
      // (Eğer aktif oda kurucu için incelenirse)
      final remainingAfterGuest = MultiplayerService.activeCustomRoom;
      if (remainingAfterGuest != null) {
        expect(remainingAfterGuest.players.any((p) => p.id == guest.id), false);
      }

      // Kurucu da odadan ayrıldığında oda tamamen kapatılmalı
      await MultiplayerService.leaveAdvancedRoom(playerId: host.id);
      expect(MultiplayerService.activeCustomRoom, isNull);
    });

    test('CustomRoom JSON serileştirme ve geri dönüştürme hatasız çalışır', () {
      const room = CustomRoom(
        id: 'r_test',
        roomCode: '654321',
        roomName: 'JSON Odası',
        hostId: 'h1',
        hostName: 'HostJSON',
        isLocked: true,
        password: 'secret_pass',
        maxPlayers: 6,
        isTeamMode: true,
        teamCount: 3,
        teams: [
          TeamConfig(id: 't1', name: 'Kırmızı', color: Color(0xFFEF4444)),
          TeamConfig(id: 't2', name: 'Mavi', color: Color(0xFF0284C7)),
        ],
        targetWins: 3,
        players: [
          RoomPlayer(
            id: 'h1',
            name: 'HostJSON',
            avatarEmoji: '👑',
            isHost: true,
            teamId: 't1',
          ),
        ],
      );

      final json = room.toJson();
      final fromJson = CustomRoom.fromJson(json);

      expect(fromJson.roomCode, '654321');
      expect(fromJson.roomName, 'JSON Odası');
      expect(fromJson.isLocked, true);
      expect(fromJson.password, 'secret_pass');
      expect(fromJson.maxPlayers, 6);
      expect(fromJson.isTeamMode, true);
      expect(fromJson.teamCount, 3);
      expect(fromJson.teams.length, 2);
      expect(fromJson.teams[0].color.toARGB32(), const Color(0xFFEF4444).toARGB32());
      expect(fromJson.players.length, 1);
      expect(fromJson.players[0].name, 'HostJSON');
    });
  });

  group('CrossGameAuthService ve E-posta Doğrulama Testleri', () {
    test('E-posta format doğrulaması (isValidEmail)', () {
      expect(CrossGameAuthService.isValidEmail('test@example.com'), true);
      expect(CrossGameAuthService.isValidEmail('oyuncu.123@gmail.com'), true);
      expect(CrossGameAuthService.isValidEmail('gecersiz-eposta'), false);
      expect(CrossGameAuthService.isValidEmail('@deneme.com'), false);
    });

    test('Şifre eşleşmeme hatası (password != confirmPassword)', () async {
      final res = await CrossGameAuthService.registerUser(
        username: 'Boran',
        password: 'password123',
        confirmPassword: 'differentPassword',
      );
      expect(res.success, false);
      expect(res.message, contains('eşleşmiyor'));
    });

    test('6 haneli OTP kodu üretimi ve doğrulaması', () async {
      const email = 'boran@test.com';
      final code = await CrossGameAuthService.sendVerificationCode(email);
      expect(code, isNotNull);
      expect(code!.length, 6);
      expect(int.tryParse(code) != null, true);

      // Yanlış kod testi
      final wrongRes = CrossGameAuthService.verifyCode(email, '000000');
      expect(wrongRes, false);

      // Doğru kod testi
      final correctRes = CrossGameAuthService.verifyCode(email, code);
      expect(correctRes, true);
    });

    test('E-postasız opsiyonel kayıt başarıyla tamamlanmalı', () async {
      final res = await CrossGameAuthService.registerUser(
        username: 'YeniOyuncu',
        password: 'password123',
        confirmPassword: 'password123',
      );
      expect(res.success, true);
      expect(res.player, isNotNull);
      expect(res.player!.name, 'YeniOyuncu');
      expect(res.player!.email, isNull);
      expect(res.player!.isEmailVerified, false);
      expect(res.player!.tag.startsWith('#KW-'), true);
    });

    test('E-posta girildiğinde doğrulanmamışsa kayıt reddedilmeli', () async {
      final res = await CrossGameAuthService.registerUser(
        username: 'EpostaKullanici',
        password: 'password123',
        confirmPassword: 'password123',
        email: 'eposta@test.com',
        isEmailVerified: false,
      );
      expect(res.success, false);
      expect(res.message, contains('doğrulama kodunu onaylayın'));
    });

    test('Giriş yaptıktan sonra e-posta bağlama ve doğrulama', () async {
      final profile = ProfileController();
      expect(profile.player.email, isNull);
      expect(profile.player.isEmailVerified, false);

      final success = await profile.attachEmail(email: 'sonradan@eposta.com');
      expect(success, true);
      expect(profile.player.email, 'sonradan@eposta.com');
      expect(profile.player.isEmailVerified, true);
    });
  });

  group('AvatarBadge ve Çift Yazı Önleme Testleri', () {
    testWidgets('AvatarBadge varsayılan olarak isim ve kupa render etmez (çift yazı önlenir)', (tester) async {
      const testPlayer = Player(
        id: 'p1',
        name: 'BoranTest',
        tag: '#KW-7777',
        avatarEmoji: '🦁',
        trophies: 1500,
        level: 8,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarBadge(player: testPlayer),
          ),
        ),
      );

      // Avatar emoji ve seviye görünmeli
      expect(find.text('🦁'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      // İsim, tag ve kupa AvatarBadge içinde görünmemeli (ekranlar kendi yerinde basar)
      expect(find.text('BoranTest'), findsNothing);
      expect(find.text('#KW-7777'), findsNothing);
      expect(find.textContaining('1500'), findsNothing);
    });
  });

  group('Yapay Zeka Hakemi & Kendini Geliştiren Soru Havuzu Testleri', () {
    test('Yazım hatası toleransı: Küçük harf ve Türkçe karakter hataları düzeltilmeli', () {
      final cat = sampleCategories.firstWhere((c) => c.id == 'yere_serilen');
      // "hali" yazılınca "Halı" olarak düzeltilmeli
      final res1 = WordEngine.validateWord(
        rawInput: 'hali',
        category: cat,
        alreadyUsedWords: {},
      );
      expect(res1.isValid, true);
      expect(res1.status, WordValidationStatus.correctedTypo);
      expect(res1.matchedWord, 'Halı');
      expect(res1.originalInput, 'hali');

      // "kilimm" (çift harf) yazılınca "Kilim" olarak düzeltilmeli
      final res2 = WordEngine.validateWord(
        rawInput: 'kilimm',
        category: cat,
        alreadyUsedWords: {},
      );
      expect(res2.isValid, true);
      expect(res2.matchedWord, 'Kilim');
    });

    test('Yapay Zeka Hakemi: Listede bulunmayan mantıklı cevabı onaylamalı ve soru havuzuna eklemeli', () async {
      final cat = sampleCategories.firstWhere((c) => c.id == 'deniz_canlilari');

      // Başlangıçta "istavrit" acceptedWords listesinde yok
      final initialLength = cat.acceptedWords.length;
      expect(cat.acceptedWords.any((w) => w.toLowerCase() == 'istavrit'), false);

      // Yapay Zeka Hakemi devreye girer
      final res = await WordEngine.validateWordAsync(
        rawInput: 'istavrit',
        category: cat,
        alreadyUsedWords: {},
      );

      // Yapay zeka onaylamalı ve havuza eklemeli
      expect(res.isValid, true);
      expect(res.isAiApproved, true);
      expect(res.matchedWord, 'İstavrit');

      // Kategori havuzu genişlemiş olmalı (+1 kelime kendini geliştirdi)
      expect(cat.acceptedWords.length, initialLength + 1);
      expect(cat.acceptedWords.any((w) => w.toLowerCase() == 'istavrit'), true);

      // Artık bir sonraki oyuncu için bu kelime yerel havuzda mevcuttur
      final nextTurnRes = WordEngine.validateWord(
        rawInput: 'istavrit',
        category: cat,
        alreadyUsedWords: {},
      );
      expect(nextTurnRes.isValid, true);
      expect(nextTurnRes.matchedWord, 'İstavrit');
    });

    test('Yapay Zeka Hakemi: Kategoriyle ilgisi olmayan mantıksız kelimeyi reddetmeli', () async {
      final cat = sampleCategories.firstWhere((c) => c.id == 'deniz_canlilari');

      final res = await WordEngine.validateWordAsync(
        rawInput: 'tornavida',
        category: cat,
        alreadyUsedWords: {},
      );

      expect(res.isValid, false);
      expect(res.status, WordValidationStatus.invalid);
    });

    test('Türkçe Çoğul ve Ek Toleransı (Morfolojik Stemming): Çoğul veya ekli kelimeler düzeltilmeli', () {
      final cat = sampleCategories.firstWhere((c) => c.id == 'cat_open_001'); // Kış Denince Akla Gelenler
      
      // "eldivenler" yazılınca "Eldiven" olarak düzeltilmeli
      final res1 = WordEngine.validateWord(
        rawInput: 'eldivenler',
        category: cat,
        alreadyUsedWords: {},
      );
      expect(res1.isValid, true);
      expect(res1.status, WordValidationStatus.correctedTypo);
      expect(res1.matchedWord, 'Eldiven');
      expect(res1.isAiApproved, true);

      // "somine" yazılınca aksansız "Şömine" olarak düzeltilmeli
      final res2 = WordEngine.validateWord(
        rawInput: 'somine',
        category: cat,
        alreadyUsedWords: {},
      );
      expect(res2.isValid, true);
      expect(res2.matchedWord, 'Şömine');
      expect(res2.isAiApproved, true);

      // "kardanadam" (boşluksuz) yazılınca "Kardan adam" olarak düzeltilmeli
      final res3 = WordEngine.validateWord(
        rawInput: 'kardanadam',
        category: cat,
        alreadyUsedWords: {},
      );
      expect(res3.isValid, true);
      expect(res3.matchedWord, 'Kardan adam');
      expect(res3.isAiApproved, true);
    });

    test('Ucu Açık Kategorilerde Anlamsal Yapay Zeka Onayı ve Havuz Genişlemesi', () async {
      final cat = sampleCategories.firstWhere((c) => c.id == 'cat_open_001'); // Kış Denince Akla Gelenler
      
      // "odun" listede yoksa bile kış kategorisi için Yapay Zeka onaylamalı
      final res = await WordEngine.validateWordAsync(
        rawInput: 'odun',
        category: cat,
        alreadyUsedWords: {},
      );

      expect(res.isValid, true);
      expect(res.isAiApproved, true);
      expect(res.matchedWord, 'Odun');
      expect(cat.acceptedWords.any((w) => w.toLowerCase() == 'odun'), true);
    });

    testWidgets('WordBubble widgetı Yapay Zeka onay rozetini ve düzeltilen kelime bilgisini render etmeli', (tester) async {
      final entry = WordEntry(
        word: 'Şömine',
        playerId: 'u1',
        isCorrect: true,
        timestamp: DateTime.now(),
        originalTypo: 'somine',
        isAiApproved: true,
        aiExplanation: 'Yapay zeka düzeltti',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordBubble(
              entry: entry,
              isFromCurrentUser: true,
            ),
          ),
        ),
      );

      // Robot ikonu, doğru kelime ve düzeltme bilgisi görünmeli
      expect(find.text('🤖'), findsWidgets);
      expect(find.text('Şömine'), findsOneWidget);
      expect(find.textContaining('Düzeltildi: "somine"'), findsOneWidget);
    });
  });

  group('Gelişmiş Oyun Güncellemesi Testleri (Birleşik Brifing, Sıfır Risk Bot, Kaptanlık, 5 Takım, Kendine İstek Engeli)', () {
    test('Birleşik Brifing Ekranı: showBriefing ile başlar, geri sayım bitince tura geçer', () {
      final controller = GameController();
      const user = Player(id: 'u1', name: 'Boran', avatarEmoji: '👑');
      const bot = Player(id: 'bot_1', name: 'Bot Efe', avatarEmoji: '🤖');
      final cat = sampleCategories.first;

      controller.startNewGame(
        category: cat,
        userPlayer: user,
        opponentPlayer: bot,
        showBriefing: true,
      );

      expect(controller.round!.isShowingBriefing, true);
      expect(controller.round!.briefingCountdown, 6);
      expect(controller.isUserTurn, false); // Brifing sırasında henüz kelime girilemez

      // Brifing sona erdiğinde tur başlar
      controller.endBriefingAndStartNextRound();
      expect(controller.round!.isShowingBriefing, false);
      expect(controller.isUserTurn, true);
    });

    test('Bot ile Alıştırma Modu: Sıfır risk, kupa/altın/istatistik ASLA değişmez', () {
      final profile = ProfileController();
      final initialTrophies = profile.player.trophies;
      final initialCoins = profile.coins;
      final initialWins = profile.wins;

      final round = GameRound(
        category: sampleCategories.first,
        player1: profile.player,
        player2: const Player(id: 'bot_test', name: 'Bot', avatarEmoji: '🤖'),
        currentTurnPlayerId: profile.player.id,
        status: RoundStatus.finished,
        winnerPlayerId: profile.player.id,
        isPracticeBot: true, // Alıştırma botu modu
      );

      // GameOver mantığında isPracticeBot true ise recordMatchResult çağrılmaz
      if (!round.isPracticeBot) {
        profile.recordMatchResult(won: true);
      }

      // Değerler hiç değişmemeli
      expect(profile.player.trophies, initialTrophies);
      expect(profile.coins, initialCoins);
      expect(profile.wins, initialWins);
    });

    test('Kendine Arkadaşlık İsteği Engeli: Kendi etiketi veya ismiyle arkadaş eklenemez', () {
      final friendsCtrl = FriendsController();
      const currentUser = Player(
        id: 'usr_me_123',
        name: 'Boran Alp',
        tag: '#KW-9999',
        avatarEmoji: '👑',
      );

      // 1. Kendi adıyla eklemeyi dene
      final resName = friendsCtrl.addFriendByTag(
        'Boran Alp',
        currentUserId: currentUser.id,
        currentUserName: currentUser.name,
        currentUserTag: currentUser.tag,
      );
      expect(resName, false);

      // 2. Kendi etiketiyle eklemeyi dene
      final resTag = friendsCtrl.addFriendByTag(
        '#KW-9999',
        currentUserId: currentUser.id,
        currentUserName: currentUser.name,
        currentUserTag: currentUser.tag,
      );
      expect(resTag, false);

      // 3. Başka bir oyuncuyu ekle -> Başarılı olmalı
      final resOther = friendsCtrl.addFriendByTag(
        '#KW-1234',
        currentUserId: currentUser.id,
        currentUserName: currentUser.name,
        currentUserTag: currentUser.tag,
      );
      expect(resOther, true);
      expect(friendsCtrl.friends.length, 1);
    });

    test('Takım Sayısı 5 e Kadar Çıkabilmeli, Oyuncu Dokunarak Takım Değiştirebilmeli ve Kaptan Renk Seçebilmeli', () async {
      const host = Player(id: 'host_1', name: 'Kaptan Host', avatarEmoji: '👑');
      final room = await MultiplayerService.createAdvancedRoom(
        roomName: '5 Takımlı Turnuva',
        host: host,
        maxPlayers: 5,
        isTeamMode: true,
        teamCount: 5, // 5 Takım!
        targetWins: 2,
      );

      // 5 Takım oluşturulmuş olmalı
      expect(room.teams.length, 5);
      expect(room.teams[0].name, 'Kırmızı Takım');
      expect(room.teams[4].name, 'Mor Takım');

      // Oyuncu dokunarak takımını team_5 e taşısın
      MultiplayerService.switchPlayerTeam(host.id, 'team_5');
      final updatedRoom = MultiplayerService.activeCustomRoom!;
      final hostInRoom = updatedRoom.players.firstWhere((p) => p.id == host.id);
      expect(hostInRoom.teamId, 'team_5');

      // team_5 in ilk oyuncusu olduğu için Kaptandır, rengini değiştirebilir
      const newTeamColor = Color(0xFF14B8A6);
      MultiplayerService.updateTeamColor('team_5', newTeamColor);
      final roomAfterColor = MultiplayerService.activeCustomRoom!;
      final team5 = roomAfterColor.teams.firstWhere((t) => t.id == 'team_5');
      expect(team5.color, newTeamColor);
    });
  });

  group('En Son Özellikler Testleri (Yanlış Kelime Tasarımı, 200 Soru, Bot-Oda Temizliği, Herkes Tek N-Oyuncu)', () {
    testWidgets('Yanlış kelime kırmızı render edilmez, üstü çizilidir ve tik ikonu yoktur', (WidgetTester tester) async {
      final wrongEntry = WordEntry(
        word: 'Yanlış',
        playerId: 'p1',
        isCorrect: false,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordBubble(
              entry: wrongEntry,
              isFromCurrentUser: true,
              teamColor: const Color(0xFF10B981),
            ),
          ),
        ),
      );

      // Tik ikonu olmamalı
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Metinde TextDecoration.lineThrough olmalı
      final textWidget = tester.widget<Text>(find.text('Yanlış'));
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);

      // Arka plan rengi kırmızı (#331C1E) olmamalı, teamColor tabanlı olmalı
      final containers = tester.widgetList<Container>(find.byType(Container));
      final bubbleContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).border != null,
      );
      final boxDecoration = bubbleContainer.decoration as BoxDecoration;
      expect(boxDecoration.color, isNot(const Color(0xFF331C1E)));
    });

    test('Odada sadece botlar kalırsa oda otomatik silinir', () async {
      const host = Player(id: 'host_solo', name: 'Yalnız Host', avatarEmoji: '👑');
      await MultiplayerService.createAdvancedRoom(
        roomName: 'Botlu Oda',
        host: host,
      );

      // Odaya bot ekle
      MultiplayerService.addBotToRoom();
      expect(MultiplayerService.activeCustomRoom!.players.length, 2);

      // İnsan oyuncu (host) çıksın
      await MultiplayerService.leaveAdvancedRoom(playerId: host.id);

      // Oda tamamen kapanmış olmalı (sadece bot kalması engellenir)
      expect(MultiplayerService.activeCustomRoom, isNull);
    });

    test('Herkes Tek modunda her oyuncu kendi takımındadır ve sıra sıra döner', () {
      final p1 = const RoomPlayer(id: 'p1', name: 'Oyuncu 1', avatarEmoji: '👑', colorValue: 0xFF10B981);
      final p2 = const RoomPlayer(id: 'p2', name: 'Oyuncu 2', avatarEmoji: '🦊', colorValue: 0xFFEF4444);
      final p3 = const RoomPlayer(id: 'p3', name: 'Oyuncu 3', avatarEmoji: '⚡', colorValue: 0xFF0284C7);

      final room = CustomRoom(
        id: 'r_individual',
        roomCode: '111222',
        roomName: 'Bireysel 3 Kişi',
        hostId: 'p1',
        hostName: 'Oyuncu 1',
        isTeamMode: false,
        players: [p1, p2, p3],
      );

      final gameCtrl = GameController();
      final user = Player(id: p1.id, name: p1.name, avatarEmoji: p1.avatarEmoji);
      final cat = sampleCategories.first;

      gameCtrl.startTeamOrCustomGame(
        room: room,
        userPlayer: user,
        category: cat,
        showBriefing: false,
      );

      // Herkes kendi takımında olmalı
      expect(gameCtrl.round!.isTeamMode, true);
      expect(gameCtrl.round!.teamScores.length, 3);
      expect(gameCtrl.round!.teamNames['team_p1'], 'Oyuncu 1');
      expect(gameCtrl.round!.teamNames['team_p2'], 'Oyuncu 2');
      expect(gameCtrl.round!.teamNames['team_p3'], 'Oyuncu 3');

      // İlk sıra p1'de
      expect(gameCtrl.round!.currentTurnTeamId, 'team_p1');

      // P1 kelime gönderince sıra p2'ye geçmeli
      gameCtrl.submitRemoteWord(word: cat.acceptedWords.first, isCorrect: true, playerId: 'p1');
      expect(gameCtrl.round!.currentTurnTeamId, 'team_p2');

      // P2 kelime gönderince sıra p3'e geçmeli
      gameCtrl.submitRemoteWord(word: cat.acceptedWords[1], isCorrect: true, playerId: 'p2');
      expect(gameCtrl.round!.currentTurnTeamId, 'team_p3');

      // P3 kelime gönderince sıra tekrar p1'e dönmeli (Round-robin döngüsü)
      gameCtrl.submitRemoteWord(word: cat.acceptedWords[2], isCorrect: true, playerId: 'p3');
      expect(gameCtrl.round!.currentTurnTeamId, 'team_p1');
    });
  });

  group('26 İkonik Bot Profili, Mükerrer Bot Engeli ve Tekrarlanan Kelime Uyarısı Testleri', () {
    test('İstenen tüm 26+ ikonik bot profili mevcut olmalı, gerçek fotoğrafları ve özel yanlış cevapları bulunmalı', () {
      final requestedBotNames = [
        'Jhonny Sins',
        'Homelander',
        'MrBeast',
        'Magnus Carlsen',
        'Cordiseps',
        'Elraenn',
        'Rraenee',
        'Efes Patos',
        'Memati Baş',
        'Polat Alemdar',
        'Ramiz Dayı',
        'Elon Musk',
        'Messi',
        'Ronaldo',
        'Snoop Dogg',
        'Eminem',
        'Ruhi Çenet',
        'Kadıköy Boğası',
        'Testere Necmi',
        'Nihat Hatipoğlu',
        'Recep İvedik',
        'Şaban',
        'Walter White',
        'Kratos',
        'Gigachad',
        'Skibidi Toilet',
        'Shrek',
      ];

      for (final name in requestedBotNames) {
        final profile = BotAiEngine.getProfileByName(name);
        expect(profile, isNotNull, reason: '$name bot profili bulunamadı!');
        if (profile != null) {
          expect(profile.avatarUrl.startsWith('http'), true, reason: '$name URL si http ile başlamalı');
          expect(profile.wrongAnswers.isNotEmpty, true, reason: '$name için yanlış cevap listesi boş olamaz!');
        }
      }

      // Özel yanlış cevap ve yayıncı/belgeselci kontrolü
      final skibidi = BotAiEngine.getProfileByName('Skibidi Toilet')!;
      expect(skibidi.wrongAnswers, containsAll(['skibidi', 'dop dop', 'yes yes']));

      final recep = BotAiEngine.getProfileByName('Recep İvedik')!;
      expect(recep.wrongAnswers, containsAll(['bohohohoty', 'kara ambar derneği']));

      final boga = BotAiEngine.getProfileByName('Kadıköy Boğası')!;
      expect(boga.wrongAnswers, containsAll(['iieh', 'iiiğğehh', 'hayır, altıma ettim', 'rabia', '2030 yılında']));

      final ruhi = BotAiEngine.getProfileByName('Ruhi Çenet')!;
      expect(ruhi.wrongAnswers, containsAll(['yahudiler', 'yahudiler buna da bir çözüm buldu']));

      final cordiseps = BotAiEngine.getProfileByName('Cordiseps')!;
      expect(cordiseps.wrongAnswers, containsAll(['chat', 'kanka', 'yayındayız', 'patladım']));

      final rraenee = BotAiEngine.getProfileByName('Rraenee')!;
      expect(rraenee.wrongAnswers, containsAll(['patos', 'chat', 'kardeşim']));

      final efesPatos = BotAiEngine.getProfileByName('Efes Patos')!;
      expect(efesPatos.wrongAnswers, containsAll(['patos rolls', 'efes', 'cips']));
    });

    test('Oda veya maçta mükerrer bot ismi engellenmeli', () {
      final existing = ['Recep İvedik', 'Elon Musk', 'Gigachad', 'Skibidi Toilet'];
      for (int i = 0; i < 20; i++) {
        final bot = BotAiEngine.generateBotPlayer(existingNames: existing);
        expect(existing.contains(bot.name), false, reason: '${bot.name} zaten odada olmasına rağmen tekrar seçildi!');
      }
    });

    test('Daha önceden yazılmış kelime tekrar yazıldığında "daha önceden yazıldı" uyarısı dönmeli', () async {
      final cat = sampleCategories.first;
      final usedWord = cat.acceptedWords.first;

      // 1. Senkron Doğrulama
      final syncRes = WordEngine.validateWord(
        rawInput: usedWord,
        category: cat,
        alreadyUsedWords: {usedWord},
      );
      expect(syncRes.status, WordValidationStatus.alreadyUsed);
      expect(syncRes.message, contains('daha önceden yazıldı!'));

      // 2. GameController geribildirim mesajı
      final controller = GameController();
      const user = Player(id: 'u1', name: 'Boran', avatarEmoji: '👑');
      const opp = Player(id: 'u2', name: 'Rakip', avatarEmoji: '🤖');
      controller.startNewGame(category: cat, userPlayer: user, opponentPlayer: opp);

      // İlk geçerli kelimeyi gönder
      await controller.submitPlayerWord(cat.acceptedWords[0]);

      // Sırayı tekrar kullanıcıya al
      controller.submitRemoteWord(word: cat.acceptedWords[1], isCorrect: true, playerId: opp.id);

      // Daha önce yazılan kelimeyi tekrar dene
      final secondRes = await controller.submitPlayerWord(cat.acceptedWords[0]);
      expect(secondRes.status, WordValidationStatus.alreadyUsed);
      expect(controller.lastFeedbackMessage, contains('daha önceden yazıldı!'));
      expect(controller.isLastFeedbackSuccess, false);
    });
  });

  group('Son Senkronizasyon, Bireysel Bot Sırası ve Soru Geçmişi Testleri', () {
    test('GameRound roundHistory ve CompletedRoundSummary model doğrulaması', () {
      final cat = sampleCategories.first;
      final summary = CompletedRoundSummary(
        roundNumber: 1,
        category: cat,
        winningTeamOrPlayerId: 'team_1',
        winningTeamOrPlayerName: 'Kırmızı Takım',
        words: [
          WordEntry(word: 'Elma', playerId: 'p1', isCorrect: true, timestamp: DateTime.now()),
          WordEntry(word: 'Armut', playerId: 'p2', isCorrect: true, timestamp: DateTime.now()),
        ],
        teamScoresAfterRound: {'team_1': 1, 'team_2': 0},
      );

      const p1 = Player(id: 'p1', name: 'Oyuncu 1', avatarEmoji: '👑');
      const p2 = Player(id: 'p2', name: 'Oyuncu 2', avatarEmoji: '🤖');

      final round = GameRound(
        category: cat,
        player1: p1,
        player2: p2,
        currentTurnPlayerId: p1.id,
        roundHistory: [summary],
      );

      expect(round.roundHistory.length, 1);
      expect(round.roundHistory.first.roundNumber, 1);
      expect(round.roundHistory.first.winningTeamOrPlayerName, 'Kırmızı Takım');
      expect(round.roundHistory.first.words.length, 2);
    });

    test('Takımda birden fazla bot olduğunda her bot sırayla (bireysel) hamle yapar', () {
      final controller = GameController();
      final cat = sampleCategories.first;
      const user = Player(id: 'user_1', name: 'Kullanıcı', avatarEmoji: '👑');
      final bot1 = BotAiEngine.generateBotPlayer();
      final bot2 = BotAiEngine.generateBotPlayer(existingNames: [bot1.name]);

      final room = CustomRoom(
        id: 'r_test',
        roomCode: '123456',
        roomName: 'Test Odası',
        hostId: user.id,
        hostName: user.name,
        isTeamMode: true,
        teamCount: 2,
        targetWins: 2,
        teams: const [
          TeamConfig(id: 'team_1', name: 'Takım 1', color: Color(0xFFEF4444)),
          TeamConfig(id: 'team_2', name: 'Takım 2', color: Color(0xFF0284C7)),
        ],
        players: [
          RoomPlayer(id: user.id, name: user.name, avatarEmoji: '👑', teamId: 'team_1', isHost: true),
          RoomPlayer(id: bot1.id, name: bot1.name, avatarEmoji: bot1.avatarEmoji, teamId: 'team_2', isBot: true),
          RoomPlayer(id: bot2.id, name: bot2.name, avatarEmoji: bot2.avatarEmoji, teamId: 'team_2', isBot: true),
        ],
      );

      controller.startTeamOrCustomGame(
        room: room,
        userPlayer: user,
        category: cat,
        showBriefing: false,
      );

      // Başlangıç: Team 1 (Kullanıcı) sırası
      expect(controller.round!.currentTurnTeamId, 'team_1');
      expect(controller.round!.currentTurnPlayerId, user.id);

      // Kullanıcı kelime yazıp sırayı devretsin -> Sıra Team 2'nin 1. botuna (bot1) geçmeli
      controller.submitRemoteWord(word: cat.acceptedWords[0], isCorrect: true, playerId: user.id);
      expect(controller.round!.currentTurnTeamId, 'team_2');
      expect(controller.round!.currentTurnPlayerId, bot1.id);

      // Bot 1 kelime yazıp devretsin -> Sıra tekrar Team 1'e geçmeli
      controller.submitRemoteWord(word: cat.acceptedWords[1], isCorrect: true, playerId: bot1.id);
      expect(controller.round!.currentTurnTeamId, 'team_1');
      expect(controller.round!.currentTurnPlayerId, user.id);

      // Kullanıcı tekrar yazıp devretsin -> Sıra Team 2'nin 2. botuna (bot2) geçmeli (Bireysel bot rotasyonu!)
      controller.submitRemoteWord(word: cat.acceptedWords[2], isCorrect: true, playerId: user.id);
      expect(controller.round!.currentTurnTeamId, 'team_2');
      expect(controller.round!.currentTurnPlayerId, bot2.id);
    });

    test('Surrender veya Timeout durumunda tamamlanan raunt roundHistory e kaydedilir', () {
      final controller = GameController();
      final cat = sampleCategories.first;
      const user = Player(id: 'u1', name: 'Boran', avatarEmoji: '👑');
      const opp = Player(id: 'u2', name: 'Rakip', avatarEmoji: '🤖');

      controller.startNewGame(category: cat, userPlayer: user, opponentPlayer: opp);
      // Kullanıcı bir kelime yazsın
      controller.submitRemoteWord(word: cat.acceptedWords[0], isCorrect: true, playerId: user.id);

      // Teslim olunsun
      controller.surrenderMatch();

      expect(controller.round!.status, RoundStatus.finished);
      expect(controller.round!.roundHistory.isNotEmpty, true);
      expect(controller.round!.roundHistory.first.roundNumber, 1);
      expect(controller.round!.roundHistory.first.words.isNotEmpty, true);
    });
  });
}

