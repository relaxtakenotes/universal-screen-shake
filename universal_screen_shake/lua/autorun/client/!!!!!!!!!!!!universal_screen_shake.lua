local enabled = CreateConVar("cl_screenshake_enabled", "1", FCVAR_ARCHIVE)

local ignore_weapon_base = CreateConVar("cl_screenshake_ignore_weapon_base", "0", FCVAR_ARCHIVE)
local hook_compatibility = CreateConVar("cl_screenshake_hook_compatibility", "0", FCVAR_ARCHIVE)

local fov_mult = CreateConVar("cl_screenshake_fov_mult", "1", FCVAR_ARCHIVE)
local shake_mult = CreateConVar("cl_screenshake_shake_mult", "1", FCVAR_ARCHIVE)
local shake_pitch_mult = CreateConVar("cl_screenshake_shake_pitch_mult", "1", FCVAR_ARCHIVE)
local default_shake_target = CreateConVar("cl_screenshake_default_shake_target", "2", FCVAR_ARCHIVE)
local default_fov_push = CreateConVar("cl_screenshake_default_fov_push", "2", FCVAR_ARCHIVE)

local motion_blur_enabled = CreateConVar("cl_screenshake_motion_blur_enabled", "1", FCVAR_ARCHIVE)
local motion_blur_mult = CreateConVar("cl_screenshake_motion_blur_mult", "1", FCVAR_ARCHIVE)

local vm_shake_enabled = CreateConVar("cl_screenshake_viewmodel_shake_enabled", "1", FCVAR_ARCHIVE)
local vm_shake_mult = CreateConVar("cl_screenshake_viewmodel_shake_mult", "1", FCVAR_ARCHIVE)

local move_back_enabled = CreateConVar("cl_screenshake_move_back_enabled", "1", FCVAR_ARCHIVE)
local move_back_mult = CreateConVar("cl_screenshake_move_back_mult", "1", FCVAR_ARCHIVE)

local decay_mult = CreateConVar("cl_screenshake_decay_mult", "0.5", FCVAR_ARCHIVE)

local frac = 0

local flip_shake = 1
local target_flip_shake = 1

local flip_fov = 1
local target_flip_fov = 1

local shake_target = 2
local shake = Angle()
local last_shake = Angle()

local fov_push_target = 2
local fov_push = 0
local last_fov_push = 0
local fov_reset = false

local compatible = true

local custom_mult = {}

if not file.Exists("uss_custom_mult.json", "DATA") then
	file.Write("uss_custom_mult.json", "{}") 
end

custom_mult = util.JSONToTable(file.Read("uss_custom_mult.json"))

local previous_ammo = 0
local previous_weapon = NULL

local move_push = 0
local move_push_c = 0

USS_CALC = false

local function calculate_compatibility()
	local lp = LocalPlayer()

	local current_weapon = nil

	local _weapon = lp:GetActiveWeapon()
	if IsValid(_weapon) and isfunction(_weapon.GetClass) then
		current_weapon = _weapon:GetClass()
	end
	
	if not current_weapon or string.StartsWith(current_weapon, "mg_") then 
		compatible = false 
		return 
	end

	compatible = not hook_compatibility:GetBool()
end

local function elastic_quad_ease(f)
	return math.ease.InElastic(math.ease.InQuad(f))
end

local function unclamped_lerp(t, from, to)
	return from + (to - from) * t
end

