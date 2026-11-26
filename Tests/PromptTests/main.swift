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
check(Prompt.system.range(of: #"at most \d+ words|\d+ to \d+ short sentences|up to \d+ short sentences"#,
                          options: .regularExpression) == nil, "answers have no word or sentence-count cap")
check(Prompt.system.contains("as short as possible but complete and accurate")
      && Prompt.system.contains("Start with the direct answer in the first sentence")
      && Prompt.system.contains("one short sentence for each point the question asks for")
      && Prompt.system.contains("every item of \"List 5…\""),
      "answers lead with the direct answer and cover every point asked")
check(Prompt.system.contains("no introduction, no repetition, no closing line, no restating the question"),
      "answers add nothing extra")
// Against Haiku's invented details and placeholders (TESTER live run, fac2b98).
check(Prompt.system.contains("When asked for an example, give one concrete example with its numbers"),
      "an example carries concrete numbers")
// Hard rules sit right before the newest utterance (TESTER live run on cc1c1fe: Haiku ignored them in the system prompt).
// Merged on e8d012f to cut ~35% of the rules tokens with the same behaviour; each check names the case it guards.
for (phrase, what) in [
    ("never your reasoning", "no thinking aloud (#6 on Haiku)"),
    ("Use only facts from the knowledge base or profile.", "facts only from KB or profile"),
    ("Never invent a number or size (e.g. \"5 cm deep\"), a dish, or restaurant details (menu, team, schedule, "
         + "working days or hours).", "no invented numbers, dishes or restaurant details (#6 \"crispy fish\")"),
    ("Never mention \"the profile\" or say that the menu or profile lacks a dish.", "no 'the profile', no 'menu lacks' (#23, #129)"),
    ("Name a weekday or date only if the question names one, even though <today> or the menu shows days.",
         "no unasked weekday (#3, #12)"),
    ("The profile menu is suggested dishes, not a plan by day.", "menu is suggestions (user decision)"),
    ("A dish is European only under a heading that says European (\"món Âu\"); dishes under \"món Việt\" are "
         + "Vietnamese.", "European by menu heading (#6)"),
    ("In answer_en, give dish names in English (\"Bò hầm rượu vang\" -> \"Beef stew in red wine\"); answer_vi keeps "
         + "the Vietnamese names.", "English dish names (#3)"),
    ("General food or recipe (\"How do you make a French omelette?\"): classic European dishes from the knowledge "
         + "base, not the profile menu.", "branch 1: general food"),
    ("What you cook or make, no restaurant named (\"What soup do you make?\"): only European dishes from the profile "
         + "menu, no days or menu details. If it has none of that kind, classic European dishes, as your own.", "branch 2: what you cook (#2, #12, #129)"),
    ("Restaurant, its menu or your workplace named (\"What do you serve at your restaurant?\"): the whole menu.",
         "branch 3: whole menu (European first via the next rule, #4)"),
    ("\n- When the profile has more than one menu, cover each one in full, with its vegetarian option, "
         + "European first even if the profile lists it second. Example for \"What does one meal come with?\":\n"
         + "  European set menu:\n  - Soup, main, side, salad, bread, dessert\n  - Vegetarian option\n\n"
         + "  Vietnamese set meal:\n  - Rice, dipping sauce, iced tea\n  - Main, side, stir-fry, soup, vegetables, "
         + "dessert\n  - Vegetarian option\n",
         "every menu, European first, as its own rule (#4 on 6501aed and 4189eda; passed on 9f85d9a as its own rule)"),
    ("A day named (\"What do you cook on Friday?\"): suggest menu dishes; they need not match that day.",
         "day question gets suggestions"),
    ("If the profile has nothing on your certificates, qualifications, experience or signature dishes, say in one "
         + "short sentence that you have none yet. Use [brackets] only for a missing name, age, address or workplace.",
         "none yet, no brackets (#23)"),
    ("A procedure keeps every step, including checks and records.", "procedures keep the record step (#60)"),
    ("cover every item and part asked", "every item and part covered"),
] {
    check(Prompt.rules.contains(phrase), "rule: \(what)")
}
// The rules' own example lines stay under 14 words (#2/#4: an example "in one short line" gave 18-word lines).
for line in Prompt.rules.split(separator: "\n") where line.hasPrefix("  - ") {
    check(line.split(separator: " ").count < 14, "example line under 14 words: \(line)")
}
// Ceiling = the 25% cut target from 3,741 chars before the merge (6501aed).
check(Prompt.rules.count < 2800, "the rules block stays short (\(Prompt.rules.count) chars)")
// Answers are laid out to skim (user request): one idea per line, "- " list lines, labelled parts with a blank
// line between, nothing else; the layout rule comes first, then the minimal rule, then the one-kind list rule.
check(Prompt.rules.hasPrefix("<rules>\n- Layout: one idea per line, every line under 14 words; break a long line into \"- \" "
                             + "lines. A one-idea "
                             + "answer is one or two lines. A list puts each item on its own \"- \" line. Several parts: "
                             + "a short label line ending in \":\", its lines, a blank line between parts. No ** or #. "
                             + "answer_vi keeps the same lines. Example:\n"),
      "the layout rule comes first")
