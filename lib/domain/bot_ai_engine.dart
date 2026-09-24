import 'dart:async';
import 'dart:math';
import '../core/utils/turkish_strings.dart';
import '../data/models/category.dart';
import '../data/models/player.dart';

class BotProfile {
  final String name;
  final String emoji;
  final String avatarUrl;
  final int trophies;
  final int level;
  final List<String> wrongAnswers;

  const BotProfile({
    required this.name,
    required this.emoji,
    required this.avatarUrl,
    required this.trophies,
    required this.level,
    required this.wrongAnswers,
  });
}

class BotAiEngine {
  final Random _random = Random();
  Timer? _turnTimer;
  Timer? _secondAttemptTimer;

  static const List<String> commonWrongWords = [
    'araba', 'telefon', 'televizyon', 'bilgisayar', 'kapı', 'pencere',
    'sandalye', 'ayakkabı', 'gözlük', 'çanta', 'masa', 'kalem',
    'defter', 'bardak', 'kaşık', 'halı', 'koltuk', 'lamba', 'tabak', 'saat'
  ];

  static const List<BotProfile> botProfiles = [
    // 1. Kullanıcının İstediği Özel İkonik Karakterler
    BotProfile(
      name: 'Jhonny Sins',
      emoji: '👨‍⚕️',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
      trophies: 1540,
      level: 9,
      wrongAnswers: ['doktorum ben', 'astronot kıyafeti', 'tesisat anahtarı', 'üniforma', 'yanlış oda', 'ben tamirciyim', 'stetoskop'],
    ),
    BotProfile(
      name: 'Homelander',
      emoji: '🦸‍♂️',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/en/d/dc/Homelander-comic-vs-tv-series.jpg',
      trophies: 1850,
      level: 10,
      wrongAnswers: ['ben vatanseverim', 'süt', 'ben daha iyiyim', 'lazer göz', 'uçabiliyorum', 'istediğimi yaparım'],
    ),
    BotProfile(
      name: 'MrBeast',
      emoji: '💰',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/4/47/MrBeast_in_2026_%28cropped_4%29.png',
      trophies: 1720,
      level: 10,
      wrongAnswers: ['100.000 dolar', 'son kalan kazanır', 'abone olun', 'para sayma makinesi', 'büyük ödül', 'çemberden çıkan kaybeder'],
    ),
    BotProfile(
      name: 'Magnus Carlsen',
      emoji: '♟️',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/5/5f/MagnusCarlsen24.jpg',
      trophies: 1980,
      level: 10,
      wrongAnswers: ['vezir fedası', 'e4', 'satranç saati', 'terk ediyorum', 'büyükusta', 'rok attım', 'şah mat'],
    ),
    BotProfile(
      name: 'Cordiseps',
      emoji: '🎧',
      avatarUrl: 'https://images.unsplash.com/photo-1566492031773-4f4e44671857?w=200&auto=format&fit=crop&q=80',
      trophies: 1490,
      level: 7,
      wrongAnswers: ['chat', 'kanka', 'yayındayız', 'patladım', 'klip al', 'yok artık', 'kurgu bu', 'bağış geldi', 'kick', 'yayın bitti'],
    ),
    BotProfile(
      name: 'Elraenn',
      emoji: '🦎',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
      trophies: 1620,
      level: 8,
      wrongAnswers: ['tuğkan abi', 'karınca çiftliğim', 'tarantula', 'racon', 'semt', 'limon tayfa', 'eyvallah', 'çiftlik'],
    ),
    BotProfile(
      name: 'Rraenee',
      emoji: '🧢',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
      trophies: 1640,
      level: 8,
      wrongAnswers: ['patos', 'chat', 'kardeşim', 'yayındayız', 'bana bak', 'yok artık', 'eyvallah', 'şaka mısın', 'efes'],
    ),
    BotProfile(
      name: 'Efes Patos',
      emoji: '🍟',
      avatarUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=200&auto=format&fit=crop&q=80',
      trophies: 1480,
      level: 7,
      wrongAnswers: ['patos rolls', 'patos cipsi', 'efes', 'cips', 'soğuk meşrubat', 'cips kola', 'atıştırmalık', 'baharatlı cips'],
    ),
    BotProfile(
      name: 'Memati Baş',
      emoji: '🔫',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&auto=format&fit=crop&q=80',
      trophies: 1750,
      level: 9,
      wrongAnswers: ['usta', 'kafama sıkarım', 'ölelim usta', 'gamzeli', 'aslanım', 'sık usta', 'konsey', 'çakır'],
    ),
    BotProfile(
      name: 'Polat Alemdar',
      emoji: '🕶️',
      avatarUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=200&auto=format&fit=crop&q=80',
      trophies: 1950,
      level: 10,
      wrongAnswers: ['sonunu düşünen kahraman olamaz', 'iki kişinin bildiği sır değildir', 'racon', 'kurtlar vadisi', 'elif', 'aslan bey', 'kripteks'],
    ),
    BotProfile(
      name: 'Ramiz Dayı',
      emoji: '🚬',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&auto=format&fit=crop&q=80',
      trophies: 1880,
      level: 10,
      wrongAnswers: ['mesele o değil yeğen', 'yeğen', 'sadakat', 'eyşan', 'oysa herkes öldürür sevdiğini', 'kaderimiz bu yeğen', 'jilet'],
    ),
    BotProfile(
      name: 'Elon Musk',
      emoji: '🚀',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/5/5e/Elon_Musk_-_54820081119_%28cropped%29.jpg',
      trophies: 1910,
      level: 10,
      wrongAnswers: ['dogecoin', 'mars', 'roket', 'cybertruck', 'neuralink', 'x', 'starlink', 'tesla'],
    ),
    BotProfile(
      name: 'Messi',
      emoji: '🐐',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/c/c8/Leo_Messi_Argentina_v_Egypt_7_July_2026-1.jpg',
      trophies: 1990,
      level: 10,
      wrongAnswers: ['ankara messi', 'que miras bobo', 'altın top', 'dünya kupası', 'barcelona', 'inter miami', 'la pulga'],
    ),
    BotProfile(
      name: 'Ronaldo',
      emoji: '⚽',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/2/26/Cristiano_Ronaldo_Croatia_v_Portugal_2_July_2026-075_%28cropped%29.jpg',
      trophies: 1990,
      level: 10,
      wrongAnswers: ['siuuu', 'cristiano', 'şampiyonlar ligi', 'calma calma', 'portekiz', 'al nassr', 'cr7'],
    ),
    BotProfile(
      name: 'Snoop Dogg',
      emoji: '🕶️',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/f/f0/Snoop_Dogg%2C_WrestleMania_XL_%28cropped%29_%28cropped%29.jpg',
      trophies: 1670,
      level: 8,
      wrongAnswers: ['smoke weed', 'doggystyle', 'west coast', 'd-o-double-g', 'rap', 'drop it like its hot', 'gin and juice'],
    ),
    BotProfile(
      name: 'Eminem',
      emoji: '🎤',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/0/0f/Eminem_2021_Color_Corrected.jpg',
      trophies: 1780,
      level: 9,
      wrongAnswers: ['rap god', 'slim shady', "mom's spaghetti", 'lose yourself', '8 mile', 'stan'],
    ),
    BotProfile(
      name: 'Ruhi Çenet',
      emoji: '🎥',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
      trophies: 1770,
      level: 9,
      wrongAnswers: [
        'yahudiler',
        'yahudiler buna da bir çözüm buldu',
        'dünyanın en tehlikeli yeri',
        'belgesel',
        'kuzey kutbunda 7 gün',
        'ölümcül virüs',
        'burada hayatta kaldım',
        'dünyanın en soğuk köyü',
        'gizli kabile',
      ],
    ),
    BotProfile(
      name: 'Kadıköy Boğası',
      emoji: '🐂',
      avatarUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=200&auto=format&fit=crop&q=80',
      trophies: 1590,
      level: 8,
      wrongAnswers: ['iieh', 'iiiğğehh', 'hayır, altıma ettim', 'rabia', '2030 yılında', 'boğa heykeli'],
    ),
    BotProfile(
      name: 'Testere Necmi',
      emoji: '🪚',
      avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=200&auto=format&fit=crop&q=80',
      trophies: 1710,
      level: 9,
      wrongAnswers: ['testere', 'parçalarım', 'hüküm verildi', 'konsey', 'laz ziya', 'odun keser gibi'],
    ),
    BotProfile(
      name: 'Nihat Hatipoğlu',
      emoji: '🕌',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/a/a4/Nihat_Hatipoglu_Viyana.JPG',
      trophies: 1650,
      level: 8,
      wrongAnswers: ['dosta doğru', 'oruç bozulur mu', 'iftar vakti', 'sevaptır', 'dualarımız sizinle', 'hayırlı ramazanlar'],
    ),
    BotProfile(
      name: 'Recep İvedik',
      emoji: '🦍',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/en/a/a3/RecepIvedikFilmPoster.jpg',
      trophies: 1530,
      level: 7,
      wrongAnswers: ['bohohohoty', 'kara ambar derneği', 'gonuşma soner', 'agresifim kompleksliyim', 'bana bak böhöhöyt', 'sal gitsin'],
    ),
    BotProfile(
      name: 'Şaban',
      emoji: '🐮',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/tr/f/f8/Kemal_Sunal.gif',
      trophies: 1690,
      level: 8,
      wrongAnswers: ['şiki şiki baba', 'parka gidecekmiş iki gözümün çiçeği', 'mesela yani', 'inek şaban', 'lütfü', 'tontonum'],
    ),
    BotProfile(
      name: 'Walter White',
      emoji: '🧪',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/en/0/03/Walter_White_S5B.png',
      trophies: 1890,
      level: 10,
      wrongAnswers: ['say my name', 'i am the one who knocks', 'heisenberg', 'mavi kristal', 'jesse', 'we need to cook'],
    ),
    BotProfile(
      name: 'Kratos',
      emoji: '🪓',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/en/2/2f/Kratos_PS4.png',
      trophies: 1940,
      level: 10,
      wrongAnswers: ['boy', 'ares', 'kaos kılıçları', 'sparta', 'intikam', 'olimpiyat'],
    ),
    BotProfile(
      name: 'Gigachad',
      emoji: '🗿',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&auto=format&fit=crop&q=80',
      trophies: 1820,
      level: 9,
      wrongAnswers: ['average enjoyer', 'can you feel my heart', 'çene kası', 'sigma', 'mewing', 'chad'],
    ),
    BotProfile(
      name: 'Skibidi Toilet',
      emoji: '🚽',
      avatarUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=200&auto=format&fit=crop&q=80',
      trophies: 1350,
      level: 6,
      wrongAnswers: ['skibidi', 'dop dop', 'yes yes'],
    ),
    BotProfile(
      name: 'Shrek',
      emoji: '🧅',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/en/4/4d/Shrek_%28character%29.png',
      trophies: 1600,
      level: 8,
      wrongAnswers: ['bataklığım', 'eşek', 'fiona', 'katmanlar', 'ogre', 'soğan gibi'],
    ),

    // 2. Standart Türkçe Botlar
    BotProfile(
      name: 'Zeynep_99',
      emoji: '🌸',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80',
      trophies: 1240,
      level: 4,
      wrongAnswers: commonWrongWords,
    ),
    BotProfile(
      name: 'Barış_Usta',
      emoji: '⚡',
      avatarUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
      trophies: 1310,
      level: 5,
      wrongAnswers: commonWrongWords,
    ),
    BotProfile(
      name: 'Mert_Gamer',
      emoji: '🎯',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
      trophies: 1180,
      level: 4,
      wrongAnswers: commonWrongWords,
    ),
    BotProfile(
      name: 'Elif.K',
      emoji: '✨',
      avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&auto=format&fit=crop&q=80',
      trophies: 1260,
      level: 5,
      wrongAnswers: commonWrongWords,
    ),
    BotProfile(
      name: 'Kaan_06',
      emoji: '🔥',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
      trophies: 1350,
      level: 6,
      wrongAnswers: commonWrongWords,
    ),
    BotProfile(
      name: 'Selin_S',
      emoji: '🦊',
      avatarUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80',
      trophies: 1210,
      level: 4,
      wrongAnswers: commonWrongWords,
    ),
    BotProfile(
      name: 'BurakPro',
      emoji: '🚀',
      avatarUrl: 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=200&auto=format&fit=crop&q=80',
      trophies: 1400,
      level: 6,
      wrongAnswers: commonWrongWords,
    ),
  ];