concommand.Add("cl_screenshake_set_custom_mult", function(ply, cmd, args, arg_str)
	_usage = "Usage: cl_screenshake_set_custom_mult shake_mult fov_push_mult weapon_class\nIf weapon_class isn't provided, the current weapon is used."
	if not args[1] then
		print(_usage)
		return
	end

	local shake_mult = args[1] or NULL
	local fov_mult = args[2] or NULL
	local weapon_class = args[3] or NULL

	if shake_mult == NULL or fov_mult == NULL then
		print(_usage)
		return
	end

	shake_mult = tonumber(shake_mult)
	fov_mult = tonumber(fov_mult)

	if weapon_class == NULL then
		local weapon = LocalPlayer():GetActiveWeapon()
		if IsValid(weapon) and isfunction(weapon.GetClass) then
			weapon_class = weapon:GetClass()
		end
	end

	custom_mult[weapon_class] = {shake_mult, fov_mult}

	file.Write("uss_custom_mult.json", util.TableToJSON(custom_mult, true)) 

	print(tostring(weapon_class)..": "..tostring(shake_mult)..", "..tostring(fov_mult))
end)

concommand.Add("cl_screenshake_reset_custom_mult", function(ply, cmd, args, arg_str)
	_usage = "Usage: cl_screenshake_reset_custom_mult weapon_class\nIf weapon_class isn't provided, the current weapon is used."
	
	print(_usage)

	local weapon_class = args[1] or NULL

	if weapon_class == NULL then
		local weapon = LocalPlayer():GetActiveWeapon()
		if IsValid(weapon) and isfunction(weapon.GetClass) then
			weapon_class = weapon:GetClass()
		end
	end

	custom_mult[weapon_class] = nil

	file.Write("uss_custom_mult.json", util.TableToJSON(custom_mult, true)) 

	print(weapon_class..": removed")
end)

hook.Add("InitPostEntity", "uss_load_mults", function()
	if not GetConVar("mat_motion_blur_enabled"):GetBool() then
		LocalPlayer():ConCommand("mat_motion_blur_enabled 1")
		LocalPlayer():ConCommand("mat_motion_blur_strength 0")
	end
end)

hook.Add("Think", "uss_calculate", function()
	if not enabled:GetBool() then return end
	
	local lp = LocalPlayer()

	calculate_compatibility()

	frac = math.Clamp(frac - FrameTime() * decay_mult:GetFloat(), 0, 1)

	flip_shake = Lerp(FrameTime() * 60 * decay_mult:GetFloat(), flip_shake, target_flip_shake)
	flip_fov = Lerp(FrameTime() * 60 * decay_mult:GetFloat(), flip_fov, target_flip_fov)

	local f = elastic_quad_ease(frac)

	if compatible then
		shake.x = unclamped_lerp(f, 0, shake_target) * 0.5 * shake_pitch_mult:GetFloat()
	end

	shake.z = unclamped_lerp(f, 0, shake_target) * flip_shake
	fov_push = unclamped_lerp(f, 0, fov_push_target) * flip_fov
	
	if not compatible then
		if frac <= 0 and not fov_reset then
			lp:SetFOV(0, 0.5)
			fov_reset = true
		end

		if frac > 0 then
			fov_reset = false
			lp:SetFOV(lp:GetFOV() + fov_push - last_fov_push)
			last_fov_push = fov_push
		end

		lp:SetEyeAngles(lp:EyeAngles() + shake - last_shake)
		last_shake.z = shake.z
	end

end)

local vm_shake_target = Angle()
local vm_shake = Angle()

hook.Add("CalcViewModelView", "uss_apply_vm", function(weapon, vm, old_pos, old_ang, pos, ang) 
	if not vm_shake_enabled:GetBool() or frac <= 0 then return end

	vm_shake_target = Angle(0, 0, shake.z * -5 * vm_shake_mult:GetFloat())
	vm_shake = LerpAngle(FrameTime() * 10, vm_shake, vm_shake_target)

	ang:Add(vm_shake)
end)

