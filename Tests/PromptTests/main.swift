import Foundation

// Plain-text checks of how utterances are joined into one question and what the prompt says; no API
// calls. Run: Tests/run-prompt-tests.sh
var failures = 0
func check(_ condition: Bool, _ name: String) {
    print((condition ? "PASS " : "FAIL ") + name)
    if !condition { failures += 1 }
}

/// Utterances as (text, seconds from the previous one's final to its first words).
func joined(_ pieces: [(String, Double)]) -> String {
    var heard: [Prompt.Heard] = []
    var clock = Date(timeIntervalSince1970: 0)
    for (text, gap) in pieces {
        let start = clock.addingTimeInterval(gap)
        clock = start.addingTimeInterval(2)
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
