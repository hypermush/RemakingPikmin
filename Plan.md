# Pikmin Remake — Next Features Plan

## Context

The core MVP loop is solid: throw Pikmin → carry pellets to onion → grow squad → break walls.
This plan adds four interconnected features to move toward a playable game loop:
enemy combat, Pikmin strength progression via nectar, a ship delivery destination, and a functioning day timer.

---

## Feature 1: Enemy AI

### Goal
A moving entity that wanders the map, can kill Pikmin (with a cooldown to prevent squad wipes),
takes damage from Pikmin attacks, and on death drops a carryable and a nectar blob.

### Architecture
- **New script:** `scripts/enemy.gd` — extends `CharacterBody3D`
- **New scene:** `scenes/enemy.tscn`

### enemy.gd design
```
Properties:
  max_health: int = 5
  current_health: int
  is_destroyed: bool = false
  kill_cooldown: float = 2.0  # seconds between kills
  _last_kill_time: float = 0.0
  move_speed: float = 2.0
  wander_radius: float = 8.0
  _navigation_agent: NavigationAgent3D
  @export var drop_carryable: PackedScene
  @export var drop_nectar: PackedScene

State machine: WANDERING only (for now)
  - Pick a random point within wander_radius of spawn
  - Navigate to it via NavigationAgent3D
  - On arrival, pick a new point

take_damage(amount):
  current_health -= amount
  if current_health <= 0: die()

die():
  is_destroyed = true
  Instantiate drop_carryable at global_position → add to scene
  Instantiate drop_nectar at global_position → add to scene
  queue_free()
```

### Pikmin killing Pikmin
- Enemy has a child `Area3D` (combat zone, small radius)
- On `body_entered(body)`: if body is Pikmin and cooldown elapsed → call `body.take_damage(99)` (instant kill), reset timer
- Pikmin.take_damage() already exists; ensure it calls `queue_free()` and removes itself from player squad

### Pikmin attacking enemy
Enemy needs the same interface as `Workable` so Pikmin can attack it:
- `take_damage(amount)` ✅ (designed above)
- `is_destroyed` ✅

Modify `scripts/pikmin.gd`:
- In `_on_area_entered()`: add detection for Enemy nodes (check `area.get_parent() is Enemy` or use a group `"enemy"`)
- When detected: set `assigned_target = enemy`, state → `WORKING`
- The existing WORKING state loop already calls `assigned_target.take_damage(1)` every second — no change needed there
- In `_physics_process()` WORKING state: ensure it navigates to enemy's position (currently navigates to `assigned_target.global_position` for workables — same logic applies)

---

## Feature 2: Pikmin Strength (Nectar System)

### Goal
Pikmin have a leaf→bud→flower progression. Drinking nectar advances them one stage.
Higher stages = more damage and faster movement.

### Pikmin changes (`scripts/pikmin.gd`)
```
Add:
  enum Strength { LEAF, BUD, FLOWER }
  var strength: Strength = Strength.LEAF

  func upgrade_strength():
    if strength < Strength.FLOWER:
      strength += 1

  func get_damage() -> int:
    match strength:
      Strength.LEAF: return 1
      Strength.BUD:  return 2
      Strength.FLOWER: return 3

  func get_speed() -> float:
    match strength:
      Strength.LEAF:   return SPEED          # 4.0
      Strength.BUD:    return SPEED * 1.2    # 4.8
      Strength.FLOWER: return SPEED * 1.5    # 6.0
```

- Replace hardcoded `1` in `take_damage(1)` calls with `get_damage()`
- Replace hardcoded `SPEED` in movement with `get_speed()`

### Nectar object
- **New script:** `scripts/nectar.gd` — extends `Area3D`
- **New scene:** `scenes/nectar.tscn`
- On `body_entered(body)`: if body is Pikmin → call `body.upgrade_strength()`, `queue_free()`
- Enemy drops it on `die()` (see Feature 1)

### Visual (placeholder)
- Pikmin node has a `MeshInstance3D` child for its body
- On strength change: swap material color (e.g. green/yellow/white tint)
- Full petal mesh swap is a future task — this is just a color hint for now

---

## Feature 3: Ship Delivery Destination

### Goal
Some carryables deliver to the ship instead of the onion.
Ship delivery increments a treasure count tracked in GlobalRefs and shown on the HUD.

### GlobalRefs changes (`scripts/singletons/GlobalRefs.gd`)
```
Add:
  var ship: Node = null
  var treasure_count: int = 0
```