hook.Add("CalcView", "uss_apply_alt", function(ply, origin, angles, fov, znear, zfar)
	if not enabled:GetBool() or not compatible or frac <= 0 then return end

	// My guess is while hooks aren't ordered specifically, they're ordered in memory depending on when they were added
	// We can leverage this and only run calcview hooks that are guaranteed to not run due to us returning from calcview, which (mostly) gets rid of hooks running twice
	local base_view = {}
	local need_to_run = false
	for name, func in pairs(hook.GetTable()["CalcView"]) do
		if name == "uss_apply_alt" then 
			need_to_run = true continue 
		end
		if not need_to_run then 
			continue 
		end
		local ret = func(ply, base_view.origin or origin, base_view.angles or angles, base_view.fov or fov, base_view.znear or znear, base_view.zfar or zfar, base_view.drawviewer or false)
		base_view = ret or base_view
	end

	if base_view then
		origin, angles, fov, znear, zfar, drawviewer = base_view.origin or origin, base_view.angles or angles, base_view.fov or fov, base_view.znear or znear, base_view.zfar or zfar, base_view.drawviewer or false
	end

	local view = {
		origin = origin,
		angles = angles + shake,
		fov = fov + fov_push,
		drawviewer = drawviewer,
		znear = znear,
		zfar = zfar
	}

	return view
end)

local function on_primary_attack(lp, weapon)
	local weapon_class = weapon:GetClass()

	shake_target = default_shake_target:GetFloat()
	fov_push_target = default_fov_push:GetFloat()

	if not ignore_weapon_base:GetBool() then
		if string.StartsWith(weapon_class, "arc9_") and isfunction(weapon.GetProcessedValue) then
			local recoil = (weapon:GetProcessedValue("RecoilUp") + weapon:GetProcessedValue("RecoilSide")) * weapon:GetProcessedValue("Recoil") * 0.75

			shake_target = math.Clamp(recoil * 2, -30, 30)
			fov_push_target = math.Clamp(recoil * 2, -30, 30)
		elseif string.StartsWith(weapon_class, "tfa_") and isfunction(weapon.GetStat) then
			local recoil = (weapon:GetStat("Primary.KickUp") + weapon:GetStat("Primary.KickHorizontal")) * 1.5

			shake_target = math.Clamp(recoil * 2, -30, 30)
			fov_push_target = math.Clamp(recoil * 2, -30, 30)
		elseif string.StartsWith(weapon_class, "mg_") and isfunction(weapon.CalculateRecoil) then
			local _recoil = weapon:CalculateRecoil()
			local recoil = math.abs(_recoil.x) + math.abs(_recoil.y)

			shake_target = math.Clamp(recoil, -30, 30)
			fov_push_target = math.Clamp(recoil, -30, 30)
		elseif string.StartsWith(weapon_class, "arccw_") and weapon.RecoilAmount then
			local recoil = weapon.RecoilAmount * 1.5

			shake_target = math.Clamp(recoil, -30, 30)
			fov_push_target = math.Clamp(recoil, -30, 30)
		elseif string.StartsWith(weapon_class, "tacrp_") and isfunction(weapon.GetRecoilAmount) then
			local recoil = math.Clamp(weapon:GetRecoilAmount() / weapon:GetValue("RecoilMaximum"), 0.3, 1) ^ 1.5

			recoil = math.max(recoil, 0.3)

			shake_target = math.Clamp(recoil * 2, -30, 30)
			fov_push_target = math.Clamp(recoil * 3, -30, 30)			
		end
	end

	if math.Rand(0, 1) > 0.7 then
		target_flip_shake = target_flip_shake * -1
	end
	
	if math.Rand(0, 1) > 0.7 then
		target_flip_fov = target_flip_fov * -1
	end

	local custom_shake = 1
	local custom_fov_push = 1
	if custom_mult[weapon_class] and custom_mult[weapon_class][1] and custom_mult[weapon_class][2] then
		custom_shake = custom_mult[weapon_class][1]
		custom_fov_push = custom_mult[weapon_class][2]
	end

	shake_target = shake_target * shake_mult:GetFloat() * custom_shake
	fov_push_target = fov_push_target * fov_mult:GetFloat() * custom_fov_push

	move_push_c = move_push_c + 1

	frac = 1 // the part that actually starts the shake
end

