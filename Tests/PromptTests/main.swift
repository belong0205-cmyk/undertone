import Foundation

// Plain-text checks of how utterances are joined into one question and what the prompt says; no API
// calls. Run: Tests/run-prompt-tests.sh
var failures = 0
func check(_ condition: Bool, _ name: String) {
    print((condition ? "PASS " : "FAIL ") + name)
    if !condition { failures += 1 }
}

/// Utterances as (text, seconds from the previous one's final to its first words), each on screen for
/// `duration` seconds from first words to final.
func joined(_ pieces: [(String, Double)], duration: Double = 2) -> String {
    var heard: [Prompt.Heard] = []
    var clock = Date(timeIntervalSince1970: 0)
    for (text, gap) in pieces {
        let start = clock.addingTimeInterval(gap)
        clock = start.addingTimeInterval(duration)
        heard.append(Prompt.Heard(text: text, start: start, end: clock))
    }
    return heard[Prompt.questionStart(heard)...].map(\.text).joined(separator: " ")
}

// The user's report: an exam-style instruction, cut by Soniox at a pause.
check(joined([("Define ganache.", 0), ("And provide common ratios for dark vs milk/white chocolate.", 1.5)])
      == "Define ganache. And provide common ratios for dark vs milk/white chocolate.",
      "\"and provide…\" joins \"Define ganache.\"")
check(joined([("Define ganache and provide common ratios for dark", 0), ("vs milk/white chocolate.", 1.2)])
      == "Define ganache and provide common ratios for dark vs milk/white chocolate.",
      "a long instruction cut mid-sentence is joined")
check(joined([("Define ganache and provide", 0), ("common ratios for dark", 1.0), ("vs milk/white chocolate.", 1.0)])
      == "Define ganache and provide common ratios for dark vs milk/white chocolate.",
      "three pieces of one instruction are joined")
check(joined([("Define ganache.", 0)]) == "Define ganache.", "a whole instruction is answered at once")
check(!Prompt.isFiller("Define ganache."), "an instruction is not a filler")
check(!Prompt.isFiller("Name three mother sauces."), "\"Name…\" is not a filler")

// A long exam question that Soniox cut into ten pieces (each about 1 s, short pauses between them).
let fishQuestion = "List three types of fish that are good for poaching, and for each one describe the texture, "
    + "the flavor, and the main characteristics."
let fishPieces: [(String, Double)] = [
    ("Okay, next question.", 0),
    ("List three types of", 3.0),
    ("fish that are good", 0.6),       // after "of": a sentence cannot end there
    ("for poaching,", 0.4),
    ("and for each one", 0.8),
    ("describe the", 0.5),
    ("texture,", 1.2),
    ("the flavor,", 0.3),
    ("and the", 0.4),
    ("main", 5.0),                     // a long hesitation, but "the" cannot end a sentence
    ("characteristics.", 0.5),
]
check(joined(fishPieces, duration: 1) == fishQuestion, "a question cut into ten pieces is joined whole")
check(joined(Array(fishPieces.prefix(4)), duration: 1) == "List three types of fish that are good for poaching,",
      "its first pieces are joined while it is still being spoken")
check(joined([("Tell me about the", 0), ("sauce?", 6.0)]) == "Tell me about the sauce?",
      "a piece ending on \"the\" joins the next one even after a long pause")
check(joined([("What pan do you cook it in?", 0), ("Explain the steps for a beurre blanc.", 6.0)])
      == "Explain the steps for a beurre blanc.", "a question ending on \"in?\" is finished")
let slow = (0..<12).map { ("word \($0) and", $0 == 0 ? 0.0 : 1.0) } + [("done.", 1.0)]
check(joined(slow).hasPrefix("word 6 and"), "pieces beyond the 20 s span are left out")

// Pieces seen with real Soniox (v0.5.0 probe).
check(joined([("So, tell me, what kind of dishes—", 0), ("Do you usually cook?", 0.9), ("At your restaurant?", 2.3)])
      == "So, tell me, what kind of dishes— Do you usually cook? At your restaurant?",
      "a question cut by hesitations is joined")
check(joined([("Okay, let's start the interview.", 0), ("So, tell me about yourself.", 2.5)])
      == "So, tell me about yourself.", "a finished statement before a question stays apart")
check(joined([("How long do we braise the beef cheeks?", 0), ("Explain the steps for a beurre blanc.", 5.6)])
      == "Explain the steps for a beurre blanc.", "a separate question after a long gap stays apart")
check(joined([("Define ganache", 0), ("and provide ratios.", 5.0)]) == "and provide ratios.",
      "pieces further apart than the gap are not joined")
check(joined([("Okay.", 0), ("And list the mother sauces.", 1.0)]) == "And list the mother sauces.",
      "a filler is never a piece")

// The prompt treats instructions as questions and lets technical answers carry numbers.
for verb in ["Define", "Explain", "Describe", "List", "Provide", "Name", "Tell me", "Give me", "What are the steps"] {
    check(Prompt.system.contains("\"\(verb)"), "prompt names \"\(verb)…\" as a question")
}
check(Prompt.system.contains("at most 45 words"), "technical answers may be longer")
check(Prompt.system.contains("concrete numbers"), "technical answers keep the numbers")

// <today> carries the local date and its weekday (the model gets weekdays of bare dates wrong).
let tuesdayMorningInHanoi = ISO8601DateFormatter().date(from: "2026-11-16T23:30:00Z")! // 06:30 on Tue 17 Nov, UTC+7
let hanoi = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
check(Prompt.today(tuesdayMorningInHanoi, in: hanoi) == "2026-11-17 (Tuesday)", "today is the local date with its weekday")
check(Prompt.user(history: [], utterance: "Hi.", now: tuesdayMorningInHanoi, timeZone: hanoi)
      .hasPrefix("<today>2026-11-17 (Tuesday)</today>"), "the user message starts with <today>")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
