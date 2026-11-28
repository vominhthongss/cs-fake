# Setup quảng cáo AdMob từ A đến Z — CS-PROTOCOL

Tài liệu thiết lập theo đúng chuẩn của dự án mẫu `lofi-garden`.

> **Tóm tắt nhanh — chỉ có 4 chỗ phải sửa trong source code:**
>
> | # | File | Sửa gì |
> | --- | --- | --- |
> | 1 | `scripts/autoload/ad_manager.gd` | Ad Unit ID thật trong `PROD_IDS` (test/thật tự chọn theo bản build) |
> | 2 | Project Settings → **Admob → General → Android** | `App Id` = App ID Android (`project.godot`, mục `[admob]`) |
> | 3 | Project Settings → **Admob → General → iOS** | `App Id` = App ID iOS (`project.godot`, mục `[admob]`) |
> | 4 | `project.godot`, mục `[app_info]` | `website` + `privacy_policy_path` = link chính sách bảo mật |
>
> Plugin AdMob **đã cài sẵn** trong `addons/admob/` (bản 5.1.0), có đủ thư viện Android (Godot 4.7.2) và iOS. Không cần cài lại.

---

## A. Kiến trúc quảng cáo đã gắn sẵn

| # | Loại | Vị trí | Cách hoạt động |
| --- | --- | --- | --- |
| 1 | **Banner** (Anchored Adaptive, đáy) | Màn hình chính (`TITLE`) | Tự hiện ở Title, chừa `banner_reserved_height()`, tự ẩn hoàn toàn khi vào trận (`PLAYING`) để không che HUD hay vùng ngắm. |
| 2 | **Rewarded** | Nút **XEM QC · +$1500** trong Kho Vũ Khí (`Buy Menu`) | Người chơi chủ động bấm, xem hết sẽ gọi `game.grant_ad_bonus_cash(1500)` và hiện thông báo xác nhận. |
| 3 | **Interstitial** | Nút **Chơi lại** / **Menu chính** ở màn hình kết thúc trận (`GAMEOVER`) | Chỉ gọi sau thao tác người chơi. 3 phút đầu không hiện, cách nhau ≥ 4 phút, tối đa 6 lần/phiên. |
| 4 | **Consent (UMP/GDPR) + ATT** | Tự chạy khi khởi động + nút **Tùy chọn quảng cáo** ở Title & Pause | Xin đồng ý trước khi khởi tạo SDK; chỉ hiện nút tùy chọn khi người dùng ở vùng EU/UK (`privacy_options_required()`). |

### Chế độ Test vs Release

- **Debug / Editor / Export With Debug**: `AdManager.use_test_ids()` tự trả `true` → luôn dùng `TEST_IDS` công khai của Google (có chữ **Test Ad**), an toàn không vi phạm chính sách AdMob.
- **Release (bỏ tick _Export With Debug_)**: tự dùng `PROD_IDS` trong `scripts/autoload/ad_manager.gd`.
- Muốn bản release vẫn chạy quảng cáo test (vd gửi TestFlight / thử nghiệm kín): đặt `const FORCE_TEST_IDS: bool = true` trong `scripts/autoload/ad_manager.gd` (nhớ trả về `false` trước khi nộp Store).
- **Bản Web**: preset Web loại bỏ toàn bộ `addons/` để gói xuất nhẹ nhất; `ad_manager.gd` nạp động class của plugin nên bản Web biên dịch và chạy sạch hoàn toàn không lỗi.

---

## B. Tạo app & Ad Unit trên Google AdMob

1. Truy cập https://admob.google.com → **Apps → Add app**:
   - Tạo 1 app **Android** (`CS-PROTOCOL`) → lấy **Android App ID** (có dấu `~`).
   - Tạo 1 app **iOS** (`CS-PROTOCOL`) → lấy **iOS App ID** (có dấu `~`).
2. Trong mỗi app, vào **Ad units → Add ad unit**, tạo 3 đơn vị quảng cáo:
   - **Banner** (`cs_banner`)
   - **Interstitial** (`cs_interstitial`)
   - **Rewarded** (`cs_rewarded`)
3. Dán 2 App ID vào `project.godot` mục `[admob]` (`general/android/app_id` và `general/ios/app_id`), và 6 Ad Unit ID vào `PROD_IDS` trong `scripts/autoload/ad_manager.gd`.

> **Lưu ý quan trọng:**
> - **App ID** có dấu `~`; **Ad Unit ID** có dấu `/`. Thiếu hoặc sai App ID sẽ làm app crash ngay khi mở trên điện thoại.
> - Tuyệt đối **không tự bấm quảng cáo thật** trên máy mình. Hãy đăng ký Advertising ID của máy vào **AdMob → Settings → Test devices**.

---

## C. Chính sách bảo mật, GDPR & `app-ads.txt`

1. Đặt `store/app-ads.txt` lên gốc domain: `https://vominhthongss.github.io/app-ads.txt`.
2. Đăng trang chính sách bảo mật từ mẫu `store/privacy_policy_template.md` lên `https://vominhthongss.github.io/cs-protocol/policy.html`.
3. Trên **AdMob → Privacy & messaging**:
   - Tạo và **Publish** thông điệp **GDPR** cho app Android & iOS.
   - Tạo và **Publish** thông điệp **IDFA explainer** cho iOS (preset iOS đã khai sẵn `NSUserTrackingUsageDescription` song ngữ Việt–Anh).

Xem log gỡ lỗi trên Android:
```bash
adb logcat -s godot poing-godot-admob
```
