import 'dart:math';

/// Türkçe karakter duyarlı metin işleme, formatlama ve Levenshtein benzerlik motoru
class TurkishStrings {
  /// Türkçe kurallarına uygun küçük harfe çevirme
  static String toLowerCaseTr(String text) {
    return text
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase()
        .trim();
  }

  /// Türkçe kurallarına uygun büyük harfe çevirme
  static String toUpperCaseTr(String text) {
    return text
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ş', 'Ş')
        .replaceAll('ö', 'Ö')
        .replaceAll('ç', 'Ç')
        .toUpperCase()
        .trim();
  }

  /// Karşılaştırma için normalizasyon
  static String normalize(String text) {
    return toLowerCaseTr(text)
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  /// Cümle içi formatı: Sadece ilk harfi büyük, geri kalanı küçük (Örn: "Halı", "Deniz yatağı")
  static String formatSentenceCase(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return clean;

    final lower = toLowerCaseTr(clean);
    final firstChar = toUpperCaseTr(lower[0]);
    if (lower.length == 1) return firstChar;
    return '$firstChar${lower.substring(1)}';
  }

  /// Başlık formatı (Özel isimler veya iller için): Her kelimenin ilk harfi büyük (Örn: "Balıkesir", "Kuzey Kıbrıs")
  static String formatTitleCase(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return clean;

    final words = clean.split(RegExp(r'\s+'));
    return words.map((w) => formatSentenceCase(w)).join(' ');
  }

  /// Doğru kelime formatlama (Özel isim/şehir ise TitleCase, değilse SentenceCase)
  static String formatCorrectWord(String text, {bool isProperNoun = false}) {
    if (isProperNoun) {
      return formatTitleCase(text);
    }
    return formatSentenceCase(text);
  }

  /// Türkçe karakterleri aksansız/düz harflere çevirir (ç->c, ş->s, ı->i, ö->o, ü->u, ğ->g, â->a)
  static String removeAccents(String text) {
    return toLowerCaseTr(text)
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  /// Yan yana basılan çift/tekrar eden harfleri teke indirger (Örn: "kilimm" -> "kilim", "elmma" -> "elma")
  static String squashRepeatedChars(String text) {
    if (text.isEmpty) return text;
    final sb = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 0 || text[i] != text[i - 1]) {
        sb.write(text[i]);
      }
    }
    return sb.toString();
  }

  /// Boşlukları ve noktalama işaretlerini kaldırır (Örn: "kardan adam" -> "kardanadam")
  static String removeSpacesAndPunctuation(String text) {
    return text.replaceAll(RegExp(r'''[\s\-_'",./\\!?:;]+'''), '');
  }

  /// Türkçe isim kökü ve gövdesi türetme (Morfolojik Kök Bulucu)
  /// Çoğul (-ler/-lar), iyelik, yönelme, bulunma, ayrılma eklerini soyar.
  /// Örn: "eldivenler" -> ["eldivenler", "eldiven"], "şömineler" -> ["şömineler", "şömine"]
  static Set<String> stemTurkishNoun(String rawWord) {
    final lower = toLowerCaseTr(rawWord).trim();
    final results = <String>{lower};
    if (lower.length <= 3) return results;

    // Eğer çok kelimeli bir tamlama ise son kelimeye ek kontrolü uygula (Örn: "kardan adamlar" -> "kardan adam")
    final words = lower.split(RegExp(r'\s+'));
    if (words.length > 1) {
      final lastWord = words.last;
      final lastStems = stemTurkishNoun(lastWord);
      for (final ls in lastStems) {
        final prefix = words.sublist(0, words.length - 1).join(' ');
        results.add('$prefix $ls');
      }
    }

    String current = lower;

    // 1. Çoğul ve ayrılma/bulunma bileşikleri: -lerden, -lardan, -lerde, -larda, -lere, -lara
    final compoundSuffixes = ['lerden', 'lardan', 'lerde', 'larda', 'lere', 'lara', 'lerin', 'ların', 'lerini', 'larını'];
    for (final s in compoundSuffixes) {
      if (current.endsWith(s) && current.length - s.length >= 3) {
        results.add(current.substring(0, current.length - s.length));
      }
    }

    // 2. Çoğul ekleri: -ler, -lar
    if ((current.endsWith('ler') || current.endsWith('lar')) && current.length >= 5) {
      final stem = current.substring(0, current.length - 3);
      if (stem.length >= 3) {
        results.add(stem);
        current = stem;
      }
    }

    // 3. Hal ekleri: -den, -dan, -ten, -tan, -de, -da, -te, -ta
    final caseSuffixes = ['den', 'dan', 'ten', 'tan', 'de', 'da', 'te', 'ta'];
    for (final s in caseSuffixes) {
      if (current.endsWith(s) && current.length - s.length >= 3) {
        results.add(current.substring(0, current.length - s.length));
      }
    }

    // 4. Belirtme ve iyelik ekleri: -i, -ı, -u, -ü, -si, -sı, -su, -sü, -ye, -ya, -e, -a
    final singleSuffixes = ['si', 'sı', 'su', 'sü', 'yi', 'yı', 'yu', 'yü', 'ye', 'ya', 'le', 'la', 'i', 'ı', 'u', 'ü', 'e', 'a'];
    for (final s in singleSuffixes) {
      if (current.endsWith(s) && current.length - s.length >= 3) {
        results.add(current.substring(0, current.length - s.length));
      }
    }

    return results;
  }