### CarryDestination changes (`scripts/carry_destination.gd`)
- Already has `DestinationType { SHIP, ONION }` and sets `GlobalRefs.onion` on ready
- Add: if `destination_type == DestinationType.SHIP` → set `GlobalRefs.ship = self`
- In `_on_carryable_reached_destination(payload)`:
  - ONION branch: existing seed spawn logic (unchanged)
  - SHIP branch: `GlobalRefs.treasure_count += payload.value` → emit a signal or call HUD update

### Carryable targeting
- `scripts/carryable_item.gd`: `carry_destination` currently defaults to `GlobalRefs.onion`
- Add `@export var goes_to_ship: bool = false`
- In `_ready()`: `carry_destination = GlobalRefs.ship if goes_to_ship else GlobalRefs.onion`
- Ship-bound items (e.g. melon) set `goes_to_ship = true` in their scene

### HUD changes (`hud.gd` + `hud.tscn`)
- HUD already has a `TotalCount` label — repurpose or add a treasure count display
- Player emits `update_hud_values` signal; add treasure count to that payload
- Or: ship CarryDestination emits its own signal to HUD directly

---

## Feature 4: Day Timer

### Goal
A countdown timer drives the DayProgress bar and DayNumber label.
On expiry: all Pikmin not in the onion die, then transition to the main menu.

### New script: `scripts/day_timer.gd` (or add to `hud.gd`)
Recommend a standalone autoload or a node in `level.tscn`:
```
@export var day_duration: float = 360.0  # 6 minutes
var time_remaining: float

func _ready():
  time_remaining = day_duration

func _process(delta):
  time_remaining -= delta
  var progress = time_remaining / day_duration  # 1.0 → 0.0
  emit_signal("day_progress_updated", progress)
  if time_remaining <= 0:
    _end_day()

func _end_day():
  # Kill all non-onion Pikmin
  for pikmin in get_tree().get_nodes_in_group("pikmin"):
    pikmin.queue_free()
  # Transition to main menu
  get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

Add Pikmin to group `"pikmin"` in `pikmin.gd._ready()`:
```
add_to_group("pikmin")
```

### HUD wiring
- Connect `day_progress_updated` signal to HUD
- HUD updates `DayProgress.value` (0–1 range) and `DayNumber` label
- Day number can start at 1 and increment each cycle (store in GlobalRefs)

---

## Critical Files to Modify

| File | Changes |
|------|---------|
| `scripts/pikmin.gd` | Add Strength enum, get_damage/get_speed helpers, enemy detection in _on_area_entered, take_damage → queue_free |
| `scripts/carryable_item.gd` | Add goes_to_ship export, conditional carry_destination in _ready |
| `scripts/carry_destination.gd` | Set GlobalRefs.ship, handle SHIP branch in delivery callback |
| `scripts/singletons/GlobalRefs.gd` | Add ship and treasure_count vars |
| `hud.gd` | Wire day timer signal, update treasure count display |

## New Files to Create

| File | Purpose |
|------|---------|
| `scripts/enemy.gd` | Enemy AI: wander, kill pikmin (cooldown), take damage, die → drop |
| `scenes/enemy.tscn` | Enemy prefab with CharacterBody3D, NavigationAgent3D, Area3D (combat zone) |
| `scripts/nectar.gd` | Area3D collectible: on pikmin contact → upgrade_strength, queue_free |
| `scenes/nectar.tscn` | Nectar prefab |
| `scripts/day_timer.gd` | Day countdown, end-of-day logic, signal to HUD |

---

## Implementation Order (suggested)

1. **Day Timer** — isolated, no dependencies, easy win
2. **Pikmin Strength** — self-contained changes to pikmin.gd
3. **Nectar** — depends on Pikmin Strength being in place
4. **Ship Destination** — extends existing carry system cleanly
5. **Enemy** — most complex; depends on Pikmin being able to take damage

---

## Verification

- **Day Timer:** Place timer in level, run game, watch DayProgress bar drain. Let it expire — confirm Pikmin die and main menu loads.
- **Pikmin Strength:** Manually call `pikmin.upgrade_strength()` from the console or a debug key. Confirm speed/damage change. Drop a nectar near Pikmin, confirm auto-pickup advances stage.
- **Enemy:** Place enemy in level. Observe wandering. Throw Pikmin at it — watch health deplete and enemy die, dropping carryable. Walk squad near enemy — confirm only one Pikmin killed per 2 seconds.
- **Ship Delivery:** Set a carryable's `goes_to_ship = true`. Carry it to ship destination. Confirm treasure count increments on HUD.
