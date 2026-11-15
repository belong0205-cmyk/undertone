import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The "Hồ sơ" page, shown inside the panel (sheets, popovers and alerts are separate windows that
/// would appear in screen sharing): profiles on the left, the active profile's fields on the right.
/// The only separate window is the file picker of "Nhập từ Word", opened on demand.
struct ProfilePage: View {
    @EnvironmentObject private var state: AppState
    let onBack: () -> Void
    // Kept here, not in the editor, so switching profiles mid-import keeps the spinner and result.
    @State private var importing = false
    @State private var importResult: ImportResult?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let importResult {
                ImportResultBar(result: importResult) { self.importResult = nil }
            }
            HStack(spacing: 0) {
                ProfileList()
                    .frame(width: 156)
                    .background(Color.black.opacity(0.14))
                Rectangle().fill(Theme.hairline).frame(width: 1)
                if let id = state.activeProfile?.id {
                    // A fresh editor per profile, so a pending delete confirmation never carries over.
                    ProfileEditor(profileID: id).id(id)
                } else {
                    EmptyProfiles()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.tint)
        .onExitCommand(perform: onBack)
    }

    private var header: some View {
        ZStack {
            Text("Hồ sơ")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 10.5, weight: .semibold))
                        Text("Cài đặt").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                importControl
            }
            .padding(.horizontal, Theme.pad)
        }
        .frame(height: 36)
        .background(WindowDragArea())
        .overlay(alignment: .bottom) { Hairline() }
    }

    @ViewBuilder private var importControl: some View {
        if importing {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Đang nhập…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            Button(action: chooseFile) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text").font(.system(size: 10.5, weight: .semibold))
                    Text("Nhập từ Word").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Theme.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Điền hồ sơ từ CV: .docx, .doc, .rtf hoặc .txt")
        }
    }

    /// Picks a CV and lets Claude fill the active profile (a new one when there is none).
    private func chooseFile() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = ["docx", "doc", "rtf", "txt"].compactMap { UTType(filenameExtension: $0) }
        picker.allowsMultipleSelection = false
        picker.canChooseDirectories = false
        picker.message = "Chọn CV hoặc hồ sơ: Word (.docx, .doc), .rtf hoặc .txt"
        picker.prompt = "Nhập"
        picker.level = .modalPanel // above the floating overlay
        picker.sharingType = .none // like the overlay, kept out of screen sharing where macOS allows it
        NSApp.activate() // the overlay never activates the app, so the picker would open behind other apps
        guard picker.runModal() == .OK, let url = picker.url else { return }

        importResult = nil
        importing = true
        Task {
            do {
                let count = try await state.importProfile(from: url)
                importResult = count > 0 ? .filled(count) : .failed("Không tìm thấy thông tin hồ sơ nào trong file này.")
            } catch {
                importResult = .failed(error.localizedDescription)
            }
            importing = false
        }
    }
}

private struct ProfileList: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(state.profiles) { profile in
                        row(profile)
                    }
                }
                .padding(8)
            }
            Hairline()
            Button { state.addProfile() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 10.5, weight: .semibold))
                    Text("Thêm").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ profile: UserProfile) -> some View {
        let isActive = profile.id == state.activeProfileID
        return Button { state.activeProfileID = profile.id } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isActive ? Theme.accent : Theme.dot)
                    .frame(width: 6, height: 6)
                Text(profile.displayName)
                    .font(.system(size: 12.5, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Theme.accent.opacity(0.14) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileEditor: View {
    @EnvironmentObject private var state: AppState
    let profileID: UUID
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(ProfileCopy.hint)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(UserProfile.fields) { profileField in
                    if profileField.multiline {
                        BoxField(label: profileField.label, text: field(profileField.keyPath))
                    } else {
                        LineField(label: profileField.label, text: field(profileField.keyPath))
                    }
                }
                Hairline().padding(.top, 2)
                deleteRow
            }
            .padding(Theme.pad)
        }
    }

    /// Two steps, in place: no alert window.
    @ViewBuilder private var deleteRow: some View {
        if confirmingDelete {
            HStack(spacing: 14) {
                Text("Xoá hẳn hồ sơ “\(state.activeProfile?.displayName ?? "")”?")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                TextAction(title: "Huỷ", color: Theme.textSecondary) { confirmingDelete = false }
                TextAction(title: "Xoá", color: Theme.danger) { state.deleteProfile(profileID) }
            }
        } else {
            TextAction(title: "Xoá hồ sơ này", color: Theme.danger) { confirmingDelete = true }
        }
    }

    /// Looks the profile up by id on every read and write, so a deleted profile is never written to.
    private func field(_ keyPath: WritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(
            get: { state.profiles.first { $0.id == profileID }?[keyPath: keyPath] ?? "" },
            set: { value in
                guard let index = state.profiles.firstIndex(where: { $0.id == profileID }) else { return }
                state.profiles[index][keyPath: keyPath] = value
            }
        )
    }
}

private struct EmptyProfiles: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Chưa có hồ sơ")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text(ProfileCopy.hint)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .fixedSize(horizontal: false, vertical: true)
            Button { state.addProfile() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 10.5, weight: .semibold))
                    Text("Thêm hồ sơ").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.accent.opacity(0.5)))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(Theme.pad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum ProfileCopy {
    static let hint = "AI dùng hồ sơ này để trả lời các câu hỏi về bạn; để trống thì trả lời bình thường."
}

private struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
    }
}

/// Single-line field with its label above.
private struct LineField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            FieldLabel(text: label)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .fieldChrome()
        }
    }
}

/// Multi-line field with its label above; Return makes a new line.
private struct BoxField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            FieldLabel(text: label)
            TextEditor(text: $text)
                .font(.system(size: 12.5))
                .scrollContentBackground(.hidden)
                .frame(height: 60)
                .fieldChrome(horizontal: 4)
        }
    }
}

private enum ImportResult {
    case filled(Int)
    case failed(String)
}

/// Outcome of the last Word import, under the header until dismissed or the next import.
private struct ImportResultBar: View {
    let result: ImportResult
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(isError ? Theme.warning : Theme.accent)
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.pad)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.14))
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var isError: Bool {
        if case .failed = result { return true }
        return false
    }

    private var message: String {
        switch result {
        case .filled(let count): "Đã điền \(count) trường"
        case .failed(let message): message
        }
    }
}
