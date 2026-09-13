class_name Creature
extends CharacterBody2D
## Shared base class for Player and Enemy.
##
## Thin orchestrator with a stable public API (facade):
##   - take_damage(amount)   → delegates to HealthComponent
##   - die()                 → is_alive = false, emit died, call _on_death()
##   - build_collision(r)    → shared circle-collision factory
##   - build_sprite(tex)     → shared sprite factory
##
## Subclasses override _setup_creature() to add components via
## _add_component() and build visuals. The Creature calls
## component._physics_tick(delta) each frame.
##
## External callers (Bullet, HUD, GameManager) only need to know
## Creature — never the individual components.

signal died(creature: Creature)
signal health_changed(current: float, maximum: float)
signal ammo_changed(current: int, maximum: int)

var is_alive := true
var facing_angle := 0.0

## ── Typed component cache ───────────────────────────────────────
var health_comp: HealthComponent
var combat_comp: CombatComponent
var movement_comp: MovementComponent
var inventory_comp: InventoryComponent
var equipment_comp: EquipmentComponent
var damage_resistances: Dictionary = {} # damage type -> fraction resisted [0, 1]

var _components: Array[Component] = []


func _ready() -> void:
	add_to_group(&"damage_receivers")
	_setup_creature()
	_relay_signals()


## ── Subclass overrides ─────────────────────────────────────────

## Override in subclass: add components via _add_component(),
## build sprites, set z_index, etc. Capture typed refs from return
## values of _add_component().
func _setup_creature() -> void:
	pass


## Override in subclass: entity-specific death behavior.
## Always call super._on_death() to disable physics.
func _on_death() -> void:
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	visible = false


## ── Component management ───────────────────────────────────────

func _add_component(comp: Component) -> Component:
	comp.creature = self
	add_child(comp)
	_components.append(comp)
	return comp


func _relay_signals() -> void:
	if health_comp:
		health_comp.health_changed.connect(_relay_health_changed)
	if combat_comp:
		combat_comp.ammo_changed.connect(_relay_ammo_changed)


func _relay_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)


func _relay_ammo_changed(current: int, maximum: int) -> void:
	ammo_changed.emit(current, maximum)


## ── Physics tick ───────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	for comp in _components:
		comp._physics_tick(delta)


## ── Facade — stable API for external callers ──────────────────

func take_damage(amount: float) -> void:
	if health_comp and is_alive:
		health_comp.take_damage(amount)


func heal(amount: float) -> void:
	if health_comp:
		health_comp.heal(amount)


func receive_damage(amount: float, damage_type: StringName = &"kinetic") -> void:
	var resolved := maxf(0.0, amount) * (1.0 - clampf(float(damage_resistances.get(damage_type, 0.0)), 0.0, 1.0))
	if resolved <= 0.0:
		return
	if damage_type in [&"kinetic", &"explosion"]:
		take_damage(resolved)
	elif health_comp and is_alive:
		health_comp.take_damage(resolved)


## Override in subclass — sets where damage flash is applied.
## Player: self.modulate. Enemy: enemy_sprite.modulate.
func apply_flash(color: Color) -> void:
	modulate = color

func reset_flash() -> void:
	if is_alive:
		modulate = Color.WHITE


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	died.emit(self)
	_on_death()


## ── Shared builders ────────────────────────────────────────────

func build_collision(radius: float, cname := "BodyCollision") -> void:
	var collision := CollisionShape2D.new()
	collision.name = cname
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)


func build_sprite(tex: Texture2D = null, sname := "Sprite") -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sname
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tex:
		sprite.texture = tex
	add_child(sprite)
	return sprite
