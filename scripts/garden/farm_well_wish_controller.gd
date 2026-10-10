extends RefCounted
## Claim the master farmer's daily wishing-well coins exactly once per date.
## The screen owns the clock, saving, sound, and sparkle.

const DAILY_COINS := 2


static func claim(farm: Dictionary, today: String) -> Dictionary:
	if today.is_empty() or str(farm.get("last_well_wish_date", "")) == today:
		return {"claimed": false, "coins": 0}
	farm["last_well_wish_date"] = today
	return {"claimed": true, "coins": DAILY_COINS}
