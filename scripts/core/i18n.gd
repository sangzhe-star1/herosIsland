extends Node
## Minimal runtime localization. English is the default and always complete;
## other locales fall back to English per-key, so a missing translation never
## shows a blank label.
##
## Kept deliberately simple (a JSON dictionary) so strings can be edited without
## the .csv -> .translation import round trip. If the project ever needs plurals
## or context, migrate to Godot's built-in TranslationServer.

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "en"
const STRINGS_PATH := "res://data/strings.json"

var locale: String = DEFAULT_LOCALE
var _strings: Dictionary = {}


func _ready() -> void:
	if FileAccess.file_exists(STRINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRINGS_PATH))
		if parsed is Dictionary:
			_strings = parsed
	locale = SaveManager.get_setting("locale", DEFAULT_LOCALE)


func set_locale(new_locale: String) -> void:
	if not _strings.has(new_locale):
		return
	locale = new_locale
	SaveManager.set_setting("locale", new_locale)
	locale_changed.emit(new_locale)


func available_locales() -> Array:
	return _strings.keys()


## t("home.play") -> "Play". Unknown keys return the key itself, which makes
## missing strings obvious on screen instead of silently empty.
func t(key: String) -> String:
	var table: Dictionary = _strings.get(locale, {})
	if table.has(key):
		return table[key]
	var fallback: Dictionary = _strings.get(DEFAULT_LOCALE, {})
	return fallback.get(key, key)
