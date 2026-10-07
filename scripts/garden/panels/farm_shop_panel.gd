extends "res://scripts/garden/panels/farm_panel_base.gd"
## Seed catalogue sheet: browsing and buying seeds.

const SeedShop := preload("res://scripts/garden/seed_shop_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")

const PANEL_PAGE := 6


func build(view: Vector2) -> void:
	var wide := 780.0
	var tall := 430.0
	var origin: Vector2 = screen.call("_panel_sheet", view, "garden.shop_title", wide, tall)
	var seeds: Array = GameData.farm_seed_shop.get("seeds", [])
	var pages := int(ceil(seeds.size() / float(PANEL_PAGE)))
	var page := clampi(int(screen.get("_shop_page")), 0, maxi(pages - 1, 0))
	screen.set("_shop_page", page)

	screen.call("_pager", origin, wide, tall, page, pages, func(step: int):
		screen.set("_shop_page", int(screen.get("_shop_page")) + step)
		screen.set("_confirm_crop", "")
		screen.call("_queue_rebuild"))

	var panel_buttons: Dictionary = screen.get("_panel_buttons")
	var y := origin.y + 74.0
	for row in seeds.slice(page * PANEL_PAGE, (page + 1) * PANEL_PAGE):
		var crop_id := str(row.get("crop_id", ""))
		var crop: Dictionary = GameData.get_crop(crop_id)
		if crop.is_empty():
			continue
		var gated: bool = SeedShop.state_of(crop_id) == "level"
		var art := UiKit.picture(str(crop.get("icon", "seed")), 44.0)
		if art != null:
			art.position = Vector2(origin.x + 30.0, y)
			if gated:
				art.modulate = Color(1, 1, 1, 0.35)
			play.add_child(art)
		var name_tag := UiKit.title(I18n.t(str(crop.get("name_key", ""))), 24,
			Color(0.62, 0.60, 0.56) if gated else Color(0.25, 0.22, 0.18))
		name_tag.position = Vector2(origin.x + 88.0, y + 8.0)
		name_tag.size = Vector2(96, 30)
		play.add_child(name_tag)

		if gated:
			var badge := UiKit.picture("star", 30.0)
			if badge != null:
				badge.position = Vector2(origin.x + 200.0, y + 6.0)
				play.add_child(badge)
			var lvl := UiKit.title(str(SeedShop.level_needed(crop_id)), 26,
				Color(0.62, 0.52, 0.36))
			lvl.position = Vector2(origin.x + 238.0, y + 7.0)
			lvl.size = Vector2(44, 30)
			play.add_child(lvl)
			y += 56.0
			continue

		var coin := UiKit.picture("star_coin", 26.0)
		if coin != null:
			coin.position = Vector2(origin.x + 200.0, y + 8.0)
			play.add_child(coin)
		var price := SeedShop.price_of(crop_id)
		var price_tag := UiKit.title("0" if price <= 0 else str(price), 24)
		price_tag.position = Vector2(origin.x + 232.0, y + 7.0)
		price_tag.size = Vector2(64, 30)
		play.add_child(price_tag)

		var seconds := int(GameData.crop_total_seconds(crop_id))
		var longest: int = screen.call("_longest_wait")
		var ring := UiKit.wait_ring(float(seconds) / maxf(float(longest), 1.0), 28.0)
		ring.position = Vector2(origin.x + 318.0, y + 8.0)
		play.add_child(ring)
		var grow_time: String = screen.call("_grow_time_text", seconds)
		var time_tag := UiKit.title(grow_time, 18, Color(0.52, 0.48, 0.40))
		time_tag.position = Vector2(origin.x + 352.0, y + 12.0)
		time_tag.size = Vector2(60, 24)
		play.add_child(time_tag)
		var pick := UiKit.picture("basket", 26.0)
		if pick != null:
			pick.position = Vector2(origin.x + 424.0, y + 8.0)
			play.add_child(pick)
		var count_tag := UiKit.title("x%d" % int(crop.get("harvest_amount", 1)), 24)
		count_tag.position = Vector2(origin.x + 456.0, y + 7.0)
		count_tag.size = Vector2(60, 30)
		play.add_child(count_tag)

		match SeedShop.state_of(crop_id):
			"owned", "free":
				var tick := UiKit.picture("check", 30.0)
				if tick != null:
					tick.position = Vector2(origin.x + wide - 200.0, y + 6.0)
					play.add_child(tick)
				var owned_tag := UiKit.title(I18n.t("garden.owned"), 22)
				owned_tag.position = Vector2(origin.x + wide - 162.0, y + 9.0)
				owned_tag.size = Vector2(90, 28)
				play.add_child(owned_tag)
			"buyable":
				var buy: Button = screen.call("_chip_button", I18n.t("garden.buy"),
					Color(0.72, 0.88, 0.60), Vector2(150, 48))
				buy.position = Vector2(origin.x + wide - 214.0, y - 4.0)
				var this_crop := crop_id
				buy.pressed.connect(func():
					screen.set("_confirm_crop", this_crop)
					screen.call("_queue_rebuild"))
				play.add_child(buy)
				if panel_buttons != null:
					panel_buttons["buy_%s" % crop_id] = buy
			"poor":
				var short_tag := UiKit.title(
					"还差%d" % Coins.short_by(price), 22, Color(0.62, 0.52, 0.36))
				short_tag.position = Vector2(origin.x + wide - 200.0, y + 9.0)
				short_tag.size = Vector2(150, 28)
				play.add_child(short_tag)
		y += 56.0

	var confirm_crop: String = str(screen.get("_confirm_crop"))
	if confirm_crop != "":
		screen.call("_confirm_card", view, origin, wide)