check(Prompt.rules.contains("  Two cold sauces:\n  - Mayonnaise\n  - Vinaigrette\n\n  Storage:\n"),
      "the layout example has a label, list lines and a blank line between parts")
// User: Sonnet's answers were too long. Minimal answers, short phrase lines, 3–4 lines per part, no word cap.
check(Prompt.rules.contains("\n- Be minimal: no restating the question, no opening or closing line, never your "
                            + "reasoning, nothing not asked. Short phrases are fine. Each part has at most 3 or 4 lines "
                            + "unless more items are asked, but cover every item and part asked."),
      "the minimal-answer rule")
// #50: a one-kind list opened with "The five mother sauces are:", so the rule shows the wrong first line.
check(Prompt.rules.contains("\n- A list of one kind starts with its first item, names only unless more is asked. "
                            + "Example: \"List the five mother sauces.\" starts with \"- Béchamel\", never with \"The "
                            + "five mother sauces are:\".\n"),
      "a one-kind list starts with its first item and gives names only")
let layoutAt = Prompt.rules.range(of: "- Layout:")!.lowerBound
let minimalAt = Prompt.rules.range(of: "- Be minimal:")!.lowerBound
let listAt = Prompt.rules.range(of: "- A list of one kind")!.lowerBound
check(layoutAt < minimalAt && minimalAt < listAt, "layout, then minimal, then the one-kind list rule")
check(!Prompt.system.contains("No bullet points") && Prompt.system.contains("Lay it out as the <rules> block says")
      && Prompt.system.contains("with the same lines and layout.</answer_vi>"),
      "the system prompt allows list lines and keeps the Vietnamese layout the same")
let ruled = Prompt.user(history: [], utterance: "What is on the menu?", now: Date(timeIntervalSince1970: 0))
check(ruled.hasSuffix(Prompt.rules + "\n\n<newest_utterance>\nWhat is on the menu?\n</newest_utterance>"),
      "the rules come right before the newest utterance")
check(Prompt.system.contains("Always follow the <rules> block just before the newest utterance"),
      "the system prompt points to the rules")
check(!Prompt.system.contains("State only facts") && !Prompt.system.contains("5 cm deep"),
      "the moved rules are not repeated in the system prompt")
check(Prompt.system.contains("hobbies, likes, goals, feelings, daily life")
      && Prompt.system.contains("with no brackets and no template text")
      && Prompt.system.contains("Never add a placeholder to an answer that has other content"),
      "soft personal details get a plain answer, never a placeholder")
check(Prompt.system.contains("for a fixed personal fact (a name, age or birthday, address or workplace), answer with a "
                             + "placeholder in square brackets for that fact only"),
      "a placeholder only for a missing name, age, address or workplace")
check(Prompt.system.contains("Never add a placeholder to an answer that has other content"),
      "a placeholder is never mixed into other content")
