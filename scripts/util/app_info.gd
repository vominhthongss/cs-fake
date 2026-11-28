class_name AppInfo
extends RefCounted

## Thông tin chung của app, đọc từ 1 chỗ duy nhất: project.godot (giống lofi-garden/scripts/util/app_info.gd).
##   - Tên game / phiên bản: mục [application] -> config/name, config/version
##   - Người làm, web, chính sách: mục [app_info]

const _DEFAULT_WEBSITE: String = "https://vominhthongss.github.io"
const _DEFAULT_PRIVACY_PATH: String = "/cs-protocol/policy.html"


static func game_name() -> String:
	return String(ProjectSettings.get_setting("application/config/name", "CS-PROTOCOL // Tactical Bot FPS"))


static func short_name() -> String:
	return String(ProjectSettings.get_setting("app_info/short_name", "CS-PROTOCOL"))


static func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "1.0.0"))


static func developer() -> String:
	return String(ProjectSettings.get_setting("app_info/developer", "vominhthongss"))


static func website() -> String:
	return String(ProjectSettings.get_setting("app_info/website", _DEFAULT_WEBSITE)).trim_suffix("/")


static func support_email() -> String:
	return String(ProjectSettings.get_setting("app_info/support_email", "contact@vominhthongss.github.io"))


static func privacy_url() -> String:
	var path: String = String(ProjectSettings.get_setting("app_info/privacy_policy_path", _DEFAULT_PRIVACY_PATH))
	if not path.begins_with("/"):
		path = "/" + path
	return website() + path
