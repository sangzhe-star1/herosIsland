extends Node
## Minimal runtime localization.
##
## The island is played in Chinese: DEFAULT_LOCALE is zh, which is what a
## fresh save starts in. English remains the FALLBACK language -- every key
## exists there, so a translation added to only one locale can never show a
## blank label -- and it is one tap away in the Parent Center for anyone who
## wants it.
##
## Kept deliberately simple (a JSON dictionary) so strings can be edited without
## the .csv -> .translation import round trip. If the project ever needs plurals
## or context, migrate to Godot's built-in TranslationServer.

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "zh"
## Where a missing key is looked up second. Kept complete by tools_check.py.
const FALLBACK_LOCALE := "en"
const STRINGS_PATH := "res://data/strings.json"

var locale: String = DEFAULT_LOCALE
var _strings: Dictionary = {}


func _ready() -> void:
	print("[autoload] I18n starting")
	if FileAccess.file_exists(STRINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRINGS_PATH))
		if parsed is Dictionary:
			_strings = parsed
	locale = SaveManager.get_setting("locale", DEFAULT_LOCALE)
	print("[autoload] I18n ok: locale=%s, %d locales loaded" % [locale, _strings.size()])


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
	# English second, always: it is the complete table by construction, and
	# the default locale is now zh -- falling back to the DEFAULT would mean
	# falling back to the very table the key is missing from.
	var fallback: Dictionary = _strings.get(FALLBACK_LOCALE, {})
	return fallback.get(key, key)
