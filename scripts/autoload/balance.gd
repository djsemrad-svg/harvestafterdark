extends Node
## Every tunable number in Harvest Afterdark lives here.
## Change a value, save, and run the game. No other code needs to change.

const TILE := 16
const SAVE_VERSION := 1
const SLOTS_PER_MODE := 3
const MODES := ["survivor", "adventure"]

var time := {
	"real_sec_per_10_min": 7.0,   # 10 in-game minutes = 7 real seconds
	"day_start": 6 * 60,          # 6:00 AM
	"midnight": 24 * 60,          # tiredness warning
	"pass_out": 26 * 60,          # 2:00 AM (minutes past the day's midnight)
	"late_sleep_start": 24 * 60,  # sleeping after this restores less energy
}

var calendar := {
	"days_per_season": 30,
	"seasons": ["spring", "summer", "autumn", "winter"],
	"weekdays": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
}

var player := {
	"walk_speed": 66.0,   # pixels per second
	"max_health": 100,
	"max_energy": 120,
	"start_money": 500,
	"swing_sec": 0.26,
	"iframes_sec": 1.1,
}

var inventory := {
	"survivor_slots": 24,   # Survivor Mode: limited carrying capacity
	"adventure_slots": 36,
	"backpack_bonus": 12,   # one upgrade sold at the general store
	"max_slots": 48,
	"toolbar_size": 12,
	"chest_slots": 24,
	"fridge_slots": 24,
}

var energy := {
	"tool_base_cost": 2.0,
	"skill_cost_reduction_per_level": 0.04,
	"late_sleep_restore": 0.75,
	"pass_out_restore": 0.5,
}

var survival := {   # Survivor Mode only
	"hunger_max": 100.0,
	"thirst_max": 100.0,
	"hunger_drain_per_hour": 3.0,
	"thirst_drain_per_hour": 4.4,
	"overnight_hunger_drain": 12.0,
	"overnight_thirst_drain": 16.0,
	"low_threshold": 25.0,
	"critical_threshold": 10.0,
	"low_speed_mult": 0.9,
	"low_tool_energy_mult": 1.25,
	"zero_speed_mult": 0.72,
	"zero_tool_energy_mult": 1.6,
	"low_sleep_energy_mult": 0.8,
	"zero_sleep_energy_mult": 0.5,
	"grace_minutes": 120,          # time at zero before health starts dropping
	"health_loss_per_hour": 6.0,
	"health_loss_growth_per_hour": 3.0,   # gets worse every hour past the grace period
	"skill_drain_reduction": 0.03,
	"summer_heat_thirst_mult": 1.3,
}

var modes := {
	"survivor": {
		"label": "Survivor Mode", "difficulty": "Hard",
		"bites_kill": true, "survival_meters": true,
		"tool_energy_mult": 1.15, "debris_respawn_mult": 0.8, "forage_mult": 0.8,
		"collapse_money_pct": 0.10, "collapse_money_max": 1000,
		"collapse_health_restore": 0.35, "collapse_hours_lost": 3,
		"pass_out_money_pct": 0.10, "pass_out_money_max": 1000,
		"bonus_reward_mult": 1.25,
	},
	"adventure": {
		"label": "Adventure Mode", "difficulty": "Normal / Relaxed",
		"bites_kill": false, "survival_meters": false,
		"tool_energy_mult": 1.0, "debris_respawn_mult": 1.0, "forage_mult": 1.0,
		"collapse_money_pct": 0.05, "collapse_money_max": 300,
		"collapse_health_restore": 0.6, "collapse_hours_lost": 2,
		"pass_out_money_pct": 0.05, "pass_out_money_max": 500,
		"bonus_reward_mult": 1.0,
	},
}

var farming := {
	"empty_soil_revert_chance": 0.25,
	"can_base_capacity": 40,
	"can_capacity_per_tier": 30,
}

var world := {
	"debris_per_night": 4,
	"forage_cap_per_map": 6,
	"forage_per_day": 3,
}

var fishing := {
	"bite_min_sec": 1.5, "bite_max_sec": 6.0, "react_sec": 1.0,
	"bar_base": 0.24, "bar_per_level": 0.012,
	"bar_lift": 2.0, "bar_gravity": 1.8, "bar_max_speed": 0.95,
	"gain_per_sec": 0.34, "loss_per_sec": 0.18, "start_progress": 0.3,
	"junk_chance": 0.12,
}

var combat := {
	"weapon_hit_range": 20.0,
	"knockback": 60.0,
	"telegraph_sec": 0.65,   # infected wind-up before a lunge (always visible)
	"lunge_sec": 0.26,
	"lunge_speed": 120.0,
	"bite_reach": 11.0,
	"recover_sec": 0.7,
}

## Weapons. Stats per weapon live in design/weapons.csv (see tools/build_gear.py).
var weapons := {
	"crit_mult": 2.0,             # critical hits do this much damage
	"stamina_to_energy": 0.15,    # the sheet's Stamina Cost x this = energy per attack
	"sneak_mult": 1.5,            # any hit on an infected that hasn't noticed you
	"noise_tiles": 2.8,           # gunshot heard this many tiles away per point of Noise
	"melee_noise_tiles": 1.0,
	"reach_px": 6.0,              # added to the weapon's range for melee hits
	"cone": 0.35,                 # how wide a normal swing is (dot product; lower is wider)
	"wide_cone": -0.15,
	"bullet_speed": 520.0, "pellet_speed": 460.0, "arrow_speed": 300.0, "bolt_speed": 340.0,
	"stone_speed": 260.0, "thrown_speed": 250.0, "boomerang_speed": 210.0, "flare_speed": 240.0,
	"max_range_tiles": 32.0,      # projectiles stop after this far, whatever the sheet says
	"hit_radius": 9.0,
	"chain_tiles": 3.0,
	"stomp_damage": 30.0,
	"shove_damage": 4.0,
	"shove_energy": 2.0,
	"shove_cooldown": 0.8,
}

