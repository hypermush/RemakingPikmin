extends Node3D

var claimed := false
var assigned_pikmin: Node3D = null

func claim(pikmin: Node3D) -> bool:
	if claimed:
		return false
	claimed = true
	assigned_pikmin = pikmin
	return true
