# Shop catalog: every tool, machine and upgrade with its category, tiers, prices, effects and hotbar slot.
class_name Catalog
extends RefCounted

const TOOLS := "Tools"
const UPGRADES := "Upgrades"
const MACHINES := "Machines"

const ITEMS := {
	"conveyor_remote": {
		"category": TOOLS, "kind": "tool", "slot": 1, "name": "Conveyor remote",
		"desc": "Click where a belt starts, walk to where it ends and click again. Snaps to belts and machines; start or end on a belt's middle to split or merge.",
		"tiers": [{"price": 15}],
	},
	"belt_meters": {
		"category": TOOLS, "kind": "meters", "name": "More belt", "requires": "conveyor_remote",
		"desc": "Every meter of conveyor uses one meter of belt. Dismantling gives it back.",
	},
	"pitchfork": {
		"category": TOOLS, "kind": "tool", "slot": 2, "name": "Pitchfork",
		"desc": "Hold on the stack to rip out a whole forkful of straws at once. They fly out at your feet.",
		"stat": "fork_count", "unit": " straws",
		"tiers": [{"price": 40, "value": 3}, {"price": 140, "value": 5}, {"price": 380, "value": 8}],
	},
	"basket": {
		"category": TOOLS, "kind": "tool", "slot": 3, "name": "Hay basket",
		"desc": "Click loose straws to toss them in. Hold right mouse to pour everything out in front of you, onto a belt or into a machine.",
		"stat": "basket_capacity", "unit": " straws",
		"tiers": [{"price": 60, "value": 10}, {"price": 160, "value": 25}, {"price": 400, "value": 50}],
	},
	"blower": {
		"category": TOOLS, "kind": "tool", "slot": 4, "name": "Leaf blower",
		"desc": "Hold to blast loose straws away in a cone. Sweep piles onto belts without touching them.",
		"stat": "blower_force", "unit": "x force",
		"tiers": [{"price": 90, "value": 1.0}, {"price": 240, "value": 1.8}],
	},
	"vacuum": {
		"category": TOOLS, "kind": "tool", "slot": 5, "name": "Hay vacuum",
		"desc": "Hold to suck up loose straws from a distance into the tank. Hold right mouse to shoot them back out as a stream.",
		"stat": "vacuum_capacity", "unit": " straws",
		"tiers": [{"price": 180, "value": 30}, {"price": 480, "value": 80}],
	},
	"shop_remote": {
		"category": TOOLS, "kind": "tool", "slot": 6, "name": "Shop remote",
		"desc": "Opens this shop from anywhere on the plate, so you never have to walk to the booth.",
		"tiers": [{"price": 150}],
	},
	"auto_puller": {
		"category": MACHINES, "kind": "machine", "slot": 7, "name": "Auto puller",
		"desc": "Place it facing the stack. Its arm pulls straws out by itself and drops them onto its own short belt. Snap a conveyor to the end.",
		"price": 250,
	},
	"hopper": {
		"category": MACHINES, "kind": "machine", "slot": 8, "name": "Hopper",
		"desc": "A funnel on legs. Drop, throw or pour straws in and it feeds them out one by one onto a belt.",
		"price": 120,
	},
	"mini_seller": {
		"category": MACHINES, "kind": "machine", "slot": 9, "name": "Sell bin",
		"desc": "A small sell point you can put anywhere. Straws that land in it or ride a belt into it are sold at your current price.",
		"price": 400,
	},
	"gloves": {
		"category": UPGRADES, "kind": "upgrade", "name": "Work gloves",
		"desc": "Get a better grip so pulling a straw out of the stack takes less time.",
		"stat": "pull_time", "unit": " s", "base": 2.0,
		"tiers": [{"price": 25, "value": 1.4}, {"price": 80, "value": 0.9}, {"price": 220, "value": 0.5}],
	},
	"buyer": {
		"category": UPGRADES, "kind": "upgrade", "name": "Better buyer",
		"desc": "Sign a better contract. Every straw sold anywhere pays more.",
		"stat": "sell_price", "prefix": "$", "base": 1,
		"tiers": [{"price": 50, "value": 2}, {"price": 160, "value": 3}, {"price": 450, "value": 5}],
	},
	"belt_motors": {
		"category": UPGRADES, "kind": "upgrade", "name": "Belt motors",
		"desc": "Stronger motors make every conveyor, splitter and machine belt run faster.",
		"stat": "belt_speed", "unit": " m/s", "base": 1.1,
		"tiers": [{"price": 40, "value": 1.6}, {"price": 130, "value": 2.2}, {"price": 350, "value": 3.0}],
	},
	"running_shoes": {
		"category": UPGRADES, "kind": "upgrade", "name": "Running shoes",
		"desc": "Walk and sprint faster around the plate.",
		"stat": "move_speed", "unit": "x", "base": 1.0,
		"tiers": [{"price": 30, "value": 1.2}, {"price": 100, "value": 1.45}],
	},
	"spring_boots": {
		"category": UPGRADES, "kind": "upgrade", "name": "Spring boots",
		"desc": "Jump higher, high enough to reach the top of the stack.",
		"stat": "jump", "unit": " m/s", "base": 4.8,
		"tiers": [{"price": 45, "value": 6.8}, {"price": 140, "value": 9.0}],
	},
	"long_arms": {
		"category": UPGRADES, "kind": "upgrade", "name": "Long arms",
		"desc": "Reach straws, the stack and machines from further away.",
		"stat": "reach", "unit": " m", "base": 3.4,
		"tiers": [{"price": 35, "value": 4.5}, {"price": 110, "value": 6.0}],
	},
	"strong_arm": {
		"category": UPGRADES, "kind": "upgrade", "name": "Strong arm",
		"desc": "Throw straws further and charge throws faster.",
		"stat": "throw_power", "unit": " m/s", "base": 12.0,
		"tiers": [{"price": 30, "value": 18.0}, {"price": 90, "value": 26.0}],
	},
	"bulk_belt": {
		"category": UPGRADES, "kind": "upgrade", "name": "Bulk belt deal",
		"desc": "Buy belt by the roll. Every meter costs less.",
		"stat": "meter_price", "prefix": "$", "unit": " / m", "base": 3,
		"tiers": [{"price": 80, "value": 2}, {"price": 260, "value": 1}],
	},
	"puller_motors": {
		"category": UPGRADES, "kind": "upgrade", "name": "Puller motors",
		"desc": "Auto pullers pull straws out more often.",
		"stat": "puller_interval", "unit": " s", "base": 4.0, "requires": "auto_puller",
		"tiers": [{"price": 150, "value": 2.5}, {"price": 400, "value": 1.5}, {"price": 900, "value": 0.8}],
	},
}

const ORDER := [
	"conveyor_remote", "belt_meters", "pitchfork", "basket", "blower", "vacuum", "shop_remote",
	"auto_puller", "hopper", "mini_seller",
	"gloves", "buyer", "belt_motors", "running_shoes", "spring_boots", "long_arms", "strong_arm", "bulk_belt", "puller_motors",
]

const TOOL_DEFAULTS := {
	"fork_count": 0, "basket_capacity": 0, "blower_force": 0.0, "vacuum_capacity": 0,
}


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func tier_count(id: String) -> int:
	return (item(id).get("tiers", []) as Array).size()


static func format_value(id: String, value: Variant) -> String:
	var it := item(id)
	var v: Variant = value
	var text := ""
	if v is float and not is_equal_approx(v, round(v)):
		text = "%.1f" % v
	else:
		text = str(int(round(float(v))))
	return str(it.get("prefix", "")) + text + str(it.get("unit", ""))


static func slot_items() -> Array:
	var out: Array = []
	for id in ORDER:
		if item(id).has("slot"):
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return int(item(a).slot) < int(item(b).slot))
	return out
