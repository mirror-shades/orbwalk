class_name SatisfiedCustomerDefinition
extends AbilityDefinition
## Numbers for the Potion Seller's passive. The internal cooldown is `cooldown`.
## See docs/champions/potion_seller.md.

## Healing when one of his spells hits an enemy champion: heal + heal_ap_ratio * ability power,
## spread over heal_duration.
@export var heal: float = 40.0
@export var heal_ap_ratio: float = 0.15
@export var heal_duration: float = 3.0


func create_ability() -> Node:
	return load("res://scripts/abilities/potion_seller/satisfied_customer_ability.gd").new()
