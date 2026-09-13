extends Node

# Sky3D builds its own SkyDome child in code, after this node's _ready(), so
# a couple of knobs that aren't exposed as top-level Sky3D properties (and
# can't just be set as static values in the .tscn) get poked here once it
# exists.
@export var sky3d_path: NodePath

func _ready() -> void:
	await get_tree().process_frame
	var sky3d: Node = get_node_or_null(sky3d_path)
	if sky3d == null:
		return
	# Looked up by underwater_effect.gd to drive real distance fog while
	# submerged - simpler and more robust than every player instance needing
	# its own path back to whichever scene's Sky3D node.
	sky3d.add_to_group("sky3d")

	var dome = sky3d.get("sky")
	if dome == null:
		return

	# The addon's default moon is a large, strongly-shadowed sphere - fine
	# for a AAA-style hero shot, but here (esp. opposite the sun, near a
	# gibbous phase) it reads as an unexplained dark ball hanging in the sky
	# rather than an obviously-a-moon. Halved so it's still clearly visible
	# but no longer dominates the frame.
	dome.moon_size = 0.035

	# A dense, strongly self-shadowed cumulus mass (high absorption + high
	# coverage) renders with only 10 raymarch steps and can look like a
	# faceted, hard-edged blob instead of a soft cloud, especially low on the
	# horizon at sunset - toned down as a secondary precaution.
	dome.cumulus_coverage = 0.35
	dome.cumulus_absorption = 1.0
	dome.cumulus_thickness = 0.018

	# The bright halo around the sun ("circumsolar glow") is real forward Mie
	# scattering - it's SUPPOSED to grow the more directly you look toward
	# the sun and shrink as you turn away, that's not a bug, but the addon's
	# default anisotropy/intensity makes it a strong, hard-edged bright spot
	# instead of a soft glow, which read as "some weird circle in the sky".
	# Softened so the same effect is there but far more subtle.
	sky3d.auto_exposure = false
	dome.atm_sun_mie_intensity = 0.5
	dome.atm_sun_mie_anisotropy = 0.6
	dome.atm_moon_mie_intensity = 0.35
