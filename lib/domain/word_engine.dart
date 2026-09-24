import '../core/utils/turkish_strings.dart';
import '../data/models/category.dart';
import 'ai_referee_service.dart';

enum WordValidationStatus {
  valid,
  correctedTypo,
  alreadyUsed,
  invalid,
}

class WordValidationResult {
  final WordValidationStatus status;
  final String matchedWord;
  final String? originalInput;
  final String message;
  final bool isAiApproved;
  final String? aiExplanation;

  const WordValidationResult({
    required this.status,
    required this.matchedWord,
    this.originalInput,
    required this.message,
    this.isAiApproved = false,
    this.aiExplanation,
  });

  bool get isValid =>
      status == WordValidationStatus.valid ||
      status == WordValidationStatus.correctedTypo;
}

class WordEngine {
  /// Bir kelime girişini doğrular (Hızlı Yerel & Senkron Kontrol).
  /// Doğru kelimeler ilk harfi büyük olacak şekilde (özel isimse TitleCase) formatlanır.
  static WordValidationResult validateWord({
    required String rawInput,
    required Category category,
    required Set<String> alreadyUsedWords,
  }) {
    final cleanInput = rawInput.trim();
    if (cleanInput.isEmpty) {
      return const WordValidationResult(
        status: WordValidationStatus.invalid,
        matchedWord: '',
        message: 'Lütfen bir kelime yazın!',
      );
    }

    final normalizedInput = TurkishStrings.toLowerCaseTr(cleanInput);
    final bool isProperNounCategory = category.id.contains('sehir') || category.id.contains('ulke');

    // 1. Zaten kullanılmış mı kontrolü
    for (final used in alreadyUsedWords) {
      final usedNorm = TurkishStrings.toLowerCaseTr(used);
      if (usedNorm == normalizedInput || TurkishStrings.isFuzzyMatch(normalizedInput, usedNorm)) {
        return WordValidationResult(
          status: WordValidationStatus.alreadyUsed,
          matchedWord: used,
          message: '"$used" daha önceden yazıldı!',
        );
      }
    }

    // 2. Tam Eşleşme (Exact Match)
    for (final target in category.acceptedWords) {
      if (TurkishStrings.toLowerCaseTr(target) == normalizedInput) {
        if (alreadyUsedWords.any((u) => TurkishStrings.toLowerCaseTr(u) == TurkishStrings.toLowerCaseTr(target))) {
          final matchedUsed = alreadyUsedWords.firstWhere((u) => TurkishStrings.toLowerCaseTr(u) == TurkishStrings.toLowerCaseTr(target));
          return WordValidationResult(
            status: WordValidationStatus.alreadyUsed,
            matchedWord: matchedUsed,
            message: '"$matchedUsed" daha önceden yazıldı!',
          );
        }

        final formatted = TurkishStrings.formatCorrectWord(target, isProperNoun: isProperNounCategory);
        return WordValidationResult(
          status: WordValidationStatus.valid,
          matchedWord: formatted,
          message: 'Doğru kelime!',
        );
      }
    }

    // 3. Harf Hatası Toleransı (Fuzzy Match / Levenshtein)
    for (final target in category.acceptedWords) {
      final isTargetAlreadyUsed = alreadyUsedWords.any(
        (u) => TurkishStrings.toLowerCaseTr(u) == TurkishStrings.toLowerCaseTr(target),
      );

      if (TurkishStrings.isFuzzyMatch(normalizedInput, target)) {
        if (isTargetAlreadyUsed) {
          final matchedUsed = alreadyUsedWords.firstWhere(
            (u) => TurkishStrings.toLowerCaseTr(u) == TurkishStrings.toLowerCaseTr(target),
          );
          return WordValidationResult(
            status: WordValidationStatus.alreadyUsed,
            matchedWord: matchedUsed,
            message: '"$matchedUsed" daha önceden yazıldı!',
          );
        }

        final formatted = TurkishStrings.formatCorrectWord(target, isProperNoun: isProperNounCategory);
        return WordValidationResult(
          status: WordValidationStatus.correctedTypo,
          matchedWord: formatted,
          originalInput: cleanInput,
          message: 'Düzeltildi: $formatted',
          isAiApproved: true,
          aiExplanation: 'Yapay Zeka yazım veya ek hatasını düzeltti.',
        );
      }
    }

    // 4. Eşleşme Bulunamadı (Geçersiz)
    return WordValidationResult(
      status: WordValidationStatus.invalid,
      matchedWord: cleanInput,
      message: 'Geçersiz kelime!',
    );
  }

  /// Yapay Zeka Hakemi Destekli Asenkron Doğrulama & Soru Havuzunu Otomatik Genişletme
  static Future<WordValidationResult> validateWordAsync({
    required String rawInput,
    required Category category,
    required Set<String> alreadyUsedWords,
  }) async {
    // 1. Önce hızlı yerel kontrolü çalıştır (0ms)
    final syncResult = validateWord(
      rawInput: rawInput,
      category: category,
      alreadyUsedWords: alreadyUsedWords,
    );

    // Eğer zaten geçerliyse veya zaten kullanılmışsa doğrudan dön
    if (syncResult.isValid || syncResult.status == WordValidationStatus.alreadyUsed) {
      return syncResult;
    }

    // 2. Eşleşmediyse -> Yapay Zeka Hakemine Danış!
    final aiResult = await AiRefereeService.evaluateWord(
      category: category,
      rawInput: rawInput,
      alreadyUsedWords: alreadyUsedWords,
    );

    if (aiResult.isApproved) {
      // Yapay zeka onaylasa bile halihazırda kullanılmış mı tekrar kontrol et
      final normAi = TurkishStrings.toLowerCaseTr(aiResult.formattedWord);
      final alreadyUsedMatch = alreadyUsedWords.firstWhere(
        (u) => TurkishStrings.toLowerCaseTr(u) == normAi,
        orElse: () => '',
      );
      if (alreadyUsedMatch.isNotEmpty) {
        return WordValidationResult(
          status: WordValidationStatus.alreadyUsed,
          matchedWord: alreadyUsedMatch,
          message: '"$alreadyUsedMatch" daha önceden yazıldı!',
        );
      }

      // Eğer kelime yeni onaylandıysa havuza ekle ve geleceğe kaydet
      if (aiResult.isNewlyLearned) {
        await AiRefereeService.learnNewWord(
          category: category,
          word: aiResult.formattedWord,
          explanation: aiResult.explanation,
        );
      }

      if (aiResult.wasTypoCorrected) {
        return WordValidationResult(
          status: WordValidationStatus.correctedTypo,
          matchedWord: aiResult.formattedWord,
          originalInput: rawInput,
          message: 'Düzeltildi: ${aiResult.formattedWord}',
          isAiApproved: true,
          aiExplanation: aiResult.explanation,
        );
      } else {
        return WordValidationResult(
          status: WordValidationStatus.valid,
          matchedWord: aiResult.formattedWord,
          message: aiResult.isNewlyLearned
              ? '🤖 Yapay Zeka Onayladı! Havuza Eklendi: ${aiResult.formattedWord}'
              : 'Doğru kelime!',
          isAiApproved: true,
          aiExplanation: aiResult.explanation,
        );
      }
    }

    return syncResult;
  }
}
