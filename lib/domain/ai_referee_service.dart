import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import '../core/utils/turkish_strings.dart';
import '../data/categories_data.dart';
import '../data/models/category.dart';
import '../data/services/supabase_service.dart';

/// Yapay Zeka Hakem Değerlendirme Sonucu
class AiRefereeResult {
  final bool isApproved;
  final String formattedWord;
  final bool wasTypoCorrected;
  final String? originalTypo;
  final String explanation;
  final bool isNewlyLearned;

  const AiRefereeResult({
    required this.isApproved,
    required this.formattedWord,
    this.wasTypoCorrected = false,
    this.originalTypo,
    this.explanation = '',
    this.isNewlyLearned = false,
  });

  static const AiRefereeResult rejected = AiRefereeResult(
    isApproved: false,
    formattedWord: '',
    explanation: 'Kelime kategoriye uygun bulunmadı.',
  );
}

/// Akıllı Yapay Zeka Hakemi & Kendini Geliştiren Soru Havuzu Servisi
/// 
/// 1. Gelişmiş Türkçe Harf ve Yazım Hatası Düzelticisi (Typo Corrector)
/// 2. Çevrimdışı Kapsamlı Anlamsal Bilgi Motoru (Semantic Knowledge Base)
/// 3. İsteğe Bağlı Çevrimiçi LLM Entegrasyonu (Google Gemini REST API)
/// 4. Kendini Geliştiren Dinamik Soru Havuzu (Supabase & Yerel Hafıza)
class AiRefereeService {
  /// Opsiyonel Gemini API anahtarı (Varsa online LLM aktifleşir)
  static String? geminiApiKey;

  /// Hafızada tutulan ve dinamik olarak öğrenilen kelimeler: `categoryId -> Set<Word>`
  static final Map<String, Set<String>> _learnedWordsMemory = {};

