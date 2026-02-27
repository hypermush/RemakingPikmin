extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Pikmin") and body.strength < body.Strength.FLOWER:
		body.upgrade_strength()
		queue_free()
