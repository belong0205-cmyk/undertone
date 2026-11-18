import Foundation

// Export and import of a profile file through AppState, with an imaginary person whose name and file
// name carry Vietnamese diacritics. Uses a throwaway profiles.json and defaults suite; no API calls.
// Run: Tests/run-profile-file-tests.sh
var failures = 0
func check(_ condition: Bool, _ name: String) {
    print((condition ? "PASS " : "FAIL ") + name)
    if !condition { failures += 1 }
}

MainActor.assumeIsolated {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("undertone-profile-tests-\(UUID())")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var suites: [String] = []
    @MainActor func freshState(_ label: String) -> AppState {
        let suite = "undertone-profile-tests-\(UUID())"
        suites.append(suite)
        return AppState(defaults: UserDefaults(suiteName: suite)!,
                        profilesURL: dir.appendingPathComponent("\(label)/profiles.json"))
    }

    // An imaginary cook; every value is made up.
    var person = UserProfile()
    person.name = "Nguyễn Thị Ánh Tuyết"
    person.dateOfBirth = "02/09/1990"
    person.work = "Bếp phó, Nhà hàng Hương Quê"
    person.kitchenTeam = "1 bếp trưởng\n2 bếp phó\n4 commis"
    person.specialties = "Phở bò, bánh xèo, crème brûlée"

    let mac1 = freshState("mac1")
    mac1.profiles = [person]
    mac1.activeProfileID = person.id
    let nfc = dir.appendingPathComponent("Nguyễn Thị Ánh Tuyết.undertone-profile".precomposedStringWithCanonicalMapping)
    do { try mac1.exportProfile(person.id, to: nfc) } catch { check(false, "export: \(error.localizedDescription)") }
    check(FileManager.default.fileExists(atPath: nfc.path), "export writes the file")

    // Another Mac: the profile arrives as it was.
    let mac2 = freshState("mac2")
    do {
        let id = try mac2.importProfile(fromFile: nfc)
        let imported = mac2.profiles.first { $0.id == id }
        check(imported?.name == person.name, "import keeps the Vietnamese name")
        check(imported?.kitchenTeam == person.kitchenTeam && imported?.specialties == person.specialties,
              "import keeps every field")
        check(mac2.activeProfileID == id, "the imported profile becomes active")
    } catch { check(false, "import on another Mac: \(error.localizedDescription)") }

    // The same Mac: a copy next to the original.
    do {
        let id = try mac1.importProfile(fromFile: nfc)
        check(mac1.profiles.count == 2, "import on the same Mac adds a profile")
        check(mac1.profiles.first { $0.id == id }?.name == person.name + " (nhập)", "the copy is named \"(nhập)\"")
    } catch { check(false, "import on the same Mac: \(error.localizedDescription)") }

    // A file whose name is in decomposed form (as some tools and disks write it).
    let nfd = dir.appendingPathComponent("Nguyễn Thị Ánh Tuyết (NFD).undertone-profile".decomposedStringWithCanonicalMapping)
    try? FileManager.default.copyItem(at: nfc, to: nfd)
    do {
        let id = try freshState("mac3").importProfile(fromFile: nfd)
        check(id != person.id, "a decomposed file name imports")
    } catch { check(false, "decomposed file name: \(error.localizedDescription)") }

    // The import is saved, so it survives a restart.
    check(ProfileStore.load(from: dir.appendingPathComponent("mac2/profiles.json"))?.first?.name == person.name,
          "the import is saved to profiles.json")

    // Both import buttons take an exported profile; a CV still goes to the AI.
    check(ProfileFile.isProfileFile(nfc), "an exported .undertone-profile is a profile file")
    check(ProfileFile.isProfileFile(URL(fileURLWithPath: "/tmp/Hồ sơ Tuyết.JSON")), "a .json profile is a profile file")
    check(!ProfileFile.isProfileFile(URL(fileURLWithPath: "/tmp/CV Nguyễn Thị Ánh Tuyết.docx")), "a Word CV is not")

    try? FileManager.default.removeItem(at: dir)
    for suite in suites { UserDefaults.standard.removePersistentDomain(forName: suite) }
}

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
