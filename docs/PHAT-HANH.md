# Checklist phát hành CS-PROTOCOL lên Google Play, App Store & Web

Áp dụng đúng cấu trúc và tiêu chuẩn phát hành từ dự án mẫu `lofi-garden`.

> **Thông tin chung sửa ở 1 chỗ: `project.godot`**
> - Tên game & phiên bản: mục `[application]` → `config/name`, `config/version`.
> - Người làm, website, đường dẫn chính sách: mục `[app_info]` (`developer`, `website`, `privacy_policy_path`, `support_email`).
> - Code đọc qua `scripts/util/app_info.gd` (`AppInfo.game_name()`, `developer()`, `privacy_url()`).
> - App ID AdMob: mục `[admob]`. Ad Unit ID: `PROD_IDS` trong `scripts/autoload/ad_manager.gd`.
> - Package / Bundle ID: `export_presets.cfg` (`com.vominhthongss.csprotocol`) — **upload lên Store rồi là không đổi được nữa**.

---

## 1. Điền ID thật trước khi phát hành

- [ ] App ID Android & iOS thật → `project.godot`, mục `[admob]`.
- [ ] 6 Ad Unit ID thật (có dấu `/`) → `PROD_IDS` trong `scripts/autoload/ad_manager.gd`.
- [ ] Kiểm tra `FORCE_TEST_IDS := false` trong `scripts/autoload/ad_manager.gd`.

---

## 2. Website & Chính sách

- [ ] Đảm bảo `https://vominhthongss.github.io/app-ads.txt` có dòng:
  ```
  google.com, pub-4353954491556133, DIRECT, f08c47fec0942fa0
  ```
- [ ] Đăng trang chính sách bảo mật tại `https://vominhthongss.github.io/cs-protocol/policy.html` (mẫu trong `store/privacy_policy_template.md`).
- [ ] Publish thông điệp **GDPR** (+ **IDFA** cho iOS) trong **AdMob → Privacy & messaging**.

---

## 3. Android / Google Play (`build/android/CSProtocol.aab`)

Preset `Android` trong `export_presets.cfg` đã cấu hình sẵn:
- Gradle Build (`export_format=1` → `.aab`), `min_sdk=24`, `target_sdk=36`
- Kiến trúc `armeabi-v7a` + `arm64-v8a`, `package/unique_name="com.vominhthongss.csprotocol"`
- `package/app_category=2` (Game), `screen/immersive_mode=false` (banner nằm trên thanh điều hướng)
- Quyền: `INTERNET`, `ACCESS_NETWORK_STATE`, `VIBRATE`
- Đủ bộ Launcher Icon 192×192 và Adaptive Icon 432×432 (`assets/icons/`)

### Các bước thực hiện
- [ ] Trong Godot: **Editor → Manage Export Templates** (bản 4.7.2) và khai **Android SDK Path** + **Java SDK Path (JDK 17)** trong Editor Settings.
- [ ] Trong Godot: **Project → Install Android Build Template…** (tạo `android/build/`, đã được `.gitignore`).
- [ ] Tạo release keystore ngoài thư mục repo (vd `~/keystores/csprotocol-release.keystore`) và khai trong **Project → Export → Android → Keystore → Release**.
- [ ] Thử nghiệm trên máy thật bằng bản Debug `.apk` (kiểm tra Banner, Rewarded `+$1500`, Interstitial đều hiện nhãn **Test Ad**).
- [ ] Export `.aab` (bỏ tick *Export With Debug*) → `build/android/CSProtocol.aab`.
- [ ] Upload lên **Google Play Console**:
  - Icon 512×512: `store/play_store_icon_512.png`
  - Ảnh nổi bật: `store/feature_graphic_1024x500.png`
  - Mô tả Việt–Anh: `store/store_listing.md`
  - **App content**: khai có quảng cáo (*Yes, my app contains ads*), Privacy Policy URL, Data Safety (AdMob), Target audience (không chọn dưới 13 tuổi).
  - Nếu là tài khoản cá nhân mới: chạy **Closed Testing** (tối thiểu 12 người thử trong 14 ngày liên tục) trước khi nộp Production.

---

## 4. iOS / App Store (`build/ios/CSProtocol.ipa`)

Preset `iOS` trong `export_presets.cfg` đã cấu hình sẵn:
- Kiến trúc `arm64`, `min_ios_version=14.0`, `bundle_identifier="com.vominhthongss.csprotocol"`
- `NSUserTrackingUsageDescription` song ngữ Việt–Anh trong `additional_plist_content`
- Đầy đủ khai báo **App Privacy (`PrivacyInfo.xcprivacy`)** cho AdMob (tracking, device_id, coarse_location, product_interaction, advertising_data, crash_data, performance_data)
- Icon App Store 1024×1024 không alpha (`assets/icons/ios_appstore_1024.png`)

### Các bước thực hiện
- [ ] Điền **App Store Team ID** (10 ký tự) trong **Project → Export → iOS**.
- [ ] Export Xcode project từ Godot → mở `.xcodeproj` trong **Xcode** → bật **Automatically manage signing** với Team của bạn.
- [ ] Test trên iPhone thật (chạy từ Xcode là bản debug → hiện **Test Ad** + hộp xin quyền ATT).
- [ ] Chọn đích **Any iOS Device (arm64)** → **Product → Archive** → **Distribute App → App Store Connect**.
- [ ] Tạo app trên **App Store Connect**, điền **App Privacy** theo hướng dẫn AdMob, kiểm thử qua **TestFlight** rồi bấm **Submit for Review**.

---

## 5. Web (`build/web/index.html`)

Preset `Web` đã loại bỏ toàn bộ `addons/`, `store/`, `docs/`, `tests/` và tắt `thread_support` (chạy được trên mọi static host như GitHub Pages mà không cần COOP/COEP header).

Lệnh build lại bản Web:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" build/web/index.html
```

Chạy thử cục bộ:
```bash
cd build/web && python3 -m http.server 8000
```
Mở `http://localhost:8000/index.html`.
