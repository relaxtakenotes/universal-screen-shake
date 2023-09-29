local enabled = CreateConVar("cl_screenshake_enabled", "1")
local fov_mult = CreateConVar("cl_screenshake_fov_mult", "1")
local shake_mult = CreateConVar("cl_screenshake_shake_mult", "1")
local default_shake_target = CreateConVar("cl_screenshake_default_shake_target", "2")
local default_fov_push = CreateConVar("cl_screenshake_default_fov_push", "2")
local ignore_weapon_base = CreateConVar("cl_screenshake_ignore_weapon_base", "0")
local hook_compatibility = CreateConVar("cl_screenshake_hook_compatibility", "0")

local frac = 0

local shake_target = 2
local shake = Angle()
local last_shake = Angle()

local fov_push_target = 2
local fov_push = 0
local last_fov_push = 0
local fov_reset = false

local compatible = true

local custom_mult = {}

local previous_ammo = 0
local previous_weapon = NULL

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

local function on_primary_attack(lp, weapon)
	shake_target = default_shake_target:GetFloat()
	fov_push_target = default_fov_push:GetFloat()
	
	local weapon_class = weapon:GetClass()

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
		end
	end

	if math.Rand(0, 1) > 0.7 then
		shake_target = shake_target * -1
	end
	
	if math.Rand(0, 1) > 0.7 then
		fov_push_target = fov_push_target * -1
	end

	local custom_shake = 1
	local custom_fov_push = 1
	if custom_mult[weapon_class] then
		custom_shake = custom_mult[weapon_class][1]
		custom_fov_push = custom_mult[weapon_class][2]
	end

	shake_target = shake_target * shake_mult:GetFloat() * custom_shake
	fov_push_target = fov_push_target * fov_mult:GetFloat() * custom_fov_push

	frac = 1 // the part that actually starts the shake
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
	if not file.Exists("uss_custom_mult.json", "DATA") then
		file.Write("uss_custom_mult.json", "{}") 
	end
	custom_mult = util.JSONToTable(file.Read("uss_custom_mult.json"))
end)

hook.Add("Think", "uss_calculate", function()
	if not enabled:GetBool() then return end
	
	local lp = LocalPlayer()

	calculate_compatibility()

	frac = math.Clamp(frac - FrameTime() / 2, 0, 1)

	shake.z = unclamped_lerp(elastic_quad_ease(frac), 0, shake_target)
	fov_push = unclamped_lerp(elastic_quad_ease(frac), 0, fov_push_target)

	if math.abs(shake.z) < 0.001 and math.abs(fov_push) < 0.001 then
		frac = 0
	end
	
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

hook.Add("CalcView", "uss_apply_alt", function(ply, origin, angles, fov, znear, zfar)
	if USS_CALC then return end
	if not enabled:GetBool() then return end
	if not compatible then return end

	USS_CALC = true
	local base_view = hook.Run("CalcView", ply, pos, angles, fov, znear, zfar)
	pos, angles, fov, znear, zfar = base_view.origin or pos, base_view.angles or angles, base_view.fov or fov, base_view.znear or znear, base_view.zfar or zfar
	USS_CALC = false

	local view = {
		origin = origin,
		angles = angles + shake,
		fov = fov + fov_push
	}

	return view
end)

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