  /// İsme göre bot profilini bulur
  static BotProfile? getProfileByName(String name) {
    final search = name.trim().toLowerCase();
    for (final p in botProfiles) {
      if (p.name.toLowerCase() == search) {
        return p;
      }
    }
    // Geriye dönük takma isim eşleşmesi
    if (search == 'ruh içen et' || search == 'ruh icen et') {
      return getProfileByName('Ruhi Çenet');
    }
    if (search == 'rraenee efes patos') {
      return getProfileByName('Rraenee');
    }
    return null;
  }

  /// Bir botun kendine özgü yanlış cevap havuzunu döner
  static List<String> getWrongAnswersForBot(String name) {
    final profile = getProfileByName(name);
    return profile?.wrongAnswers ?? commonWrongWords;
  }

  /// Bir odada veya maçta aynı isimle mükerrer bot olmasını engelleyerek rastgele bot üretir
  static Player generateBotPlayer({List<String> existingNames = const []}) {
    final rand = Random();
    final lowerExisting = existingNames.map((n) => n.trim().toLowerCase()).toSet();

    // Mevcut odadaki isimleri filtrele
    final candidates = botProfiles.where((p) => !lowerExisting.contains(p.name.toLowerCase())).toList();
    final profile = candidates.isNotEmpty
        ? candidates[rand.nextInt(candidates.length)]
        : botProfiles[rand.nextInt(botProfiles.length)];

    return Player(
      id: 'bot_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(9999)}',
      name: profile.name,
      tag: '#KW-${1000 + rand.nextInt(9000)}',
      avatarEmoji: profile.emoji,
      avatarUrl: profile.avatarUrl,
      trophies: profile.trophies,
      level: profile.level,
      isBot: true,
      botWrongAnswers: profile.wrongAnswers,
    );
  }

