/obj/item/mod/module
	name = "MOD module"
	icon = 'icons/obj/clothing/modsuit/mod_modules.dmi'
	icon_state = "module"
	/// If it can be removed
	var/removable = TRUE
	/// If it's passive, togglable, usable or active
	var/module_type = MODULE_PASSIVE
	/// Is the module active
	var/active = FALSE
	/// How much space it takes up in the MOD
	var/complexity = 0
	/// Power use when idle
	var/idle_power_cost = DEFAULT_CHARGE_DRAIN * 0
	/// Power use when active
	var/active_power_cost = DEFAULT_CHARGE_DRAIN * 0
	/// Power use when used, we call it manually
	var/use_power_cost = DEFAULT_CHARGE_DRAIN * 0
	/// ID used by their TGUI
	var/tgui_id
	/// Linked MODsuit
	var/obj/item/mod/control/mod
	/// If we're an active module, what item are we?
	var/obj/item/device
	/// Overlay given to the user when the module is inactive
	var/overlay_state_inactive
	/// Overlay given to the user when the module is active
	var/overlay_state_active
	/// Overlay given to the user when the module is used, lasts until cooldown finishes
	var/overlay_state_use
	/// Icon file for the overlay.
	var/overlay_icon_file = 'icons/mob/clothing/modsuit/mod_modules.dmi'
	/// Does the overlay use the control unit's colors?
	var/use_mod_colors = FALSE
	/// What modules are we incompatible with?
	var/list/incompatible_modules = list()
	/// Cooldown after use
	var/cooldown_time = 0
	/// The mouse button needed to use this module
	var/used_signal
	/// If we're allowed to use this module while phased out.
	var/allowed_in_phaseout = FALSE
	/// If we're allowed to use this module while the suit is disabled.
	var/allowed_inactive = FALSE
	/// Timer for the cooldown
	COOLDOWN_DECLARE(cooldown_timer)
	/// BLUEMOON ADD Bitflag for exosuit fabricator sub-categories
	var/mod_module_flags

/obj/item/mod/module/Initialize(mapload)
	. = ..()
	if(module_type != MODULE_ACTIVE)
		return
	if(ispath(device))
		device = new device(src)
		ADD_TRAIT(device, TRAIT_NODROP, MOD_TRAIT)
		RegisterSignal(device, COMSIG_PARENT_PREQDELETED, PROC_REF(on_device_deletion))
		RegisterSignal(src, COMSIG_ATOM_EXITED, PROC_REF(on_exit))

/obj/item/mod/module/Destroy()
	mod?.uninstall(src)
	if(device)
		UnregisterSignal(device, COMSIG_PARENT_PREQDELETED)
		QDEL_NULL(device)
	return ..()

/obj/item/mod/module/examine(mob/user)
	. = ..()
	if(user.hud_list[DIAG_HUD] && user.client.images & user.hud_list[DIAG_HUD])
		. += span_notice("Complexity level: [complexity]")

/// Called from MODsuit's install() proc, so when the module is installed.
/obj/item/mod/module/proc/on_install()
	return

/// Called from MODsuit's uninstall() proc, so when the module is uninstalled.
/obj/item/mod/module/proc/on_uninstall()
	return

/// Called when the MODsuit is activated
/obj/item/mod/module/proc/on_suit_activation()
	return

/// Called when the MODsuit is deactivated
/obj/item/mod/module/proc/on_suit_deactivation()
	return

/// Called when the MODsuit is equipped
/obj/item/mod/module/proc/on_equip()
	return

/// Called when the MODsuit is unequipped
/obj/item/mod/module/proc/on_unequip()
	return

/// Called when the module is selected from the TGUI
/obj/item/mod/module/proc/on_select()
	if(((!mod.active || mod.activating) && !allowed_inactive) || module_type == MODULE_PASSIVE)
		if(mod.wearer)
			balloon_alert(mod.wearer, "not active!")
		return
	if(module_type != MODULE_USABLE)
		if(active)
			on_deactivation()
		else
			on_activation()
	else
		on_use()
	SEND_SIGNAL(mod, COMSIG_MOD_MODULE_SELECTED, src)

