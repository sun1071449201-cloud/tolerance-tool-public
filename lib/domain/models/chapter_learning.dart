/// 章节学习卡：结论、边界、反例、检查清单、自测题和关联。
class ChapterLearning {
  const ChapterLearning({
    required this.summary,
    required this.boundaries,
    required this.counterexample,
    required this.checklist,
    required this.standard,
    required this.reviewedAt,
    required this.canonical,
    required this.seeAlso,
    required this.quickRefs,
    required this.relatedTools,
    required this.quiz,
  });

  final List<String> summary;
  final List<String> boundaries;
  final String counterexample;
  final List<String> checklist;
  final String standard;
  final String reviewedAt;
  final bool canonical;
  final List<String> seeAlso;
  final List<String> quickRefs;
  final List<String> relatedTools;
  final List<QuizQuestion> quiz;

  factory ChapterLearning.fromJson(Map<String, dynamic> j) {
    List<String> strs(String key) => [
          for (final v in (j[key] as List? ?? const []))
            if (v is String && v.trim().isNotEmpty) v.trim(),
        ];
    return ChapterLearning(
      summary: strs('summary'),
      boundaries: strs('boundaries'),
      counterexample: (j['counterexample'] ?? '').toString().trim(),
      checklist: strs('checklist'),
      standard: (j['standard'] ?? '').toString().trim(),
      reviewedAt: (j['reviewed_at'] ?? '').toString().trim(),
      canonical: j['canonical'] == true,
      seeAlso: strs('see_also'),
      quickRefs: strs('quick_refs'),
      relatedTools: strs('related_tools'),
      quiz: [
        for (final q in (j['quiz'] as List? ?? const []))
          if (q is Map<String, dynamic>) QuizQuestion.fromJson(q),
      ],
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int answer;
  final String explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        question: (j['q'] ?? '').toString().trim(),
        options: [
          for (final o in (j['options'] as List? ?? const []))
            if (o is String) o,
        ],
        answer: (j['answer'] as num?)?.toInt() ?? 0,
        explanation: (j['why'] ?? '').toString().trim(),
      );
}