  /// Sıra bota geldiğinde hamle sürecini başlatır
  /// 
  /// Kural:
  /// - Yanlış cevap verme ihtimali: %50
  /// - Bir turda en fazla 1 defa yanlış cevap verebilir
  /// - Mesaj gönderme süresi: Her bir mesaj için ayrı ayrı 5 ile 12 saniye arası değişken (5000 - 12000 ms).
  ///   Bu rastgelelikte toplam süre 15 saniyeyi aşarsa bot doğal olarak süreden kaybeder.
  void playTurn({
    required Category category,
    required Set<String> Function() getAlreadyUsedWords,
    required void Function(String word) onWordSelected,
    required bool Function() isGameActive,
    Player? botPlayer,
  }) {
    stop();

    if (!isGameActive()) return;

    final usedWords = getAlreadyUsedWords();
    final availableWords = category.acceptedWords.where((word) {
      final norm = TurkishStrings.toLowerCaseTr(word);
      return !usedWords.any((u) => TurkishStrings.toLowerCaseTr(u) == norm);
    }).toList();

    // Eğer doğru kelime kalmadıysa bot hamle yapamaz ve süresi biterek yenilir
    if (availableWords.isEmpty) {
      return;
    }

    final chosenCorrectWord = availableWords[_random.nextInt(availableWords.length)];

    // %50 ihtimalle bot önce yanlış bir kelime denesin (üstü çizili görünsün), ardından doğruyu bilsin
    // Ancak bir turda en fazla 1 defa yanlış cevap verebilir!
    final willMakeMistakeFirst = _random.nextInt(100) < 50;

    // Mesaj gönderme süresi her bir mesaj için 5 ile 12 saniye arasında değişken (5000 - 12000 ms)
    final firstDelay = 5000 + _random.nextInt(7001); // 5000 - 12000 ms

    if (willMakeMistakeFirst) {
      // 1. Hamle (Yanlış kelime denemesi - 5 ile 12 sn sonra)
      _turnTimer = Timer(Duration(milliseconds: firstDelay), () {
        if (!isGameActive()) return;

        // Botun kendi karakterine özgü yanlış cevap listesinden kelime seç
        final wrongPool = (botPlayer?.botWrongAnswers != null && botPlayer!.botWrongAnswers!.isNotEmpty)
            ? botPlayer.botWrongAnswers!
            : (botPlayer != null ? getWrongAnswersForBot(botPlayer.name) : commonWrongWords);

        final wrongWord = wrongPool[_random.nextInt(wrongPool.length)];
        onWordSelected(wrongWord);

        // 2. Hamle (Doğru kelimeyi bulma): Yine ayrı olarak 5 ile 12 sn arasında (5000 - 12000 ms)
        // Eğer 1. ve 2. mesajın toplamı 15 saniyeyi aşarsa tur süresi dolacak ve bot süreden kaybedecek!
        final secondDelay = 5000 + _random.nextInt(7001); // 5000 - 12000 ms
        _secondAttemptTimer = Timer(Duration(milliseconds: secondDelay), () {
          if (!isGameActive()) return;
          onWordSelected(chosenCorrectWord);
        });
      });
    } else {
      // Direkt doğru kelimeyi yazma (5 ile 12 sn arasında)
      _turnTimer = Timer(Duration(milliseconds: firstDelay), () {
        if (!isGameActive()) return;
        onWordSelected(chosenCorrectWord);
      });
    }
  }

  void stop() {
    _turnTimer?.cancel();
    _secondAttemptTimer?.cancel();
    _turnTimer = null;
    _secondAttemptTimer = null;
  }
}