/// Called when the module is activated
/obj/item/mod/module/proc/on_activation()
	if(!COOLDOWN_FINISHED(src, cooldown_timer))
		balloon_alert(mod.wearer, "on cooldown!")
		return FALSE
	if(!mod.active || mod.activating || !mod.cell?.charge)
		balloon_alert(mod.wearer, "unpowered!")
		return FALSE
	if(!allowed_in_phaseout && istype(mod.wearer.loc, /obj/effect/dummy/phased_mob))
		//specifically a to_chat because the user is phased out.
		to_chat(mod.wearer, span_warning("You cannot activate this right now."))
		return FALSE
	if(module_type == MODULE_ACTIVE)
		if(mod.selected_module && !mod.selected_module.on_deactivation())
			return
		mod.selected_module = src
		if(device)
			if(mod.wearer.put_in_hands(device))
				balloon_alert(mod.wearer, "[device] extended")
				RegisterSignal(mod.wearer, COMSIG_ATOM_EXITED, PROC_REF(on_exit))
			else
				balloon_alert(mod.wearer, "can't extend [device]!")
				return
		else
			update_signal()
			balloon_alert(mod.wearer, "[src] activated, alt-click to use")
	active = TRUE
	mod.wearer.update_inv_back()
	return TRUE

/// Called when the module is deactivated
/obj/item/mod/module/proc/on_deactivation()
	active = FALSE
	if(module_type == MODULE_ACTIVE)
		mod.selected_module = null
		if(device)
			mod.wearer.transferItemToLoc(device, src, TRUE)
			balloon_alert(mod.wearer, "[device] retracted")
			UnregisterSignal(mod.wearer, COMSIG_ATOM_EXITED)
		else
			balloon_alert(mod.wearer, "[src] deactivated")
			UnregisterSignal(mod.wearer, used_signal)
			used_signal = null
	mod.wearer.update_inv_back()
	return TRUE

/// Called when the module is used
/obj/item/mod/module/proc/on_use()
	if(!COOLDOWN_FINISHED(src, cooldown_timer))
		return FALSE
	if(!check_power(use_power_cost))
		return FALSE
	if(!allowed_in_phaseout && istype(mod.wearer.loc, /obj/effect/dummy/phased_mob))
		//specifically a to_chat because the user is phased out.
		to_chat(mod.wearer, span_warning("You cannot activate this right now."))
		return FALSE
	COOLDOWN_START(src, cooldown_timer, cooldown_time)
	addtimer(CALLBACK(mod.wearer, TYPE_PROC_REF(/mob, update_inv_back)), cooldown_time)
	mod.wearer.update_inv_back()
	return TRUE

/// Called when an activated module without a device is used
/obj/item/mod/module/proc/on_select_use(atom/target)
	if(mod.wearer.incapacitated(ignore_grab = TRUE))
		return FALSE
	mod.wearer.face_atom(target)
	if(!on_use())
		return FALSE
	return TRUE

/// Called when an activated module without a device is active and the user alt/middle-clicks
/obj/item/mod/module/proc/on_special_click(mob/source, atom/target)
	SIGNAL_HANDLER
	on_select_use(target)
	return COMSIG_MOB_CANCEL_CLICKON

/// Called on the MODsuit's process
/obj/item/mod/module/proc/on_process(delta_time)
	if(active)
		if(!drain_power(active_power_cost * delta_time))
			on_deactivation()
			return FALSE
		on_active_process(delta_time)
	else
		drain_power(idle_power_cost * delta_time)
	return TRUE

/// Called on the MODsuit's process if it is an active module
/obj/item/mod/module/proc/on_active_process(delta_time)
	return

/// Drains power from the suit cell
/obj/item/mod/module/proc/drain_power(amount)
	if(!check_power(amount))
		return FALSE
	mod.cell.charge = max(0, mod.cell.charge - amount)
	return TRUE

/obj/item/mod/module/proc/check_power(amount)
	if(!mod.cell || (mod.cell.charge < amount))
		return FALSE
	return TRUE

/// Adds additional things to the MODsuit ui_data()
/obj/item/mod/module/proc/add_ui_data()
	return list()

/// Creates a list of configuring options for this module
/obj/item/mod/module/proc/get_configuration()
	return list()

/// Generates an element of the get_configuration list with a display name, type and value
/obj/item/mod/module/proc/add_ui_configuration(display_name, type, value, list/values)
	return list("display_name" = display_name, "type" = type, "value" = value, "values" = values)

/// Receives configure edits from the TGUI and edits the vars
/obj/item/mod/module/proc/configure_edit(key, value)
	return

