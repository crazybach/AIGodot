class_name LauncherComponent
extends ItemComponent
## Connects an item definition to a row in the weapon configuration table.
## Keeping behavior in the table lets weapons share combat code and reload live.

@export var weapon_config_id: StringName