## Achievements that unlock legendary gear.
var achievements := {
	"marksman_tiles": 15,         # Marksman: critical kills from at least this far away
	"marksman_count": 100,
	"heavy_metal_count": 1000,    # Heavy Metal: chainsaw kills
}

## Fruit trees from saplings (item sheet): days to grow up before they fruit.
var trees := {"grow_days": 28}

## Searching wrecks, suitcases and crates.
var loot := {"respawn_days": 7}

## Moving around.
var movement := {
	"sprint_mult": 1.45,
	"sprint_energy_per_sec": 1.2,
	"sprint_detect_mult": 1.35,   # infected notice you from farther while you run
	"crouch_mult": 0.6,
	"crouch_detect_mult": 0.6,
	"dash_speed": 260.0, "dash_sec": 0.18,
}

## Durability repairs (Varga Forge and Mercer Workshop).
var repair := {
	"base_pct": 0.05,      # of the item's price, always
	"wear_pct": 0.45,      # of the price, times wear ^ curve
	"curve": 1.6,          # above 1: the last stretch before breaking costs the most
	"broken_pct": 0.4,     # extra for a broken item (Adventure Mode)
	"min_gold": 10,
	"units_per_wear": 4,
	"broken_units": 2,
	"mats": {"Normal": "scrap", "Rare": "copper_bar", "Epic": "iron_bar", "Legendary": "gold_bar", "Cosmetic": "cloth"},
}

## Armour: damage taken is multiplied by 1 - armor / (armor + armor_k).
var armor := {"armor_k": 60.0}

var mining := {
	"ladder_chance_per_rock": 0.035,
	"lift_every": 5,
	"max_floor_phase1": 20,
}

var friendship := {
	"points_per_heart": 100, "max_hearts": 10,
	"talk_points": 12, "gift_love": 80, "gift_like": 45, "gift_neutral": 20, "gift_dislike": -25,
	"gifts_per_week": 2, "birthday_mult": 8, "daily_decay": 2,   # points lost each day you don't talk
}

var skills := {
	"xp_table": [0, 100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000],
	"max_level": 10,
}

var services := {
	"geode_fee": 25,
	## Hal repairs the farmhouse one stage at a time (done overnight). "to" is the new condition (see Data.CONDITIONS).
	"house_repairs": [
		{"to": 2, "name": "Seal the farmhouse", "desc": "Patch the roof holes, replace the broken glass and pull the vines.", "price": 600, "mats": [["wood", 60], ["stone", 20]]},
		{"to": 3, "name": "Fortify the farmhouse", "desc": "Iron-strapped door, taped windows, sandbags and a tarp over the worst of the roof.", "price": 2000, "mats": [["wood", 120], ["stone", 60], ["copper_bar", 2]]},
		{"to": 4, "name": "Restore the farmhouse", "desc": "New shingles, fresh paint, curtains and flower boxes. A real home again.", "price": 5000, "mats": [["wood", 150], ["iron_bar", 3]]},
	],
	"refine_fee_per_bar": {"copper_bar": 15, "iron_bar": 30, "silver_bar": 60, "gold_bar": 100, "aurium_bar": 250},
}

## Night raids: groups of infected that come out of the treeline onto the homestead.
var raids := {
	"grace_days": 4,               # no raids before this day
	"base_chance": 0.2,            # chance of a raid on a given night
	"chance_per_season": 0.05,     # grows each season that passes
	"max_chance": 0.55,
	"adventure_chance_mult": 0.6,
	"size_base": 2,
	"size_per_days": 12,           # +1 raider per this many days
	"size_random": 2,
	"max_size": 12,
	"adventure_size_mult": 0.6,
	"warn_time": 1080,             # 6:00 pm warning
	"start_time": 1320,            # 10:00 pm infected arrive (if you are on the homestead)
	"overnight_barrier_damage": 25,  # damage one raider does to a barrier overnight
	"live_barrier_damage": 6,        # damage per swipe while you watch
	"live_attack_sec": 1.2,
	"trample_per_raider": 2,       # crops a raider can ruin once inside
	"xp_per_turret_kill": 3,       # survival xp you earn for each infected your turrets stop
}

## Power for advanced turrets, electric fences and floodlights.
var power := {
	"radius_tiles": 10,            # devices within this many tiles of a source can draw from it
	"coal_per_night": 1,           # a generator burns this much while powering devices overnight
	"generator_fuel_cap": 10,
}

var farming_extra := {
	"tonic_bonus_chance": 0.3,     # Growth Tonic: chance of an extra day of growth
	"mulch_keep_chance": 0.5,      # Moisture Mulch: chance soil stays watered overnight
	"rain_collector_cap": 5,
}

var bombs := {
	"fuse_sec": 1.8,
	"player_damage": 15,
}

var animals := {
	"coop_capacity": 8,
	"hopper_cap": 60,
	"pet_points": 15,           # friendship for petting once a day
	"fed_points": 5,            # each morning after eating
	"unfed_points": -20,
	"unpetted_points": -5,      # each day you don't pet them
	"big_product_friendship": 600,
	"big_product_chance": 0.5,
	"rare_friendship": 800,
	"rare_chance": 0.08,
	"hay_from_weeds_chance": 0.5,   # once you own a coop, scything weeds can give hay
	"open_door_losses_per": 2,      # one animal lost per this many raiders that reach an open coop
	"outside_start": 540, "outside_end": 1080,
}
