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

// Soniox now closes a line at a full stop, so a many-part instruction can arrive as two lines.
check(joined([("List three types of fish.", 0),
               ("Commonly used in a commercial kitchen and briefly describe their characteristics.", 0.4)])
      == "List three types of fish. Commonly used in a commercial kitchen and briefly describe their characteristics.",
      "a fragment starting \"Commonly used…\" joins the instruction before it")
check(joined([("Name two sauces.", 0), ("Provide a cooking method for each.", 0.3)])
      == "Name two sauces. Provide a cooking method for each.", "a second instruction joins the first")
check(joined([("Define brunoise.", 0), ("Explain when you would use it.", 0.5)])
      == "Define brunoise. Explain when you would use it.", "\"Define…\" + \"Explain…\" are one task")
check(joined([("Name three cuts of beef.", 0), ("Used for braising.", 0.6)])
      == "Name three cuts of beef. Used for braising.", "a participle fragment joins")
check(joined([("List two mother sauces.", 0), ("Their main ingredients too.", 0.5)])
      == "List two mother sauces. Their main ingredients too.", "a line pointing back with \"Their\" joins")
check(joined([("Name two knives.", 0), ("For each, say what you cut with it.", 0.4)])
      == "Name two knives. For each, say what you cut with it.", "\"For each…\" joins")
check(joined([("I work as a cook.", 0), ("What do you have on the menu today?", 0.3)])
      == "What do you have on the menu today?", "two whole sentences spoken back to back stay apart")
check(joined([("How long do we braise the beef cheeks?", 0), ("Explain the steps for a beurre blanc.", 0.5)])
      == "Explain the steps for a beurre blanc.", "an instruction after a separate question stays apart")
check(joined([("We need more shallots.", 0), ("Need two boxes by noon.", 0.4)]) == "Need two boxes by noon.",
      "\"need\" is not a participle")
check(joined([("Name two sauces.", 0), ("Provide a cooking method for each.", 6.0)])
      == "Provide a cooking method for each.", "an instruction long after the last stays apart")

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
check(Prompt.system.contains("at most 70 words") && Prompt.system.contains("cover every point"),
      "procedure and list answers may take 70 words and cover every point")
check(Prompt.system.contains("at most 25 words"), "normal answers stay at 25 words")
check(Prompt.system.contains("concrete numbers"), "technical answers keep the numbers")

// <today> carries the local date and its weekday (the model gets weekdays of bare dates wrong).
let tuesdayMorningInHanoi = ISO8601DateFormatter().date(from: "2026-11-16T23:30:00Z")! // 06:30 on Tue 17 Nov, UTC+7
let hanoi = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
check(Prompt.today(tuesdayMorningInHanoi, in: hanoi) == "2026-11-17 (Tuesday)", "today is the local date with its weekday")
check(Prompt.user(history: [], utterance: "Hi.", now: tuesdayMorningInHanoi, timeZone: hanoi)
      .hasPrefix("<today>2026-11-17 (Tuesday)</today>"), "the user message starts with <today>")

// Follow-ups that dig into the last answer get it as context and a longer answer; anything else stays short.
for text in ["Can you explain more?", "Tell me more about the poaching liquid.", "Why?", "Why so?", "How?",
             "How do you do that?", "Give me an example.", "For example?", "What about the shellfish?",
             "In more detail, please.", "And why?", "Really?", "What do you mean?", "Could you elaborate on that?",
             "Can you go deeper into the ratios?", "Like what?"] {
    check(Prompt.isFollowUp(text), "follow-up: \(text)")
}
for text in ["Why do you want to work in our kitchen?", "How many years have you worked as a chef?",
             "List three mother sauces.", "Define ganache.", "Clean the station and then label the containers.",
             "What time do you start your shift?", "Okay.", "Name two sauces such as béchamel.",
             "How long do we braise the beef cheeks today?", "We go only on Mondays."] {
    check(!Prompt.isFollowUp(text), "new question: \(text)")
}
let ganache = Prompt.Exchange(question: "Define ganache and give the ratios.",
                              answer: "Ganache is chocolate melted with hot cream. I use 1 to 1 for dark chocolate.")
let asked = Date(timeIntervalSince1970: 1_000)
check(Prompt.previousExchange(for: "Can you explain more?", startedAt: asked.addingTimeInterval(8),
                              answered: [(ganache, asked)])?.question == ganache.question,
      "a follow-up 8 s later digs into the last exchange")
check(Prompt.previousExchange(for: "Tell me more.", startedAt: asked.addingTimeInterval(19),
                              answered: [(ganache, asked)]) != nil, "a follow-up 19 s later still counts")