/// Called when the device moves to a different place on active modules
/obj/item/mod/module/proc/on_exit(datum/source, atom/movable/part, direction)
	SIGNAL_HANDLER

	if(!active)
		return
	if(part.loc == src)
		return
	if(part.loc == mod.wearer)
		return
	if(part == device)
		on_deactivation()

/// Called when the device gets deleted on active modules
/obj/item/mod/module/proc/on_device_deletion(datum/source)
	SIGNAL_HANDLER

	if(source == device)
		device = null
		qdel(src)

/// Generates an icon to be used for the suit's worn overlays
/obj/item/mod/module/proc/generate_worn_overlay()
	. = list()
	if(!mod.active)
		return
	var/used_overlay
	if(overlay_state_use && !COOLDOWN_FINISHED(src, cooldown_timer))
		used_overlay = overlay_state_use
	else if(overlay_state_active && active)
		used_overlay = overlay_state_active
	else if(overlay_state_inactive)
		used_overlay = overlay_state_inactive
	else
		return
	var/mutable_appearance/module_icon = mutable_appearance(overlay_icon_file, used_overlay)
	if(!use_mod_colors)
		module_icon.appearance_flags |= RESET_COLOR
	. += module_icon

/// Updates the signal used by active modules to be activated
/obj/item/mod/module/proc/update_signal()
	mod.selected_module.used_signal = COMSIG_MOB_ALTCLICKON
	RegisterSignal(mod.wearer, mod.selected_module.used_signal, TYPE_PROC_REF(/obj/item/mod/module, on_special_click))

/obj/item/mod/module/anomaly_locked
	name = "MOD anomaly locked module"
	desc = "A form of a module, locked behind an anomalous core to function."
	incompatible_modules = list(/obj/item/mod/module/anomaly_locked)
	/// The core item the module runs off.
	var/obj/item/assembly/signaler/anomaly/core
	/// Accepted types of anomaly cores.
	var/list/accepted_anomalies = list(/obj/item/assembly/signaler/anomaly)
	/// If this one starts with a core in.
	var/prebuilt = FALSE

/obj/item/mod/module/anomaly_locked/Initialize(mapload)
	. = ..()
	if(!prebuilt || !length(accepted_anomalies))
		return
	var/core_path = pick(accepted_anomalies)
	core = new core_path(src)
	update_icon_state()

/obj/item/mod/module/anomaly_locked/Destroy()
	QDEL_NULL(core)
	return ..()

/obj/item/mod/module/anomaly_locked/examine(mob/user)
	. = ..()
	if(!length(accepted_anomalies))
		return
	if(core)
		. += span_notice("There is a [core.name] installed in it. You could remove it with a <b>screwdriver</b>...")
	else
		var/list/core_list = list()
		for(var/path in accepted_anomalies)
			var/atom/core_path = path
			core_list += initial(core_path.name)
		. += span_notice("You need to insert \a [english_list(core_list, and_text = " or ")] for this module to function.")

/obj/item/mod/module/anomaly_locked/on_select()
	if(!core)
		balloon_alert(mod.wearer, "no core!")
		return
	return ..()

/obj/item/mod/module/anomaly_locked/on_process(delta_time)
	. = ..()
	if(!core)
		return FALSE

/obj/item/mod/module/anomaly_locked/on_active_process(delta_time)
	if(!core)
		return FALSE
	return TRUE

/obj/item/mod/module/anomaly_locked/attackby(obj/item/item, mob/living/user, params)
	if(item.type in accepted_anomalies)
		if(core)
			balloon_alert(user, "core already in!")
			return
		if(!user.transferItemToLoc(item, src))
			return
		core = item
		balloon_alert(user, "core installed")
		playsound(src, 'sound/machines/click.ogg', 30, TRUE)
		update_icon_state()
	else
		return ..()

/obj/item/mod/module/anomaly_locked/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	if(!core)
		balloon_alert(user, "no core!")
		return
	balloon_alert(user, "removing core...")
	if(!do_after(user, 3 SECONDS, target = src))
		balloon_alert(user, "interrupted!")
		return
	balloon_alert(user, "core removed")
	core.forceMove(drop_location())
	if(Adjacent(user) && !issilicon(user))
		user.put_in_hands(core)
	core = null
	update_icon_state()

/obj/item/mod/module/anomaly_locked/update_icon_state()
	icon_state = initial(icon_state) + (core ? "-core" : "")
	return ..()
