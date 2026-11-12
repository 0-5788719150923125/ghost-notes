extends Medium
class_name FullMedium

## FullMedium - one scene, filling the frame: the identity medium.
##
## A real object rather than an `if medium == null` branch: every one of the [Director]'s four vetoes
## returns its argument unchanged here. It draws nothing; scenes are added straight to the stage
## SubViewport and composite themselves.


func host_for(_incoming: GhostScene) -> Node:
	return stage