  /// Başlangıçta öğrenilmiş kelimeleri Supabase'den yükleyip soru havuzlarını genişletir
  static Future<void> initialize() async {
    debugPrint('🧠 [AiRefereeService] Yapay Zeka Hakemi başlatılıyor...');

    if (SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        final response = await SupabaseService.client!
            .from('learned_category_words')
            .select('category_id, word, canonical_word')
            .order('created_at', ascending: true);

        int count = 0;
        for (final row in (response as List)) {
          final catId = row['category_id']?.toString();
          final word = (row['canonical_word'] ?? row['word'])?.toString();
          if (catId != null && word != null && word.trim().isNotEmpty) {
            _learnedWordsMemory.putIfAbsent(catId, () => {}).add(word.trim());
            // Kategori havuzuna da ekle
            final catIndex = sampleCategories.indexWhere((c) => c.id == catId);
            if (catIndex != -1) {
              sampleCategories[catIndex].addAcceptedWord(word.trim());
              count++;
            }
          }
        }
        debugPrint('🧠 [AiRefereeService] $count adet daha önce öğrenilmiş kelime havuzlara entegre edildi.');
      } catch (e) {
        debugPrint('🧠 [AiRefereeService] Supabase öğrenilmiş kelimeler tablosu kontrolü: $e');
      }
    }
  }

  /// Yeni onaylanan bir kelimeyi soru havuzuna kaydeder ve gelecekteki tüm maçlar için kalıcı hale getirir
  static Future<void> learnNewWord({
    required Category category,
    required String word,
    String? explanation,
  }) async {
    final cleanWord = TurkishStrings.formatSentenceCase(word.trim());
    category.addAcceptedWord(cleanWord);
    _learnedWordsMemory.putIfAbsent(category.id, () => {}).add(cleanWord);

    debugPrint('🎓 [AiRefereeService] Kategori "${category.title}" havuzuna yeni kelime eklendi: $cleanWord');

    // Supabase'e asenkron kaydet (Tüm oyuncular faydalansın)
    if (SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        await SupabaseService.client!.from('learned_category_words').insert({
          'category_id': category.id,
          'category_title': category.title,
          'word': cleanWord.toLowerCase(),
          'canonical_word': cleanWord,
          'explanation': explanation ?? 'Yapay Zeka tarafından onaylandı',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('🧠 [AiRefereeService] Supabase kayıt uyarısı: $e');
      }
    }
  }

  /// Bir kelimeyi Yapay Zeka Hakemi ile değerlendirir
  static Future<AiRefereeResult> evaluateWord({
    required Category category,
    required String rawInput,
    required Set<String> alreadyUsedWords,
  }) async {
    final clean = rawInput.trim();
    if (clean.length < 2) return AiRefereeResult.rejected;

    final lowerInput = TurkishStrings.toLowerCaseTr(clean);
    final bool isProperNounCategory = category.id.contains('sehir') || category.id.contains('ulke');

    // 1. AŞAMA: Gelişmiş Türkçe Yazım Hatası Düzeltici (Typo Correction)
    // Var olan kabul edilmiş kelimeler ve öğrenilmiş kelimeler arasında harf hatası ara
    for (final accepted in category.acceptedWords) {
      if (alreadyUsedWords.any((u) => TurkishStrings.toLowerCaseTr(u) == TurkishStrings.toLowerCaseTr(accepted))) {
        continue;
      }

      if (_isAdvancedTypoMatch(lowerInput, TurkishStrings.toLowerCaseTr(accepted))) {
        final formatted = TurkishStrings.formatCorrectWord(accepted, isProperNoun: isProperNounCategory);
        return AiRefereeResult(
          isApproved: true,
          formattedWord: formatted,
          wasTypoCorrected: true,
          originalTypo: clean,
          explanation: 'Yazım hatası düzeltildi: $formatted',
          isNewlyLearned: false,
        );
      }
    }

    // 2. AŞAMA: Çevrimdışı Kapsamlı Anlamsal Bilgi Tabanı Doğrulaması
    final offlineCheck = _evaluateWithOfflineKnowledge(category, clean);
    if (offlineCheck.isApproved) {
      return offlineCheck;
    }

    // 3. AŞAMA: Çevrimiçi LLM Değerlendirmesi (Google Gemini) - Eğer anahtar varsa
    if (geminiApiKey != null && geminiApiKey!.isNotEmpty) {
      try {
        final onlineResult = await _queryGeminiAi(category, clean);
        if (onlineResult != null && onlineResult.isApproved) {
          return onlineResult;
        }
      } catch (e) {
        debugPrint('🧠 [AiRefereeService] Gemini online API sorgu hatası: $e');
      }
    }

    return AiRefereeResult.rejected;
  }

  /// Gelişmiş Türkçe harf benzerliği ve yazım hatası toleransı
  static bool _isAdvancedTypoMatch(String input, String target) {
    return TurkishStrings.isFuzzyMatch(input, target);
  }

  // ========================================================
  // ÇEVRİMDIŞI ANLAMSAL BİLGİ MOTORU (Kapsamlı Türkçe Sözlük ve Mantık Doğrulayıcı)
  // ========================================================
  static AiRefereeResult _evaluateWithOfflineKnowledge(Category category, String rawInput) {
    final lowerInput = TurkishStrings.toLowerCaseTr(rawInput);
    final isProperNounCategory = category.id.contains('sehir') ||
        category.id.contains('il') ||
        category.id.contains('ulke') ||
        category.title.toLowerCase().contains('şehir') ||
        category.title.toLowerCase().contains('ülke') ||
        category.title.toLowerCase().contains('il');

    final catId = category.id.toLowerCase();
    final catTitle = TurkishStrings.toLowerCaseTr(category.title);
    final catDesc = TurkishStrings.toLowerCaseTr(category.description);
    final combined = '$catId $catTitle $catDesc';

    final Set<List<String>> relevantPools = {};

    // 1. Şehirler & İller
    if (combined.contains('sehir') || combined.contains('il') || combined.contains('turkiye') || combined.contains('türkiye')) {
      relevantPools.add(_turkishProvinces);
    }
    // 2. Ülkeler & Başkentler
    if (combined.contains('ulke') || combined.contains('ülke') || combined.contains('dunya') || combined.contains('dünya') || combined.contains('baskent') || combined.contains('başkent')) {
      relevantPools.add(_worldCountries);
    }
    // 3. Suda Yaşayanlar & Balıklar
    if (combined.contains('deniz') || combined.contains('suda') || combined.contains('balik') || combined.contains('balık') || combined.contains('okyanus') || combined.contains('akvaryum')) {
      relevantPools.add(_waterCreatures);
    }
    // 4. Meyveler, Sebzeler, Yiyecekler, Kahvaltılıklar
    if (combined.contains('meyve') || combined.contains('sebze') || combined.contains('yiyecek') || combined.contains('kahvalti') || combined.contains('kahvaltı') || combined.contains('yemek') || combined.contains('tatli') || combined.contains('tatlı') || combined.contains('icecek') || combined.contains('içecek')) {
      relevantPools.add(_foodsAndProduce);
    }
    // 5. Hayvanlar, Kuşlar, Uçabilen Canlılar
    if (combined.contains('hayvan') || combined.contains('canli') || combined.contains('canlı') || combined.contains('kus') || combined.contains('kuş') || combined.contains('ucabilen') || combined.contains('uçabilen') || combined.contains('bocek') || combined.contains('böcek')) {
      relevantPools.add(_animalsAndBirds);
    }
    // 6. Mutfak Eşyaları & Pişirme Araçları
    if (combined.contains('mutfak') || combined.contains('esya') || combined.contains('eşya') || combined.contains('alet') || combined.contains('pisir') || combined.contains('pişir') || combined.contains('firin') || combined.contains('fırın')) {
      relevantPools.add(_kitchenAndHomeItems);
    }
    // 7. Taşıtlar & Ulaşım Araçları
    if (combined.contains('tasit') || combined.contains('taşıt') || combined.contains('arac') || combined.contains('araç') || combined.contains('ulasim') || combined.contains('ulaşım') || combined.contains('araba') || combined.contains('trafik') || combined.contains('ray') || combined.contains('ucak') || combined.contains('gemi')) {
      relevantPools.add(_vehicles);
    }
    // 8. Meslekler
    if (combined.contains('meslek') || combined.contains('is') || combined.contains('iş') || combined.contains('kariyer') || combined.contains('uzman')) {
      relevantPools.add(_professions);
    }
    // 9. Kış, Kar, Soğuk
    if (combined.contains('kis') || combined.contains('kış') || combined.contains('kar') || combined.contains('soguk') || combined.contains('soğuk') || combined.contains('buz') || combined.contains('don') || combined.contains('mevsim')) {
      relevantPools.add(_winterAndCold);
    }
    // 10. Yaz, Plaj, Kumsal, Deniz Tatili
    if (combined.contains('yaz') || combined.contains('plaj') || combined.contains('kumsal') || combined.contains('tatil') || combined.contains('gunes') || combined.contains('güneş') || combined.contains('yuzme') || combined.contains('yüzme')) {
      relevantPools.add(_summerAndBeach);
    }
    // 11. Piknik, Kamp, Doğa, Park
    if (combined.contains('piknik') || combined.contains('kamp') || combined.contains('mangal') || combined.contains('doga') || combined.contains('doğa') || combined.contains('orman') || combined.contains('park')) {
      relevantPools.add(_picnicAndCamping);
    }
    // 12. Sinema, Film, Dizi, Tiyatro
    if (combined.contains('sinema') || combined.contains('film') || combined.contains('dizi') || combined.contains('tiyatro') || combined.contains('perde') || combined.contains('salon')) {
      relevantPools.add(_cinemaAndMovie);
    }
    // 13. Hastane, Doktor, Sağlık, İlaç, Muayene
    if (combined.contains('hastane') || combined.contains('doktor') || combined.contains('saglik') || combined.contains('sağlık') || combined.contains('ilac') || combined.contains('ilaç') || combined.contains('tedavi') || combined.contains('muayene') || combined.contains('eczane') || combined.contains('hemsire') || combined.contains('hemşire')) {
      relevantPools.add(_hospitalAndHealth);
    }
    // 14. Düğün, Nikah, Evlilik, Parti, Kutlama
    if (combined.contains('dugun') || combined.contains('düğün') || combined.contains('nikah') || combined.contains('kina') || combined.contains('kına') || combined.contains('evlilik') || combined.contains('gelin') || combined.contains('damat') || combined.contains('parti') || combined.contains('kutlama') || combined.contains('nisan') || combined.contains('nişan')) {
      relevantPools.add(_weddingAndCelebration);
    }
    // 15. Uyku, Gece, Yatak
    if (combined.contains('uyku') || combined.contains('gece') || combined.contains('yatak') || combined.contains('ruya') || combined.contains('rüya') || combined.contains('dinlen')) {
      relevantPools.add(_sleepAndNight);
    }
    // 16. Okul, Sınıf, Ders, Kırtasiye, Üniversite
    if (combined.contains('okul') || combined.contains('sinif') || combined.contains('sınıf') || combined.contains('ders') || combined.contains('kirtasiye') || combined.contains('kırtasiye') || combined.contains('ogrenci') || combined.contains('öğrenci') || combined.contains('ogretmen') || combined.contains('öğretmen') || combined.contains('universite') || combined.contains('üniversite')) {
      relevantPools.add(_schoolAndStationery);
    }
    // 17. Uçak, Havaalanı, Havalimanı, Uçuş, Seyahat
    if (combined.contains('ucak') || combined.contains('uçak') || combined.contains('havaalani') || combined.contains('havaalanı') || combined.contains('havalimani') || combined.contains('havalimanı') || combined.contains('ucus') || combined.contains('uçuş') || combined.contains('bavul') || combined.contains('seyahat')) {
      relevantPools.add(_airportAndTravel);
    }
    // 18. Otel, Pansiyon, Turizm
    if (combined.contains('otel') || combined.contains('pansiyon') || combined.contains('resepsiyon') || combined.contains('turizm') || combined.contains('konakla')) {
      relevantPools.add(_hotelAndTourism);
    }
    // 19. Spor, Futbol, Basketbol, Fitness
    if (combined.contains('spor') || combined.contains('futbol') || combined.contains('basket') || combined.contains('fitness') || combined.contains('egzersiz') || combined.contains('antrenman') || combined.contains('kosu') || combined.contains('koşu') || combined.contains('gym')) {
      relevantPools.add(_sportsAndFitness);
    }
    // 20. Uzay, Gezegen, Astronomi
    if (combined.contains('uzay') || combined.contains('gezegen') || combined.contains('gokyuzu') || combined.contains('gökyüzü') || combined.contains('yildiz') || combined.contains('yıldız') || combined.contains('astronomi') || combined.contains('samanyolu')) {
      relevantPools.add(_spaceAndAstronomy);
    }
    // 21. Bilgisayar, Teknoloji, İnternet, Telefon
    if (combined.contains('bilgisayar') || combined.contains('teknoloji') || combined.contains('internet') || combined.contains('telefon') || combined.contains('yazilim') || combined.contains('yazılım') || combined.contains('elektronik') || combined.contains('cihaz')) {
      relevantPools.add(_technologyAndComputer);
    }
    // 22. Müzik, Çalgı, Enstrüman
    if (combined.contains('muzik') || combined.contains('müzik') || combined.contains('enstruman') || combined.contains('enstrüman') || combined.contains('calgi') || combined.contains('çalgı') || combined.contains('sarki') || combined.contains('şarkı') || combined.contains('saz') || combined.contains('ses')) {
      relevantPools.add(_musicAndInstruments);
    }
    // 23. Banyo, Hijyen, Temizlik
    if (combined.contains('banyo') || combined.contains('hijyen') || combined.contains('dus') || combined.contains('duş') || combined.contains('temizlik') || combined.contains('tuvalet')) {
      relevantPools.add(_bathroomAndHygiene);
    }
    // 24. Salon, Mobilya, Ev Eşyası
    if (combined.contains('salon') || combined.contains('mobilya') || combined.contains('ev') || combined.contains('oda') || combined.contains('dekorasyon') || combined.contains('esya') || combined.contains('eşya') || combined.contains('serilen')) {
      relevantPools.add(_livingRoomAndHome);
    }
    // 25. Giyim, Kıyafet, Ayakkabı, Aksesuar
    if (combined.contains('giyim') || combined.contains('kiyafet') || combined.contains('kıyafet') || combined.contains('giysi') || combined.contains('elbise') || combined.contains('ayakkabi') || combined.contains('ayakkabı') || combined.contains('aksesuar') || combined.contains('moda')) {
      relevantPools.add(_clothingAndAccessories);
    }
    // 26. Duygular, Hissiyat
    if (combined.contains('duygu') || combined.contains('his') || combined.contains('mutlu') || combined.contains('uzgun') || combined.contains('üzgün') || combined.contains('korku') || combined.contains('heyecan') || combined.contains('sevgi')) {
      relevantPools.add(_emotionsAndFeelings);
    }
    // 27. Rutinler, Aktiviteler, Pazar, Hobi
    if (combined.contains('rutin') || combined.contains('aktivite') || combined.contains('hafta sonu') || combined.contains('pazar') || combined.contains('hobi') || combined.contains('bos zaman') || combined.contains('boş zaman')) {
      relevantPools.add(_routinesAndHobbies);
    }

    // Arama havuzlarını tara
    for (final pool in relevantPools) {
      for (final candidate in pool) {
        if (TurkishStrings.isFuzzyMatch(lowerInput, candidate)) {
          if (_checkCategoryConstraints(category, candidate)) {
            final formatted = TurkishStrings.formatCorrectWord(candidate, isProperNoun: isProperNounCategory);
            final wasTypo = TurkishStrings.toLowerCaseTr(rawInput) != TurkishStrings.toLowerCaseTr(candidate);
            final explanation = wasTypo
                ? 'Yapay Zeka "$rawInput" girişini "$formatted" olarak düzeltti ve "${category.title}" için onayladı.'
                : 'Yapay Zeka Hakemi: "$formatted", "${category.title}" ile doğrudan ilişkili mantıklı bir cevaptır.';

            return AiRefereeResult(
              isApproved: true,
              formattedWord: formatted,
              wasTypoCorrected: wasTypo,
              originalTypo: wasTypo ? rawInput : null,
              explanation: explanation,
              isNewlyLearned: true,
            );
          }
        }
      }
    }

    return AiRefereeResult.rejected;
  }

  /// Kategori başlığındaki özel harf kuralı kontrolleri (Örn: "B ile başlayan", "K ile biten")
  static bool _checkCategoryConstraints(Category category, String candidateWord) {
    final title = category.title.toLowerCase();
    final lowerWord = TurkishStrings.toLowerCaseTr(candidateWord.trim());
    if (lowerWord.isEmpty) return false;

    // "X ile başlayan" kontrolü
    final startMatch = RegExp(r'([abcçdefgğhıijklmnoöprsştuüvyz])\s+harfi?\s+ile\s+başlayan', caseSensitive: false).firstMatch(title);
    if (startMatch != null) {
      final expectedChar = startMatch.group(1)?.toLowerCase();
      if (expectedChar != null && !lowerWord.startsWith(expectedChar)) {
        return false;
      }
    }

    // "X ile biten" kontrolü
    final endMatch = RegExp(r'([abcçdefgğhıijklmnoöprsştuüvyz])\s+harfi?\s+ile\s+biten', caseSensitive: false).firstMatch(title);
    if (endMatch != null) {
      final expectedChar = endMatch.group(1)?.toLowerCase();
      if (expectedChar != null && !lowerWord.endsWith(expectedChar)) {
        return false;
      }
    }

    return true;
  }

  // ========================================================
  // ÇEVRİMİÇİ GOOGLE GEMINI 1.5/2.0 REST API ENTEGRASYONU
  // ========================================================
  static Future<AiRefereeResult?> _queryGeminiAi(Category category, String input) async {
    final key = geminiApiKey;
    if (key == null || key.isEmpty) return null;

    final prompt = '''
Sen Türkçe kelime oyunu için uzman ve adil bir Yapay Zeka Hakemisin.
Kategori: "${category.title}" (Açıklama: "${category.description}")
Kullanıcının yazdığı cevap: "$input"

GÖREVİN:
1. Bu kelime verilen kategoriye mantıklı, geçerli ve doğru bir cevap mıdır?
2. Eğer cevapta küçük yazım/klavye/imla hataları varsa doğru halini düzelt.
3. Cevabını SADECE geçerli bir JSON olarak ver:
{
  "is_valid": true veya false,
  "corrected_word": "Düzeltilmiş ve ilk harfi büyük doğru kelime",
  "was_typo": true veya false,
  "explanation": "Neden kabul edildiğine veya reddedildiğine dair 1 cümlelik Türkçe açıklama"
}
''';

    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.1,
          "maxOutputTokens": 150,
          "responseMimeType": "application/json"
        }
      });

      request.write(body);
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
        final textPart = jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        if (textPart != null) {
          final parsed = jsonDecode(textPart) as Map<String, dynamic>;
          final isValid = parsed['is_valid'] == true;
          final correctedWord = parsed['corrected_word']?.toString() ?? input;
          final wasTypo = parsed['was_typo'] == true;
          final explanation = parsed['explanation']?.toString() ?? 'Yapay Zeka tarafından onaylandı.';

          if (isValid) {
            return AiRefereeResult(
              isApproved: true,
              formattedWord: TurkishStrings.formatSentenceCase(correctedWord),
              wasTypoCorrected: wasTypo,
              originalTypo: wasTypo ? input : null,
              explanation: explanation,
              isNewlyLearned: true,
            );
          }
        }
      }
    } finally {
      client.close();
    }
    return null;
  }

  // ========================================================
  // KAPSAMLI ÇEVRİMDIŞI SÖZLÜK VE ANLAMSAL BİLGİ VERİLERİ
  // ========================================================

  static const List<String> _turkishProvinces = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin', 'Aydın',
    'Balıkesir', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı',
    'Çorum', 'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir',
    'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Isparta', 'Mersin', 'İstanbul',
    'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya',
    'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir',
    'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ',
    'Tokat', 'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak', 'Aksaray',
    'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan', 'Iğdır', 'Yalova',
    'Karabük', 'Kilis', 'Osmaniye', 'Düzce', 'Alanya', 'Bodrum', 'Fethiye', 'Marmaris', 'Çeşme',
    'Kuşadası', 'Gebze', 'Bandırma', 'İnegöl', 'İskenderun', 'Tarsus', 'Siverek', 'Erbaa'
  ];

  static const List<String> _worldCountries = [
    'Türkiye', 'Almanya', 'Fransa', 'İtalya', 'İspanya', 'İngiltere', 'Portekiz', 'Hollanda',
    'Belçika', 'İsviçre', 'Avusturya', 'İsveç', 'Norveç', 'Danimarka', 'Finlandiya', 'İzlanda',
    'Polonya', 'Yunanistan', 'Bulgaristan', 'Romanya', 'Macaristan', 'Çekya', 'Slovakya',
    'Hırvatistan', 'Sırbistan', 'Bosna Hersek', 'Arnavutluk', 'Karadağ', 'Kuzey Makedonya',
    'Rusya', 'Ukrayna', 'Gürcistan', 'Ermenistan', 'Azerbaycan', 'İran', 'Irak', 'Suriye',
    'Lübnan', 'Ürdün', 'İsrail', 'Suudi Arabistan', 'Katar', 'Kuveyt', 'Birleşik Arap Emirlikleri',
    'Umman', 'Yemen', 'Mısır', 'Fas', 'Tunus', 'Cezayir', 'Libya', 'Sudan', 'Güney Afrika',
    'Nijerya', 'Kenya', 'Etiyopya', 'Gana', 'Senegal', 'Japonya', 'Güney Kore', 'Çin', 'Hindistan',
    'Pakistan', 'Bangladeş', 'Endonezya', 'Malezya', 'Singapur', 'Tayland', 'Vietnam', 'Filipinler',
    'Avustralya', 'Yeni Zelanda', 'Amerika Birleşik Devletleri', 'Kanada', 'Meksika', 'Brezilya',
    'Arjantin', 'Şili', 'Kolombiya', 'Peru', 'Uruguay', 'Paraguay', 'Venezuela', 'Küba'
  ];

  static const List<String> _waterCreatures = [
    'barbunya', 'lüfer', 'istavrit', 'palamut', 'mezgit', 'kefal', 'kılıç balığı', 'turna',
    'alabalık', 'yayın balığı', 'zargana', 'orfoz', 'çaça', 'kolyoz', 'mercan', 'çipura',
    'levrek', 'kalamar', 'ahtapot', 'sübye', 'ıstakoz', 'kerevit', 'yengeç', 'deniz hıyarı',
    'denizatı', 'vatoz', 'köpekbalığı', 'orka', 'beluga', 'balina', 'yunus', 'fok', 'mors',
    'su samuru', 'deniz kaplumbağası', 'caretta caretta', 'denizanası', 'midye', 'istiridye',
    'karides', 'somon', 'hamsi', 'sardalya', 'uskumru', 'çinekop', 'torik', 'kalkan',
    'dil balığı', 'tekir', 'mercan balığı', 'dülger balığı', 'lapin', 'isparoz', 'gümüş balığı'
  ];

  static const List<String> _foodsAndProduce = [
    'kumkuat', 'yaban mersini', 'liçi', 'pitaya', 'avokado', 'mango', 'ananas', 'ejder meyvesi',
    'hindistan cevizi', 'papaya', 'guava', 'böğürtlen', 'frambuaz', 'kivi', 'çarkıfelek',
    'hünnap', 'muşmula', 'kızılcık', 'karadut', 'ahududu', 'kuşburnu', 'enginar', 'kuşkonmaz',
    'brokoli', 'brüksel lahanası', 'kereviz', 'şalgam', 'yer elması', 'bamya', 'pırasa',
    'pazı', 'roka', 'tere', 'semizotu', 'dereotu', 'nane', 'fesleğen', 'biberiye', 'kekik',
    'zencefil', 'zerdeçal', 'alıç', 'trabzon hurması', 'cennet hurması', 'dağ çileği',
    'kestane', 'fıstık', 'antep fıstığı', 'ceviz', 'fındık', 'badem', 'kaju', 'çam fıstığı',
    'kabak çekirdeği', 'ay çekirdeği', 'hurma', 'incir', 'kuru üzüm', 'kayısı', 'kuru erik',
    'kaymak', 'labne', 'lor', 'kaşar', 'tulum peyniri', 'gravyer', 'mozzarella', 'parmesan',
    'hellim', 'pastırma', 'kavurma', 'füme et', 'tahin', 'pekmez', 'acuka', 'menemen',
    'kuymak', 'muhlama', 'gözleme', 'pişi', 'simit', 'açma', 'çörek', 'kruvasan'
  ];

  static const List<String> _animalsAndBirds = [
    'albatros', 'tukan', 'kolibri', 'saka', 'iskete', 'florya', 'ispinoz', 'ardıç', 'sığırcık',
    'ibibik', 'guguk', 'yalıçapkını', 'ebabil', 'kırlangıç', 'akbaba', 'kartal', 'şahin',
    'doğan', 'atmaca', 'kerkenez', 'baykuş', 'puhu', 'kukumav', 'pelikan', 'flamingo',
    'karabatak', 'balıkçıl', 'leylek', 'turna', 'ördek', 'kaz', 'kuğu', 'sülün', 'bıldırcın',
    'keklik', 'çulluk', 'üveyik', 'kumru', 'güvercin', 'karga', 'saksağan', 'kuzgun',
    'vaşak', 'puma', 'jaguar', 'leopar', 'çita', 'sırtlan', 'çakal', 'dingo', 'mirket',
    'lemur', 'koala', 'vombat', 'ornitorenk', 'armadillo', 'tembel hayvan', 'pangolin',
    'karıncayiyen', 'oklu kirpi', 'kirpi', 'köstebek', 'sincap', 'kunduz', 'gelincik',
    'sansar', 'porsuk', 'samur', 'kapibara', 'kobay', 'şinşilla', 'tarantula', 'akrep'
  ];

  static const List<String> _kitchenAndHomeItems = [
    'airfryer', 'fritöz', 'nihale', 'spatula', 'çırpıcı', 'kevgir', 'kepçe', 'fırın tepsisi',
    'borcam', 'kavanoz', 'sürahi', 'karaf', 'tirbüşon', 'konserve açacağı', 'sarımsak ezici',
    'narenciye sıkacağı', 'rondo', 'mikrodalga', 'tost makinesi', 'waffle makinesi', 'semaver',
    'termos', 'matara', 'güveç', 'saç tava', 'döküm tava', 'wok tava', 'düdüklü tencere',
    'buharlı pişirici', 'ekmek kızartma makinesi', 'kahve makinesi', 'french press', 'moka pot',
    'fincan', 'kupa', 'çerezlik', 'sosluk', 'yağdanlık', 'sirkelik', 'tuzluk', 'biberlik',
    'ekmek sepeti', 'kesme tahtası', 'peçetelik', 'nihale', 'önlük', 'tutacak', 'fırın eldiveni'
  ];

  static const List<String> _vehicles = [
    'tramvay', 'teleferik', 'metrobüs', 'feribot', 'vapur', 'kano', 'gondol', 'yelkenli',
    'kruvaziyer', 'denizaltı', 'zeplin', 'planör', 'yamaç paraşütü', 'helikopter', 'dron',
    'scooter', 'sukuter', 'kaykay', 'paten', 'fayton', 'monoray', 'hızlı tren', 'mavna',
    'katamaran', 'sürat teknesi', 'jetski', 'hoverkraft', 'kar arabası', 'atv', 'utv',
    'traktör', 'biçerdöver', 'forklift', 'vinç', 'buldozer', 'greyder', 'itfaiye aracı',
    'ambulans', 'polis otosu', 'çekici', 'karavan', 'limuzin', 'kamyonet', 'tır'
  ];

  static const List<String> _professions = [
    'yazılımcı', 'grafiker', 'mimar', 'psikolog', 'veteriner', 'astronot', 'pilot', 'kaptan',
    'makinist', 'biyolog', 'arkeolog', 'jeolog', 'sosyolog', 'fizyoterapist', 'diyetisyen',
    'eczacı', 'hemşire', 'cerrah', 'avukat', 'hakim', 'savcı', 'noter', 'gazeteci', 'muhabir',
    'spiker', 'senarist', 'yönetmen', 'kameraman', 'koreograf', 'heykeltıraş', 'ressam',
    'müzisyen', 'besteci', 'şef', 'aşçı', 'barista', 'sommelier', 'garson', 'barmen',
    'marangoz', 'tesisatçı', 'kaynakçı', 'elektrikçi', 'tornacı', 'demirci', 'kuyumcu',
    'saatçi', 'optisyen', 'fotoğrafçı', 'terzi', 'kuaför', 'berber', 'itfaiyeci', 'astronot'
  ];

  static const List<String> _winterAndCold = [
    'kar', 'kardan adam', 'soba', 'eldiven', 'atkı', 'bere', 'bot', 'mont',
    'mandalina', 'kestane', 'salep', 'sıcak çikolata', 'kayak', 'buz',
    'fırtına', 'şömine', 'battaniye', 'kalın çorap', 'ıhlamur', 'grip',
    'kar topu', 'polar', 'yorgan', 'kızak', 'termal içlik', 'kazak', 'çorba',
    'odun', 'kar küresi', 'çizme', 'kalorifer', 'soğuk', 'kar tatili', 'yün çorap',
    'pekmez', 'portakal', 'tipi', 'tiftik', 'şal', 'hırka', 'buz pateni',
    'nane limon', 'kuşburnu', 'kar zinciri', 'don', 'kırağı', 'termometre',
    'soba borusu', 'kül', 'kuzine', 'kar helvası', 'buzdağı', 'buz sarkıtı'
  ];

  static const List<String> _summerAndBeach = [
    'deniz', 'kumsal', 'kum', 'güneş', 'güneş kremi', 'şezlong', 'şemsiye',
    'mayo', 'bikini', 'terlik', 'dondurma', 'karpuz', 'palet', 'şnorkel',
    'simit', 'havlu', 'dalga', 'bronzlaşmak', 'deniz kabuğu', 'sahil',
    'tekne', 'soğuk içecek', 'şort', 'güneş gözlüğü', 'hasır şapka', 'yelken',
    'palmiye', 'deniz yatağı', 'can simidi', 'can yeleği', 'kumdan kale',
    'denizanası', 'midye', 'plaj voleybolu', 'bronzlaştırıcı', 'pareo',
    'soğuk kahve', 'buzlu çay', 'iskele', 'koy', 'yat', 'sörf', 'buz',
    'vantilatör', 'klima', 'deniz şortu', 'hasır çanta', 'limonata', 'deniz topu'
  ];

  static const List<String> _picnicAndCamping = [
    'termos', 'çay', 'mangal', 'örtü', 'sofra bezi', 'top', 'hamak',
    'köfte', 'sucuk', 'domates', 'karpuz', 'çekirdek', 'plastik tabak',
    'çatal', 'karınca', 'salıncak', 'sepet', 'minder', 'gazoz', 'maşa',
    'kömür', 'piknik tüpü', 'ıslak mendil', 'tavla', 'frisbee', 'biber',
    'çadır', 'uyku tulumu', 'mat', 'fener', 'kamp ateşi', 'kamp sandalyesi',
    'kamp masası', 'odun', 'kibrit', 'çakmak', 'doğa yürüyüşü', 'pusula',
    'matara', 'sinek ilacı', 'böcek', 'ağaç', 'çimen', 'göl', 'çakı'
  ];

  static const List<String> _cinemaAndMovie = [
    'patlamış mısır', 'mısır', 'kola', 'bilet', 'perde', 'dev ekran',
    'koltuk', 'gözlük', 'karanlık', 'fragman', 'film', 'seans',
    'ses sistemi', 'projektör', 'afiş', 'salon', 'yer gösterici',
    'jenerik', 'nachos', 'ara', '3d gözlük', 'hoparlör', 'bilet kontrol',
    'biletçi', 'mısır kovası', 'koltuk numarası', 'altyazı', 'dublaj', 'gişe',
    'fuaye', 'yönetmen', 'oyuncu', 'senaryo', 'kamera', 'vizyon', 'oscar',
    'prömiyer', 'sinema bileti', 'sinema salonu', 'popcorn'
  ];

  static const List<String> _hospitalAndHealth = [
    'stetoskop', 'şırınga', 'iğne', 'doktor', 'hemşire', 'serum', 'sedye',
    'önlük', 'maske', 'eldiven', 'pamuk', 'yara bandı', 'tansiyon aleti',
    'termometre', 'reçete', 'ilaç', 'röntgen', 'tahlil', 'tekerlekli sandalye',
    'pansuman', 'serum askısı', 'ultrason', 'ameliyathane', 'acil', 'alçı',
    'kan alma', 'hastabakıcı', 'acil servis', 'enjektör', 'sargı bezi',
    'neşter', 'oksijen tüpü', 'hastane odası', 'randevu', 'poliklinik',
    'başhekim', 'laboratuvar', 'mr', 'tomografi', 'ambulans', 'aşı',
    'serum şişesi', 'hasta yatağı', 'ateş ölçer', 'dezenfektan'
  ];

  static const List<String> _weddingAndCelebration = [
    'gelin', 'damat', 'gelinlik', 'damatlık', 'pasta', 'halay', 'takı',
    'altın', 'kemençe', 'davul', 'zurna', 'oyun havası', 'çiçek', 'nikah',
    'konvoy', 'dans', 'yüzük', 'duvak', 'konfeti', 'fotoğrafçı', 'orkestra',
    'bahşiş', 'şahit', 'kaynana', 'görümce', 'nedime', 'kına', 'nikah şekeri',
    'çeyrek altın', 'damat traşı', 'halay başı', 'kına gecesi', 'takı merasimi',
    'gelin arabası', 'havai fişek', 'düğün salonu', 'gelin çiçeği', 'kuaför',
    'şampanya', 'gelin buketi', 'alyans', 'altın bilezik', 'düğün davetiyesi'
  ];

  static const List<String> _sleepAndNight = [
    'koyun saymak', 'telefona bakmak', 'su içmek', 'kitap okumak',
    'müzik dinlemek', 'volta atmak', 'dizi izlemek', 'balkona çıkmak',
    'ılık süt içmek', 'tavanı izlemek', 'sosyal medya', 'pencereyi açmak',
    'yatakta dönmek', 'derin nefes almak', 'saate bakmak', 'buzdolabını açmak',
    'düşüncelere dalmak', 'yastığı çevirmek', 'podcast dinlemek',
    'yastık', 'yorgan', 'çarşaf', 'pijama', 'gece lambası', 'alarm',
    'uyku bandı', 'rüya', 'esnemek', 'karanlık', 'sessizlik'
  ];

  static const List<String> _schoolAndStationery = [
    'tahta', 'tebeşir', 'sıra', 'masa', 'öğretmen', 'öğrenci', 'defter',
    'kitap', 'kalem', 'silgi', 'kalemtraş', 'cetvel', 'çanta', 'okul çantası',
    'zil', 'teneffüs', 'ders', 'sınav', 'karne', 'nöbetçi', 'müdür',
    'önlük', 'forma', 'harita', 'küre', 'kalemlik', 'pergel', 'boya',
    'pastel boya', 'kütüphane', 'kantin', 'ödev', 'yoklama', 'proje',
    'laboratuvar', 'zımba', 'ataş', 'dosya', 'fosforlu kalem', 'uçlu kalem'
  ];

  static const List<String> _airportAndTravel = [
    'uçak', 'bavul', 'valiz', 'pasaport', 'vize', 'bilet', 'biniş kartı',
    'pilot', 'hostes', 'kabin memuru', 'pist', 'terminal', 'bagaj',
    'güvenlik', 'x-ray', 'duty free', 'kapı', 'gate', 'uçağa biniş',
    'rötar', 'türbülans', 'koltuk', 'emniyet kemeri', 'el bagajı', 'aktarma',
    'pasaport kontrol', 'check-in', 'uçuş', 'havaalanı', 'uçak kanadı', 'kule'
  ];

  static const List<String> _hotelAndTourism = [
    'oda', 'yatak', 'resepsiyon', 'anahtar', 'oda kartı', 'bavul', 'havlu',
    'sabun', 'şampuan', 'minibar', 'balkon', 'kahvaltı', 'açık büfe',
    'oda servisi', 'havuz', 'lobi', 'asansör', 'temizlikçi', 'çarşaf',
    'yastık', 'kasa', 'klima', 'fatura', 'çıkış', 'giriş', 'bellboy', 'spa'
  ];

  static const List<String> _sportsAndFitness = [
    'futbol', 'basketbol', 'voleybol', 'tenis', 'koşu', 'yürüyüş', 'yüzme',
    'fitness', 'halter', 'dambıl', 'ağırlık', 'koşu bandı', 'pilates',
    'yoga', 'mat', 'forma', 'krampon', 'spor ayakkabı', 'ter bandı',
    'matara', 'protein tozu', 'şınav', 'mekik', 'barfiks', 'boks',
    'eldiven', 'raket', 'file', 'kale', 'düdük', 'hakem', 'sarı kart',
    'kırmızı kart', 'kaleci', 'forvet', 'basket potası', 'penaltı'
  ];

  static const List<String> _spaceAndAstronomy = [
    'güneş', 'ay', 'dünya', 'mars', 'jüpiter', 'satürn', 'venüs', 'merkür',
    'uranüs', 'neptün', 'plüton', 'yıldız', 'kuyruklu yıldız', 'kara delik',
    'galaksi', 'samanyolu', 'asteroit', 'meteor', 'roket', 'uzay mekiği',
    'astronot', 'uzay istasyonu', 'teleskop', 'uydu', 'yerçekimi', 'yörünge',
    'ışık yılı', 'uzaylı', 'atmosfer', 'krater', 'supernova', 'nebula'
  ];

  static const List<String> _technologyAndComputer = [
    'bilgisayar', 'laptop', 'telefon', 'akıllı telefon', 'tablet', 'klavye',
    'fare', 'mouse', 'monitör', 'ekran', 'kulaklık', 'hoparlör', 'mikrofon',
    'kamera', 'webcam', 'yazıcı', 'tarayıcı', 'modem', 'wi-fi', 'internet',
    'şarj aleti', 'powerbank', 'usb', 'flash bellek', 'hard disk', 'ram',
    'işlemci', 'yazılım', 'kodlama', 'yapay zeka', 'oyun konsolu', 'bluetooth'
  ];

  static const List<String> _musicAndInstruments = [
    'gitar', 'piyano', 'keman', 'bağlama', 'saz', 'davul', 'bateri',
    'flüt', 'klarnet', 'trompet', 'çello', 'kanun', 'ud', 'darbuka',
    'ney', 'armonika', 'akordeon', 'zil', 'mikrofon', 'kulaklık', 'nota',
    'akor', 'konser', 'beste', 'şarkı', 'solist', 'ritim', 'melodi', 'albüm'
  ];

  static const List<String> _bathroomAndHygiene = [
    'sabun', 'şampuan', 'duş jeli', 'lif', 'havlu', 'diş fırçası',
    'diş macunu', 'ayna', 'lavabo', 'klozet', 'küvet', 'duşakabin',
    'musluk', 'tuvalet kağıdı', 'tarak', 'saç kurutma makinesi',
    'tıraş bıçağı', 'tırnak makası', 'pamuk', 'kulak çöpü', 'parfüm',
    'deodorant', 'çamaşır sepeti', 'banyo paspası', 'sıvı sabun', 'kese'
  ];

  static const List<String> _livingRoomAndHome = [
    'koltuk', 'kanepe', 'sehpa', 'televizyon', 'tv ünitesi', 'halı',
    'perde', 'kırlent', 'yastık', 'lamba', 'avize', 'kitaplık', 'tablo',
    'vazo', 'çiçek', 'kumanda', 'saat', 'duvar saati', 'berjer', 'konsol',
    'vitrin', 'abajur', 'pencere', 'biblo', 'masa', 'sandalye', 'şömine'
  ];

  static const List<String> _clothingAndAccessories = [
    'pantolon', 'gömlek', 'tişört', 'kazak', 'ceket', 'mont', 'palto',
    'etek', 'elbise', 'hırka', 'yelek', 'şort', 'pijama', 'eşofman',
    'çorap', 'iç çamaşırı', 'kemer', 'kravat', 'papyon', 'şapka', 'atkı',
    'bere', 'eldiven', 'ayakkabı', 'bot', 'çizme', 'terlik', 'sandalet',
    'spor ayakkabı', 'çanta', 'cüzdan', 'saat', 'kolye', 'bilezik', 'küpe'
  ];

  static const List<String> _emotionsAndFeelings = [
    'mutlu', 'neşeli', 'heyecanlı', 'huzurlu', 'sevinçli', 'sakin',
    'yorgun', 'uykusuz', 'üzgün', 'kızgın', 'sinirli', 'şaşkın',
    'meraklı', 'umutlu', 'gururlu', 'sevgi', 'neşe', 'kahkaha', 'tebessüm',
    'sarılmak', 'korku', 'panik', 'endişe', 'özlem', 'aşk', 'şefkat'
  ];

  static const List<String> _routinesAndHobbies = [
    'uyumak', 'uyanmak', 'kitap okumak', 'müzik dinlemek', 'yürüyüş yapmak',
    'kahve içmek', 'film izlemek', 'dizi izlemek', 'duş almak', 'yemek yemek',
    'su içmek', 'telefonla konuşmak', 'mesajlaşmak', 'koşmak', 'dinlenmek',
    'temizlik yapmak', 'yemek pişirmek', 'alışveriş yapmak', 'resim yapmak',
    'bahçe işleri', 'bisiklete binmek', 'arkadaşlarla buluşmak', 'tavla oynamak'
  ];
}
