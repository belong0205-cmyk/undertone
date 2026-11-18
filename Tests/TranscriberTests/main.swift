import Foundation

// Utterance splitting in SonioxTranscriber, fed scripted Soniox responses (no network, no API calls).
// Run: Tests/run-transcriber-tests.sh
var failures = 0
func check(_ condition: Bool, _ name: String) {
    print((condition ? "PASS " : "FAIL ") + name)
    if !condition { failures += 1 }
}

/// One Soniox response with final spoken tokens: (text, start ms, end ms).
func response(_ words: [(String, Int, Int)], final: Bool = true) -> String {
    let tokens = words.map { word -> [String: Any] in
        ["text": word.0, "is_final": final, "start_ms": word.1, "end_ms": word.2, "translation_status": "original"]
    }
    let data = try! JSONSerialization.data(withJSONObject: ["tokens": tokens])
    return String(decoding: data, as: UTF8.self)
}

/// Words spoken one after another from `start`, 200 ms each, no gaps.
func words(_ text: String, from start: Int) -> [(String, Int, Int)] {
    text.split(separator: " ").enumerated().map { index, word in
        ((index == 0 && start == 0 ? "" : " ") + word, start + index * 200, start + index * 200 + 180)
    }
}

/// Utterance texts in order, the last one possibly still open.
@MainActor func utterances(_ script: (SonioxTranscriber) -> Void) -> [String] {
    let transcriber = SonioxTranscriber()
    var order: [UUID] = []
    var texts: [UUID: String] = [:]
    transcriber.onUtterance = { id, text, _ in
        if texts[id] == nil { order.append(id) }
        texts[id] = text
    }
    script(transcriber)
    return order.compactMap { texts[$0] }
}

MainActor.assumeIsolated {
    // A sentence of 8+ words ending on a dangling word ("of."), then the next word after a reconnect.
    // The new stream's clock restarts at 0, so a gap measured against the old stream's last word is
    // meaningless and must not end the utterance.
    let sentence = "List three types of fish and three types of."
    let acrossReconnect = utterances { t in
        t.debugReceive(response(words(sentence, from: 0)))
        t.debugStreamOpened()
        t.debugReceive(response([(" shellfish", 1_200, 1_600), (" commonly", 1_700, 2_000)]))
    }
    check(acrossReconnect.count == 1, "no split at the first word after a reconnect: \(acrossReconnect)")

    // The same gap inside one stream, with no quiet audio recorded (music underneath): splits.
    let sameStream = utterances { t in
        t.debugReceive(response(words(sentence, from: 0)))
        t.debugReceive(response([(" Shellfish", 2_600, 3_000), (" next", 3_100, 3_300)]))
    }
    check(sameStream.count == 2, "a pause after a long sentence under music still splits: \(sameStream)")

    // Two sentences spoken back to back split; a continuation word does not.
    let backToBack = utterances { t in
        t.debugReceive(response(words("I work as a cook.", from: 0) + words("What do you have today?", from: 1_000)))
    }
    check(backToBack == ["I work as a cook.", "What do you have today?"], "back-to-back sentences split: \(backToBack)")
    let continued = utterances { t in
        t.debugReceive(response(words("Commonly used in a commercial kitchen.", from: 0) + words("And briefly describe them.", from: 1_200)))
    }
    check(continued.count == 1, "a sentence carried on with \"And\" stays one: \(continued)")
}

print(failures == 0 ? "ALL PASS" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
