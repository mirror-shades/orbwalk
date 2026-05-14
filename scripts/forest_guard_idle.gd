extends Node3D

func _ready():
	$AnimationPlayer.play("Take 001")
	$AnimationPlayer.advance(0)