// User request: general food questions get classic European dishes; the profile menu only for questions about
// the restaurant or work. Both branches reach the model with the same rules (offline: prompt text only).
check(Prompt.system.contains("their recipes, or the dishes and menu at their workplace")
      && !Prompt.system.contains("their dishes, recipes or menu"),
      "the profile answers about dishes only for the workplace menu")
check(!Prompt.rules.contains("In menu and dish answers"), "European-first applies to the menu branch only")
// User decision: three branches. "What you cook" gets the profile's European dishes only, not the whole menu.
check(!Prompt.rules.contains("what you cook there") && !Prompt.rules.contains("are general."),
      "cooking questions are neither the general nor the whole-menu branch")
for question in ["How do you make a classic French omelette?", "What do you serve at your restaurant?"] {
    check(Prompt.user(history: [], utterance: question, now: Date(timeIntervalSince1970: 0))
              .hasSuffix(Prompt.rules + "\n\n<newest_utterance>\n\(question)\n</newest_utterance>"),
          "the general-or-menu rules come before: \(question)")
}
// A missing certificate is not a bracket placeholder (#23, live: "I have [your certificate].").
check(Prompt.system.contains("For a record of the user's own (certificates, qualifications, experience, signature "
                             + "dishes), say in one short first-person sentence that you have none yet")
      && Prompt.system.contains("(e.g. \"I do not have any certificates yet.\"), with no brackets"),
      "a missing certificate or other record gets a plain 'none yet' answer")
check(Prompt.system.contains("with no specific places or dates"), "soft personal answers invent no places or dates")
check(Prompt.system.contains("every answer, short or long, including follow-ups")
      && Prompt.system.contains("one idea each") && Prompt.system.contains("same strict B1 rules"),
      "strict B1 applies to every tier, follow-ups included")
check(Prompt.system.contains("concrete numbers"), "technical answers keep the numbers")

// <today> carries the local date and its weekday (the model gets weekdays of bare dates wrong).
let tuesdayMorningInHanoi = ISO8601DateFormatter().date(from: "2026-11-16T23:30:00Z")! // 06:30 on Tue 17 Nov, UTC+7
let hanoi = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
check(Prompt.today(tuesdayMorningInHanoi, in: hanoi) == "2026-11-17 (Tuesday)", "today is the local date with its weekday")
check(Prompt.user(history: [], utterance: "Hi.", now: tuesdayMorningInHanoi, timeZone: hanoi)
      .hasPrefix("<today>2026-11-17</today>"), "the user message starts with <today>")
// The weekday goes in only for a day question (Haiku named it unasked, TESTER #12).
for text in ["What is on the menu today?", "What do you cook tomorrow?", "Who works tonight?",
             "What do you serve on Fridays?", "Is Sunday a working day?"] {
    check(Prompt.user(history: [], utterance: text, now: tuesdayMorningInHanoi, timeZone: hanoi)
          .hasPrefix("<today>2026-11-17 (Tuesday)</today>"), "weekday sent for: \(text)")
}
for text in ["What kind of food do you cook?", "How old are you?", "What do you do every day?"] {
    check(Prompt.user(history: [], utterance: text, now: tuesdayMorningInHanoi, timeZone: hanoi)
          .hasPrefix("<today>2026-11-17</today>"), "no weekday for: \(text)")
}

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
check(Prompt.system.contains("<previous_exchange>") && Prompt.system.contains("add only the new information"),
      "a follow-up answers in more detail with only the new information")

// Fixed answers: the file in Knowledge/, matched word for word or nearly, never on another question.
let fixedText = try! String(contentsOfFile: "Knowledge/\(FixedAnswers.fileName)", encoding: .utf8)
let fixed = FixedAnswers.parse(fixedText)
let cleaning = "Cleaning removes dirt, food and grease with detergent and water. Sanitising kills bacteria, "
    + "usually with a sanitiser or very hot water. We always clean first and sanitise after, because sanitiser "
    + "does not work well on dirty surfaces."
check(!fixed.isEmpty && fixed.allSatisfy { !$0.questions[0].isEmpty && !$0.answer.isEmpty && !$0.vietnamese.isEmpty },
      "every entry in the file has a question, an answer and a Vietnamese line")
