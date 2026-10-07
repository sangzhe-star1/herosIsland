extends RefCounted
## Farm Market Day Manager: deterministic weekly market day and announce day.
##
## Rules:
## 1. Once a week (Friday, weekday 5), the board announces tomorrow's dear produce.
## 2. On Market Day (Saturday, weekday 6), prices for that one produce double (x2).
## 3. The dear produce rotates deterministically by week, teaching planning ahead.
## 4. No RNG, no gambling, no fail states.


static func config() -> Dictionary:
	return GameData.farm_market_day


static func announce_weekday() -> int:
	return int(config().get("announce_weekday", 5))


static func market_weekday() -> int:
	return int(config().get("market_weekday", 6))


static func multiplier() -> int:
	return int(config().get("multiplier", 2))


static func rotation() -> Array:
	return config().get("rotation", [
		"carrot", "strawberry", "tomato", "corn",
		"potato", "pumpkin", "egg", "wheat", "milk", "honey", "fish"
	])


## Returns the stable week number from unix seconds.
## Week starts on Sunday (weekday 0 in Godot Time).
static func week_number(unix_time: int = -1) -> int:
	var t := unix_time if unix_time >= 0 else GameClock.now_unix()
	var days := int(t / 86400)
	var weekday := (days + 4) % 7
	var sunday_days := days - weekday
	return int(sunday_days / 7)


## Returns the dear produce key for the given unix timestamp's week.
static func dear_produce_for_week(unix_time: int = -1) -> String:
	var rot := rotation()
	if rot.is_empty():
		return "carrot"
	var w := week_number(unix_time)
	var idx := posmod(w, rot.size())
	return str(rot[idx])


## Current weekday according to GameClock (0=Sun, 1=Mon, ..., 6=Sat).
static func current_weekday(unix_time: int = -1) -> int:
	var t := unix_time if unix_time >= 0 else GameClock.now_unix()
	var days := int(t / 86400)
	return (days + 4) % 7


## True if today is Friday (announcement day).
static func is_announce_day(unix_time: int = -1) -> bool:
	return current_weekday(unix_time) == announce_weekday()


## True if today is Saturday (market day).
static func is_market_day(unix_time: int = -1) -> bool:
	return current_weekday(unix_time) == market_weekday()


## Returns the dear produce for today's week.
static func current_dear_produce(unix_time: int = -1) -> String:
	return dear_produce_for_week(unix_time)


## Effective unit price for the crop at this moment in time.
static func unit_price(crop_id: String, unix_time: int = -1) -> int:
	var base := maxi(0, int(GameData.farm_market_prices.get("prices", {}).get(crop_id, 0)))
	if is_market_day(unix_time) and crop_id == current_dear_produce(unix_time):
		return base * multiplier()
	return base


## Whether this crop is currently doubled in price right now.
static func is_doubled(crop_id: String, unix_time: int = -1) -> bool:
	return is_market_day(unix_time) and crop_id == current_dear_produce(unix_time)


## Localized name of the crop or produce.
static func crop_display_name(crop_id: String) -> String:
	var crop := GameData.get_crop(crop_id)
	if not crop.is_empty():
		return I18n.t(str(crop.get("name_key", crop_id)))
	return crop_id.capitalize()


## Icon name of the crop or produce.
static func crop_icon(crop_id: String) -> String:
	var crop := GameData.get_crop(crop_id)
	if not crop.is_empty():
		return str(crop.get("icon", crop_id))
	return "star_coin"
