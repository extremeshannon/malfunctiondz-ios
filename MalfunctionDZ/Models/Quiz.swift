// File: ASC/Models/Quiz.swift
import Foundation
import SwiftUI
import MalfunctionDZCore

struct QuizDetail: Codable {
    let id: Int
    let title: String
    let passPercentage: Double
    let randomizeQuestions: Bool
    let isTimed: Bool
    let timeLimit: Int?
    let totalQuestions: Int
    let attemptCount: Int
    let lastAttempt: QuizLastAttempt?
    let questions: [QuizQuestion]

    enum CodingKeys: String, CodingKey {
        case id, title, questions
        case passPercentage   = "pass_percentage"
        case randomizeQuestions = "randomize_questions"
        case isTimed          = "is_timed"
        case timeLimit        = "time_limit"
        case totalQuestions   = "total_questions"
        case attemptCount     = "attempt_count"
        case lastAttempt      = "last_attempt"
    }
}

struct QuizLastAttempt: Codable {
    let id: Int
    let score: Double
    let passed: Bool
    let date: String?
}

struct QuizQuestion: Codable, Identifiable {
    let id: Int
    let pivotId: Int
    let text: String
    let type: String
    let points: Double
    let instructions: String?
    let imagePath: String?
    let choices: [QuizChoice]

    enum CodingKeys: String, CodingKey {
        case id, text, type, points, instructions, choices
        case pivotId    = "pivot_id"
        case imagePath  = "image_path"
    }
}

struct QuizChoice: Codable, Identifiable {
    let id: Int
    let text: String
}

struct QuizDetailResponse: Codable {
    let ok: Bool
    let quiz: QuizDetail?
    let error: String?
}

/// Top-level API envelope (success and error responses).
struct QuizAPIEnvelope: Codable {
    let ok: Bool
    let error: String?
    let detail: String?
}

struct QuizSubmitResponse: Codable {
    let ok: Bool
    let attemptId: Int
    let scorePct: Double
    let passed: Bool
    let passPercentage: Double
    let earnedPoints: Double
    let totalPoints: Double
    let correctCount: Int
    let totalCount: Int
    let results: [QuizQuestionResult]

    enum CodingKeys: String, CodingKey {
        case ok, passed, results
        case attemptId      = "attempt_id"
        case scorePct       = "score_pct"
        case passPercentage = "pass_percentage"
        case earnedPoints   = "earned_points"
        case totalPoints    = "total_points"
        case correctCount   = "correct_count"
        case totalCount     = "total_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        attemptId = try c.decodeIfPresent(Int.self, forKey: .attemptId) ?? 0
        scorePct = Self.decodeFlexibleDouble(c, key: .scorePct)
        passed = try c.decodeIfPresent(Bool.self, forKey: .passed) ?? false
        passPercentage = Self.decodeFlexibleDouble(c, key: .passPercentage)
        earnedPoints = Self.decodeFlexibleDouble(c, key: .earnedPoints)
        totalPoints = Self.decodeFlexibleDouble(c, key: .totalPoints)
        correctCount = try c.decodeIfPresent(Int.self, forKey: .correctCount) ?? 0
        totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        results = try c.decodeIfPresent([QuizQuestionResult].self, forKey: .results) ?? []
    }

    private static func decodeFlexibleDouble(
        _ c: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Double {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
        if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v }
        return 0
    }
}

struct QuizQuestionResult: Codable, Identifiable {
    var id: Int { questionId }
    let questionId: Int
    let questionText: String
    let selectedChoiceId: Int
    let selectedChoiceText: String
    let correctChoiceId: Int
    let correctChoiceText: String
    let isCorrect: Bool

    enum CodingKeys: String, CodingKey {
        case isCorrect          = "is_correct"
        case questionId         = "question_id"
        case questionText       = "question_text"
        case selectedChoiceId   = "selected_choice_id"
        case selectedChoiceText = "selected_choice_text"
        case correctChoiceId    = "correct_choice_id"
        case correctChoiceText  = "correct_choice_text"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        questionId = try c.decodeIfPresent(Int.self, forKey: .questionId) ?? 0
        questionText = try c.decodeIfPresent(String.self, forKey: .questionText) ?? ""
        selectedChoiceId = try c.decodeIfPresent(Int.self, forKey: .selectedChoiceId) ?? 0
        selectedChoiceText = try c.decodeIfPresent(String.self, forKey: .selectedChoiceText) ?? ""
        correctChoiceId = try c.decodeIfPresent(Int.self, forKey: .correctChoiceId) ?? 0
        correctChoiceText = try c.decodeIfPresent(String.self, forKey: .correctChoiceText) ?? ""
        isCorrect = try c.decodeIfPresent(Bool.self, forKey: .isCorrect) ?? false
    }
}

// MARK: - Quiz text (LMS stores `<p>…</p>` and entities like &rsquo;)

enum QuizTextFormat {
    private static let entities: [(String, String)] = [
        ("&rsquo;", "'"), ("&lsquo;", "'"), ("&#8217;", "'"), ("&#39;", "'"),
        ("&rdquo;", "\""), ("&ldquo;", "\""), ("&#8221;", "\""), ("&#8220;", "\""), ("&quot;", "\""),
        ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
    ]

    /// Clean display string — no HTML tags, decoded entities.
    static func displayText(from html: String) -> String {
        var s = html.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }

        // Block tags → line breaks, then strip remaining tags.
        s = s.replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</p>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</li>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        for (entity, character) in entities {
            s = s.replacingOccurrences(of: entity, with: character)
        }

        while s.contains("\n\n\n") {
            s = s.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct QuizRichText: View {
    let html: String
    var fontSize: CGFloat = 17
    var weight: Font.Weight = .regular
    var color: Color
    var alignment: TextAlignment = .leading

    private var display: String { QuizTextFormat.displayText(from: html) }

    var body: some View {
        Text(display)
            .font(.system(size: fontSize, weight: weight))
            .foregroundColor(color)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }
}

/// A, B, C … for choice rows.
func quizChoiceLetter(index: Int) -> String {
    guard index >= 0, index < 26,
          let scalar = UnicodeScalar(UInt32(65 + index)) else { return "?" }
    return String(Character(scalar))
}
