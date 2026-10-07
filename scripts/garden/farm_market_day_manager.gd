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


## The week index, Sunday-start, of the date the child sees. One calendar for
## the board, the banner and the till: GameData.market_calendar().
static func week_number(unix_time: int = -1) -> int:
	return int(GameData.market_calendar(unix_time).get("week", 0))


## The dear produce of that week, from the same calendar the price uses.
static func dear_produce_for_week(unix_time: int = -1) -> String:
	var dear := GameData.market_dear_produce(unix_time)
	return dear if dear != "" else "carrot"


## Weekday of the date the child sees (0=Sun ... 6=Sat).
static func current_weekday(unix_time: int = -1) -> int:
	return int(GameData.market_calendar(unix_time).get("weekday", 0))


## True if today is Friday (announcement day).
static func is_announce_day(unix_time: int = -1) -> bool:
	return current_weekday(unix_time) == announce_weekday()


## True if today is Saturday (market day).
static func is_market_day(unix_time: int = -1) -> bool:
	return current_weekday(unix_time) == market_weekday()


## Returns the dear produce for today's week.
static func current_dear_produce(unix_time: int = -1) -> String:
	return dear_produce_for_week(unix_time)


## Effective unit price for the crop at this moment: the till's own number,
## so the panel's tag and the sale can never disagree.
static func unit_price(crop_id: String, unix_time: int = -1) -> int:
	return GameData.market_price(crop_id, unix_time)


## Whether this crop is doubled right now, by the same rule the price uses.
static func is_doubled(crop_id: String, unix_time: int = -1) -> bool:
	return GameData.market_doubled(crop_id, unix_time)


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
