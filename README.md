# Undertone

Cửa sổ nổi trên macOS: nghe âm thanh hệ thống (tiếng Anh + tiếng Pháp, bối cảnh bếp chuyên nghiệp),
hiện phụ đề gốc, bản dịch tiếng Việt, và tự gợi ý câu trả lời ngắn (Anh + Việt) khi có câu hỏi dành cho bạn.
Cửa sổ được loại khỏi ảnh chụp màn hình và luồng chia sẻ màn hình.

## Cài trên máy Mac khác (bản build sẵn)

Cần macOS 14.4+, chạy được cả Mac chip Apple lẫn Mac Intel. Mở Terminal:

```bash
gh release download --repo belong0205-cmyk/undertone --pattern 'Undertone.zip' --clobber
ditto -x -k Undertone.zip /Applications && rm Undertone.zip
open /Applications/Undertone.app
```

Tải bằng Terminal thì macOS không chặn app. Nếu tải `Undertone.zip` bằng trình duyệt, macOS sẽ báo
không mở được vì app chưa được Apple xác minh. Khi đó chạy thêm lệnh này rồi mở lại:

```bash
xattr -dr com.apple.quarantine /Applications/Undertone.app
```

Key API lưu riêng trên từng máy: vào ⚙ dán lại **Claude key** và **Soniox key**.

## Build & chạy

Cần macOS 14.4+ và Xcode (hoặc Command Line Tools).

```bash
./build.sh                          # nhanh, cho đúng loại chip của máy này
ARCHS="arm64 x86_64" ./build.sh     # bản universal để chạy trên mọi Mac
open build/Undertone.app
```

Lần đầu bấm nghe, macOS hỏi quyền **Ghi âm thanh hệ thống** (nghe tiếng từ Zoom, Meet, YouTube…): bấm **Cho phép**.
Nhận dạng giọng nói dùng Soniox (cần Soniox key trong ⚙).

Mỗi lần build lại, chữ ký app thay đổi nên macOS có thể hỏi quyền lại.

## Dùng

| Thao tác | Cách làm |
|---|---|
| Tạm dừng / nghe tiếp | Bấm chấm tròn ở góc trên (xanh = đang nghe) |
| API key, bối cảnh cho AI, độ hiện, xoá hội thoại, thoát | Bấm ⚙ |
| Di chuyển cửa sổ | Kéo thanh tiêu đề |
| Đổi kích thước | Kéo mép cửa sổ |

App không có icon trên Dock và không xuất hiện trong ⌘-Tab. Thoát bằng ⚙ › Thoát.

"Bối cảnh cho AI" giúp câu trả lời sát với bạn, ví dụ:
*Tôi phỏng vấn vị trí Backend Developer, 3 năm kinh nghiệm Go, từng làm hệ thống thanh toán.*

## Kiểm tra chống chụp trước buổi họp

1. Mở Undertone.
2. Chụp màn hình bằng ⌘⇧3 → mở ảnh: không được thấy cửa sổ Undertone.
3. Trong Zoom/Meet, chia sẻ **toàn bộ màn hình**, nhờ người khác (hoặc máy thứ hai) xem:
   không được thấy cửa sổ Undertone.

Cơ chế: `NSWindow.sharingType = .none` — API chính thức duy nhất của macOS cho việc này.
Ứng dụng chụp/chia sẻ dùng ScreenCaptureKit trên các bản macOS mới có thể không tôn trọng cờ này,
nên hãy luôn thử bước 3 với đúng ứng dụng họp bạn dùng.

## AI

- Model mỗi câu: `claude-haiku-5-5`, effort `low` cho nhanh; mỗi câu nghe được = 1 request (dịch + gợi ý nếu là câu hỏi).
- Haiku 5.5 không có server-side fallback: nếu bộ lọc an toàn từ chối, câu đó hiện lỗi "AI từ chối trả lời".
- Nhập hồ sơ từ Word dùng `claude-opus-5-5` (có `fallbacks: "default"`).
- Đổi model: sửa `ClaudeClient.liveModel` (mỗi câu) hoặc `ClaudeClient.model` (nhập hồ sơ) trong `Sources/ClaudeClient.swift`.

## Debug

```bash
open --env UNDERTONE_DEBUG=1 --stdout /tmp/undertone.log build/Undertone.app
```
In ra từng câu nghe được, bản dịch và lỗi.

## Thiết kế

`./design.sh` render mọi trạng thái giao diện ra `build/design/*.png` (không cần quyền quay màn hình)
và tạo lại `Resources/AppIcon.icns`.

## Cấu trúc

| File | Vai trò |
|---|---|
| `Sources/SystemAudioCapture.swift` | Thu âm thanh hệ thống bằng Core Audio process tap |
| `Sources/SonioxTranscriber.swift` | Giọng nói → chữ (Soniox real-time, Anh + Pháp), tách theo từng câu |
| `Sources/CulinaryTerms.swift` | Thuật ngữ bếp gửi cho Soniox và lời dặn cho Claude |
| `Sources/ClaudeClient.swift` | Gọi Claude API (streaming), prompt dịch + gợi ý, cache kho kiến thức |
| `Sources/KnowledgeBase.swift`, `Knowledge/` | Kho kiến thức SIT30821 gửi kèm prompt (có cache) |
| `Sources/AppState.swift` | Trạng thái app, mỗi hàng = một câu |
| `Sources/Views.swift`, `Components.swift` | Giao diện 2 cột, design tokens |
| `Sources/OverlayPanel.swift` | Cửa sổ nổi, chống chụp/chia sẻ |
