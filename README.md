# universal-screen-shake
 Universal screen shake in GMOD

This will either make you vomit or make you awe at how cool your firefights have become. This just shakes the screen in cool ways with any weapon that you have.

It tries to adjust the shake using recoil values from more popular weapon bases, but it allows for custom configuration also.

Commands: 
- cl_screenshake_enabled - enables the darn thing
- cl_screenshake_fov_mult - multiplier for the fov push
- cl_screenshake_shake_mult - multiplier for the tilt shake
- cl_screenshake_default_shake_target - default value for the tilt shake if we were unable to get the weapons recoil
- cl_screenshake_default_fov_push - default value for the fov push if we were unable to get the weapons recoil
- cl_screenshake_ignore_weapon_base - ignores weapons parameters and uses the default values
- cl_screenshake_hook_compatibility - in case shit breaks and the mod hadn't adjusted for it, enable or disable this.
- cl_screenshake_set_custom_mult - Usage: cl_screenshake_set_custom_mult shake_mult fov_push_mult weapon_class. If weapon_class isn't provided, the current weapon is used.
- cl_screenshake_reset_custom_mult - Usage: cl_screenshake_set_custom_mult weapon_class. If weapon_class isn't provided, the current weapon is used.
- cl_screenshake_viewmodel_shake_mult - Multiplier for how much the viewmodel should shake.
