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
}