  /// İki kelime arasındaki Levenshtein Düzenleme Mesafesi (Edit Distance)
  static int levenshteinDistance(String s1, String s2) {
    final a = normalize(s1);
    final b = normalize(s2);

    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> previousRow = List<int>.generate(b.length + 1, (i) => i);
    List<int> currentRow = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      currentRow[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = (a[i] == b[j]) ? 0 : 1;
        currentRow[j + 1] = [
          currentRow[j] + 1,
          previousRow[j + 1] + 1,
          previousRow[j] + cost,
        ].reduce(min);
      }
      previousRow = List.from(currentRow);
    }

    return currentRow[b.length];
  }

  /// Gelişmiş Türkçe Benzerlik ve Yazım Hatası Toleransı:
  /// 1. Tam Eşleşme (normalize)
  /// 2. Türkçe Karakter / Aksan Toleransı (c->ç, s->ş, o->ö, u->ü, g->ğ, i->ı)
  /// 3. Çift Basılan Harf Toleransı (kilimm -> kilim)
  /// 4. Boşluksuz / Birleşik Kelime Toleransı (kardanadam -> kardan adam)
  /// 5. Morfolojik Kök Eşleşmesi (eldivenler -> eldiven, pastalar -> pasta)
  /// 6. Toleranslı Levenshtein Mesafesi
  static bool isFuzzyMatch(String input, String target) {
    final normInput = normalize(input);
    final normTarget = normalize(target);

    // 1. Birebir eşitlik
    if (normInput == normTarget) return true;

    // 2. Aksansız/Türkçe karakter eşitliği (Örn: somine == şömine, cilek == çilek, hali == halı)
    final cleanInput = removeAccents(normInput);
    final cleanTarget = removeAccents(normTarget);
    if (cleanInput == cleanTarget) return true;

    // 3. Çift harf indirgeme (Örn: kilimm == kilim, elmma == elma)
    final squashedInput = squashRepeatedChars(cleanInput);
    final squashedTarget = squashRepeatedChars(cleanTarget);
    if (squashedInput == squashedTarget) return true;

    // 4. Boşluksuz / Birleşik kelime kontrolü (Örn: kardanadam == kardan adam, sicakcikolata == sıcak çikolata)
    final noSpaceInput = removeSpacesAndPunctuation(cleanInput);
    final noSpaceTarget = removeSpacesAndPunctuation(cleanTarget);
    if (noSpaceInput == noSpaceTarget) return true;

    // 5. Morfolojik Kök Kontrolü (Çoğul ve hal ekleri soyma)
    // Örn: "eldivenler" -> "eldiven", "şömineler" -> "şömine", "pastalar" -> "pasta"
    final inputStems = stemTurkishNoun(normInput);
    final targetStems = stemTurkishNoun(normTarget);

    for (final inStem in inputStems) {
      if (inStem == normTarget || removeAccents(inStem) == cleanTarget) return true;
      for (final tarStem in targetStems) {
        if (inStem == tarStem || removeAccents(inStem) == removeAccents(tarStem)) return true;
      }
    }
    for (final tarStem in targetStems) {
      if (normInput == tarStem || cleanInput == removeAccents(tarStem)) return true;
    }

    // 6. Düzenleme Mesafesi (Levenshtein) - Aksansız ve temizlenmiş metinler üzerinde
    final distance = levenshteinDistance(cleanInput, cleanTarget);

    if (cleanTarget.length <= 3) {
      // 3 veya daha az harfli kelimelerde yazım hatası toleransı tanımaz (et, ev, ay karışmasın)
      return false;
    }
    if (cleanTarget.length <= 6) {
      return distance <= 1; // Örn: kaysi -> kayisi (mesafe 1)
    }
    if (cleanTarget.length <= 10) {
      return distance <= 2;
    }
    return distance <= 3;
  }
}