check(Prompt.previousExchange(for: "Tell me more.", startedAt: asked.addingTimeInterval(45),
                              answered: [(ganache, asked)]) == nil, "45 s later it is a new, short answer")
check(Prompt.previousExchange(for: "How many staff are in your kitchen?", startedAt: asked.addingTimeInterval(5),
                              answered: [(ganache, asked)]) == nil, "an unrelated question stays short")
check(Prompt.previousExchange(for: "Why?", startedAt: asked, answered: []) == nil, "no earlier answer, no context")
let followUp = Prompt.user(history: [], utterance: "Can you explain more?", previous: ganache, now: asked)
check(followUp.contains("<previous_exchange>\n<question>Define ganache and give the ratios.</question>")
      && followUp.contains("<answer>Ganache is chocolate"), "the user message carries the previous exchange")
check(followUp.range(of: "<previous_exchange>")!.lowerBound < followUp.range(of: "<newest_utterance>")!.lowerBound,
      "the previous exchange comes before the newest utterance")
check(!Prompt.user(history: [], utterance: "Define ganache.", now: asked).contains("previous_exchange"),
      "a new question has no previous exchange")
check(Prompt.system.contains("<previous_exchange>") && Prompt.system.contains("3 to 6 short sentences"),
      "the prompt allows a longer answer for a follow-up")

// Fixed answers: the file in Knowledge/, matched word for word or nearly, never on another question.
let fixedText = try! String(contentsOfFile: "Knowledge/\(FixedAnswers.fileName)", encoding: .utf8)
let fixed = FixedAnswers.parse(fixedText)
let cleaning = "Cleaning removes dirt, food and grease with detergent and water. Sanitising kills bacteria, "
    + "usually with a sanitiser or very hot water. We always clean first and sanitise after, because sanitiser "
    + "does not work well on dirty surfaces."
check(fixed.count == 1 && fixed.first?.questions.count == 4, "the file holds one entry with three other wordings")
check(fixed.first?.answer == cleaning, "the answer is read word for word")
check(fixed.first?.vietnamese.hasPrefix("Làm sạch là") == true, "the Vietnamese line is read")
for heard in ["What is the difference between cleaning and sanitising?",
              "What's the difference between cleaning and sanitizing?",
              "Difference between cleaning and sanitising.",
              "Explain cleaning versus sanitising.",
              "Explain cleaning vs sanitizing.",
              "Okay, next question. What is the difference between cleaning and sanitising?",
              "What is the difference between clean and sanitising?",           // one word misheard
              "What is a difference between cleaning and sanitizing?",
              "So what is the difference between cleaning and sanitising in the kitchen?"] {
    check(FixedAnswers.match(heard, in: fixed)?.answer == cleaning, "fixed answer for: \(heard)")
}
for heard in ["How do you sanitise a chopping board?",
              "What is the difference between a cook and a chef?",
              "What is the difference between baking and roasting?",
              "Explain cleaning schedules.",
              "How often do you clean and sanitise the cool room shelves and the floor drains every week?",
              "Why do we clean before we sanitise? Tell me about the chemicals you use and how you store them safely."] {
    check(FixedAnswers.match(heard, in: fixed) == nil, "no fixed answer for: \(heard)")
}
// TESTER's 17 cases (v0.5.6 block): every content word required, no further question.
let testerCases: [(String, Bool)] = [
    ("What is the difference between cleaning and sanitising?", true),
    ("What's the difference between cleaning and sanitizing?", true),
    ("Difference between cleaning and sanitising.", true),
    ("Explain cleaning versus sanitising.", true),
    ("Can you explain the difference between cleaning and sanitising?", true),
    ("What is the difference between cleaning and sanitising in a kitchen?", true),
    ("Okay, next question. What is the difference between cleaning and sanitising?", true),
    ("What is the difference between clean and sanitise?", true),
    ("What is the difference between cleaning and disinfecting?", false),
    ("What is the difference between cleaning and sterilising?", false),
    ("What is the difference between washing and sanitising?", false),
    ("What is the difference between cleaning and sanitising? And why is it important?", false),
    ("What is the difference between cleaning and sanitising and when do you do each?", false),
    ("How do you sanitise a chopping board?", false),
    ("What is the difference between a cook and a chef?", false),
    ("Clean and sanitise the boards after service.", false),
    ("Why is cleaning important before sanitising?", false),
]
for (heard, matches) in testerCases {
    check((FixedAnswers.match(heard, in: fixed) != nil) == matches,
          (matches ? "fixed answer for: " : "no fixed answer for: ") + heard)
}
check(FixedAnswers.words("What’s sanitizing vs cleaning?") == ["what", "is", "sanitising", "versus", "cleaning"],
      "words are normalised")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