let cleaningEntry = fixed.first { $0.questions[0] == "What is the difference between cleaning and sanitising?" }
check(cleaningEntry?.questions.count == 4, "the cleaning entry has three other wordings")
check(cleaningEntry?.answer == cleaning, "the answer is read word for word")
check(cleaningEntry?.vietnamese.hasPrefix("Làm sạch là") == true, "the Vietnamese line is read")
// A fixed answer written over several lines keeps its lines and blank lines for display, word for word.
let multiLine = FixedAnswers.parse("## Q: Name two cold sauces.\nA: Two cold sauces:\n- Mayonnaise\n- Vinaigrette\n\n"
                                   + "Storage:\n- Keep them cold\n\nVI: Hai loại sốt lạnh:\n- Mayonnaise\n\n## Q: Next?\nA: Yes.")
check(multiLine.first?.answer == "Two cold sauces:\n- Mayonnaise\n- Vinaigrette\n\nStorage:\n- Keep them cold"
      && multiLine.first?.vietnamese == "Hai loại sốt lạnh:\n- Mayonnaise"
      && multiLine.first?.questions == ["Name two cold sauces."] && multiLine.count == 2,
      "a fixed answer keeps its line breaks; its list lines are not read as other wordings")
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
// Other entries, and questions that only share their words (TESTER, f0be2e0).
let dangerZone = fixed.first { $0.questions[0] == "What is the temperature danger zone?" }
let twoFour = fixed.first { $0.questions[0] == "What is the 2-hour 4-hour rule?" }
check(dangerZone != nil && twoFour != nil, "the danger zone and 2-hour 4-hour entries are read")
for (heard, expected) in [("What is the temperature danger zone?", dangerZone),
                          ("Okay. Define the temperature danger zone.", dangerZone),
                          ("Explain the 2-hour 4-hour rule.", twoFour),
                          ("What is the two hour four hour rule?", twoFour),
                          ("What is the cooling rule, 2 hours then 4 hours?", nil),
                          ("What is the difference between the temperature danger zone and the 2-hour 4-hour rule?", nil),
                          ("Compare the 2-hour 4-hour rule with the cooling rule.", nil),
                          ("What is the difference between cleaning and sanitising?", cleaningEntry),
                          ("What is the difference between cleaning, sanitising and disinfecting?", nil),
                          ("What is the difference between cleaning and sanitising and the sterilising?", nil),
                          ("Explain cleaning versus sanitising versus disinfecting.", nil),
                          ("What is the difference between cleaning and sanitising or disinfecting?", nil)] {
    check(FixedAnswers.match(heard, in: fixed) == expected,
          (expected == nil ? "no fixed answer for: " : "fixed answer for: ") + heard)
}
check(FixedAnswers.words("What’s sanitizing vs cleaning?") == ["what", "is", "sanitising", "versus", "cleaning"],
      "words are normalised")

// The answer request (offline: the body and headers are only built, never sent).
let body = ClaudeClient.requestBody(system: "s", profile: nil, user: "u", maxTokens: 2048, stream: true)
check(body["model"] as? String == "claude-sonnet-5-5", "answers use Sonnet 5.5")
check(body["thinking"] == nil, "no thinking field (TESTER: faster than between_tools, no thinking blocks)")
let warmUp = ClaudeClient.requestBody(system: "s", profile: nil, user: "Warm-up.", maxTokens: 0, stream: false)
check(warmUp["thinking"] == nil && warmUp["model"] as? String == "claude-sonnet-5-5",
      "the cache warm-up sends no thinking field either, with the same model")
check((body["output_config"] as? [String: Any])?["effort"] as? String == "low" && body["max_tokens"] as? Int == 2048,
      "effort low, max_tokens 2048")
check(body["fallbacks"] as? String == "default"
      && (try? ClaudeClient(apiKey: "k").makeRequest(body: body))?.value(forHTTPHeaderField: "anthropic-beta")
         == "server-side-fallback-2026-07-01", "a refusal falls back server-side, with its beta header")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
