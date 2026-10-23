class_name ScopeAugmentEffect
extends AugmentEffect

func max_drag_multiplier() -> float:
	return float(definition.values.get("max_impulse_multiplier", 1.3))

func guide_multiplier() -> float:
	return float(definition.values.get("guide_multiplier", 1.5))