hook.Add("Think", "uss_detect_fire", function()
	if not enabled:GetBool() then return end
	// We could very well use entityfirebullets in this one and do all the magic bullet sorting like in DWRV3 so we don't get more than 1 shot in 1-2 frames.
	// But I feel like it's too expensive for such a simple task.
	local lp = LocalPlayer()

	if not lp:Alive() then return end

	local weapon = lp:GetActiveWeapon()

	if not weapon then return end
	if not isfunction(weapon.Clip1) then return end

	local current_ammo = weapon:Clip1()
	if (previous_ammo - current_ammo < 2 or current_ammo != 0) and current_ammo < previous_ammo and not (weapon != previous_weapon) then
		on_primary_attack(lp, weapon)
	end
	
	previous_ammo = current_ammo
	previous_weapon = weapon
end)

hook.Add("CreateMove", "uss_recoil_move", function(cmd) 
	if not enabled:GetBool() or not move_back_enabled:GetBool() or LocalPlayer():GetMoveType() != MOVETYPE_WALK then return end

	if frac <= 0.5 then
		move_push_c = 0
	end
	
	if frac <= 0 then return end

	local f = math.ease.InOutQuad(frac * 0.5)
	local resist = (move_push_c ^ 3) * (math.abs(fov_push) + math.abs(shake.z)) * FrameTime() * 5 / 20
	local recoil = LocalPlayer():GetRunSpeed() * f * math.sqrt(math.abs(fov_push) + math.abs(shake.z)) * FrameTime() * 10
	resist = math.min(recoil, resist)
	local total = (recoil - resist) * move_back_mult:GetFloat()

	cmd:SetForwardMove(cmd:GetForwardMove() - total)
end)

hook.Add("GetMotionBlurValues", "uss_motion_blur", function( x, y, w, z)
	if not enabled:GetBool() or not motion_blur_enabled:GetBool() or frac <= 0 then return end

	w = math.abs(-fov_push / 80 * motion_blur_mult:GetFloat())

	return x, y, w, z
end)

hook.Add("PopulateToolMenu", "uss_settings_populate", function()
    spawnmenu.AddToolMenuOption("Options", "uss_tool", "uss_main_options", "Settings", nil, nil, function(panel)
        panel:ClearControls()

		panel:CheckBox("Enabled", enabled:GetName())
		panel:CheckBox("Motion Blur", motion_blur_enabled:GetName())
		panel:CheckBox("Viewmodel Shake", vm_shake_enabled:GetName())
		panel:CheckBox("Recoil Move", move_back_enabled:GetName())
		panel:CheckBox("Ignore Weapon Recoil", ignore_weapon_base:GetName())
		panel:CheckBox("Force compatibility mode", hook_compatibility:GetName())

		panel:ControlHelp("")
		
		panel:NumSlider("Default Shake Value", default_shake_target:GetName(), -30, 30, 1)
		panel:NumSlider("Default Fov Push Value", default_fov_push:GetName(), -10, 10, 1)

		panel:ControlHelp("")

		panel:NumSlider("Fov Push Multiplier", fov_mult:GetName(), 0, 10, 2)
		panel:NumSlider("Shake Multiplier", shake_mult:GetName(), 0, 10, 2)
		panel:NumSlider("Pitch Shake Multiplier", shake_pitch_mult:GetName(), 0, 10, 2)
		panel:NumSlider("Motion Blur Multiplier", motion_blur_mult:GetName(), 0, 10, 2)
		panel:NumSlider("Viewmodel Shake Multiplier", vm_shake_mult:GetName(), 0, 10, 2)
		panel:NumSlider("Recoil Move Multiplier", move_back_mult:GetName(), 0, 10, 2)
		panel:NumSlider("Decay Time Multiplier", decay_mult:GetName(), 0, 10, 2)
    end)
end)

hook.Add("AddToolMenuCategories", "uss_add_category", function() 
    spawnmenu.AddToolCategory("Options", "uss_tool", "Screen Shake")
end)