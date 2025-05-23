/obj/item/clothing/accessory //Ties moved to neck slot items, but as there are still things like medals and armbands, this accessory system is being kept as-is
	name = "Accessory"
	desc = "Something has gone wrong!"
	icon = 'icons/obj/clothing/accessories.dmi'
	//skyrat edit
	mob_overlay_icon = 'icons/mob/clothing/accessories.dmi'
	//
	icon_state = "plasma"
	item_state = ""	//no inhands
	slot_flags = ITEM_SLOT_ACCESSORY
	slot_equipment_priority = list(ITEM_SLOT_ACCESSORY)
	w_class = WEIGHT_CLASS_SMALL
	var/above_suit = FALSE
	var/minimize_when_attached = TRUE // TRUE if shown as a small icon in corner, FALSE if overlayed
	var/datum/component/storage/detached_pockets
	//skyrat edit
	var/current_uniform = null
	// BLUEMOON ADD START - изменение аксессуаров
	// У некоторых акссессуаров теперь типо будет доступ. Костыль, да.
	var/list/access = list()
	// Для всех боевых аксессуаров, которые не должны стакать свои бонусы с кучей других боевых аксессуаров.
	// Количество возможных боевых акссессуаров зависит от джампсьюта на персонаже, по умолчанию 3.
	var/restricted_accessory = FALSE
	// Максимальное количество аксессуаров этого вида, которые можно прицепить к джампсьюту. -1 означает отсутствие лимита.
	var/max_stack = -1
	// Родительский класс, все дочерние классы которого не могут стакаться друг с другом без ограничений
	var/max_stack_path = null
	// BLUEMOON ADD END

/obj/item/clothing/accessory/proc/attach(obj/item/clothing/under/U, user)
	var/datum/component/storage/storage = GetComponent(/datum/component/storage)
	if(storage)
		if(SEND_SIGNAL(U, COMSIG_CONTAINS_STORAGE))
			return FALSE
		U.TakeComponent(storage)
		detached_pockets = storage
	//SKYRAT EDIT
	U.attached_accessories |= src
	force_unto(U)
	current_uniform = U
	//SKYRAT EDIT END
	forceMove(U)

	layer = NECK_LAYER
	plane = FLOAT_PLANE

	if (islist(U.armor) || isnull(U.armor)) 										// This proc can run before /obj/Initialize has run for U and src,
		U.armor = getArmor(arglist(U.armor))	// we have to check that the armor list has been transformed into a datum before we try to call a proc on it
																					// This is safe to do as /obj/Initialize only handles setting up the datum if actually needed.
	if (islist(armor) || isnull(armor))
		armor = getArmor(arglist(armor))

	U.armor = U.armor.attachArmor(armor)

	if(isliving(user))
		on_uniform_equip(U, user)

	return TRUE

/obj/item/clothing/accessory/proc/detach(obj/item/clothing/under/U, user)
	if(detached_pockets && detached_pockets.parent == U)
		TakeComponent(detached_pockets)

	if(U.armor && armor)
		U.armor = U.armor.detachArmor(armor)
	//SANDSTORM EDIT
	current_uniform = null
	//SANDSTORM EDIT END

	if(isliving(user))
		on_uniform_dropped(U, user)

	if(minimize_when_attached)
		transform *= 2
		pixel_x = 0
		pixel_y = 0
	layer = initial(layer)
	plane = initial(plane)
	U.cut_overlays()
	U.attached_accessories -= src
	U.accessory_overlays = list()
	if(length(U.attached_accessories))
		U.accessory_overlays = list(mutable_appearance('icons/mob/clothing/accessories.dmi', "blank"))
		for(var/obj/item/clothing/accessory/attached_accessory in U.attached_accessories)
			attached_accessory.force_unto(U)
			var/datum/element/polychromic/polychromic = LAZYACCESS(attached_accessory.comp_lookup, "item_worn_overlays")
			if(!polychromic)
				var/mutable_appearance/accessory_overlay = mutable_appearance(attached_accessory.mob_overlay_icon, attached_accessory.item_state || attached_accessory.icon_state, -UNIFORM_LAYER)
				accessory_overlay.alpha = attached_accessory.alpha
				accessory_overlay.color = attached_accessory.color
				U.accessory_overlays += accessory_overlay
			else
				polychromic.apply_worn_overlays(attached_accessory, FALSE, attached_accessory.mob_overlay_icon, attached_accessory.item_state || attached_accessory.icon_state, NONE, U.accessory_overlays)

//SANDSTORM EDIT
/obj/item/clothing/accessory/proc/force_unto(obj/item/clothing/under/U)
	layer = FLOAT_LAYER
	plane = FLOAT_PLANE
	if(minimize_when_attached)
		if(current_uniform != U)
			transform *= 0.5	//halve the size so it doesn't overpower the under
			pixel_x += 8
			pixel_y -= 8
		if(length(U.attached_accessories) > 1)
			if(length(U.attached_accessories) <= 3 && !current_uniform)
				pixel_y += 8 * (length(U.attached_accessories) - 1)
			else if((length(U.attached_accessories) > 3) && (length(U.attached_accessories) <= 6) && !current_uniform)
				pixel_x -= 8
				pixel_y += 8 * (length(U.attached_accessories) - 4)
			else if((length(U.attached_accessories) > 6) && (length(U.attached_accessories) <= 9) && !current_uniform)
				pixel_x -= 16
				pixel_y += 8 * (length(U.attached_accessories) - 7)
			else
				if(current_uniform != U)
					//we ran out of space for accessories, so we just throw shit at the wall
					pixel_x = 0
					pixel_y = 0
					pixel_x += rand(-16, 16)
					pixel_y += rand(-16, 16)
	U.add_overlay(src)
//SANDSTORM EDIT END

/obj/item/clothing/accessory/proc/on_uniform_equip(obj/item/clothing/under/U, user)
	return

/obj/item/clothing/accessory/proc/on_uniform_dropped(obj/item/clothing/under/U, user)
	return

/obj/item/clothing/accessory/CtrlClick(mob/user)
	. = ..()
	if(istype(user) && user.canUseTopic(src, BE_CLOSE, ismonkey(user)))
		if(initial(above_suit))
			above_suit = !above_suit
			to_chat(user, "[src] will be worn [above_suit ? "above" : "below"] your suit.")
			return TRUE

/obj/item/clothing/accessory/examine(mob/user)
	. = ..()
	. += "<span class='notice'>\The [src] can be attached to [istype(src, /obj/item/clothing/accessory/ring) ? "gloves" : "a uniform"]. Alt-click to remove it once attached.</span>"
	if(initial(above_suit))
		. += "<span class='notice'>\The [src] can be worn above or below your suit. Ctrl-click to toggle.</span>"

//////////////
//Waistcoats//
//////////////

/obj/item/clothing/accessory/waistcoat
	name = "black waistcoat"
	desc = "For some classy, murderous fun."
	icon_state = "waistcoat"
	item_state = "waistcoat"
	minimize_when_attached = FALSE

/obj/item/clothing/accessory/waistcoat/red
	name = "red waistcoat"
	icon_state = "waistcoat_red"
	item_state = "waistcoat_red"

/obj/item/clothing/accessory/waistcoat/grey
	name = "grey waistcoat"
	icon_state = "waistcoat_grey"
	item_state = "waistcoat_grey"

/obj/item/clothing/accessory/waistcoat/brown
	name = "red waistcoat"
	icon_state = "waistcoat_brown"
	item_state = "waistcoat_brown"

/obj/item/clothing/accessory/waistcoat/sweatervest
	name = "black sweatervest"
	icon_state = "sweatervest"
	item_state = "sweatervest"

/obj/item/clothing/accessory/waistcoat/sweatervest/blue
	name = "blue sweatervest"
	icon_state = "sweatervest_blue"
	item_state = "sweatervest_blue"

/obj/item/clothing/accessory/waistcoat/sweatervest/red
	name = "red sweatervest"
	icon_state = "sweatervest_red"
	item_state = "sweatervest_red"

////////////
//Sweaters//
////////////

/obj/item/clothing/accessory/sweater
	name = "grey sweater"
	desc = "Nicely comfy and warm!"
	icon_state = "sweater"
	item_state = "sweater"
	minimize_when_attached = FALSE

/obj/item/clothing/accessory/sweater/pink
	name = "pink sweater"
	icon_state = "sweater_pink"
	item_state = "sweater_pink"

/obj/item/clothing/accessory/sweater/heart
	name = "heart sweater"
	icon_state = "sweater_heart"
	item_state = "sweater_heart"

/obj/item/clothing/accessory/sweater/blue
	name = "blue sweater"
	icon_state = "sweater_blue"
	item_state = "sweater_blue"

/obj/item/clothing/accessory/sweater/nt
	name = "nanotrasen sweater"
	icon_state = "sweater_nt"
	item_state = "sweater_nt"

/obj/item/clothing/accessory/sweater/mint
	name = "mint sweater"
	icon_state = "sweater_mint"
	item_state = "sweater_mint"

/obj/item/clothing/accessory/sweater/shoulderless
	name = "shoulderless sweater"
	icon_state = "sweater_shoulderless"
	item_state = "sweater_shoulderless"

/obj/item/clothing/accessory/sweater/uglyxmas
	name = "ugly xmas sweater"
	icon_state = "sweater_uglyxmas"
	item_state = "sweater_uglyxmas"

/obj/item/clothing/accessory/sweater/flower
	name = "flower sweater"
	icon_state = "sweater_flower"
	item_state = "sweater_flower"

////////////////
//Suit Jackets//
////////////////

/obj/item/clothing/accessory/suitjacket
	name = "tan suit jacket"
	desc = "For those times when you have to attend a fancy business meeting without wearing your pants."
	icon_state = "jacket_tan"
	item_state = "jacket_tan"
	minimize_when_attached = FALSE

/obj/item/clothing/accessory/suitjacket/charcoal
	name = "charcoal suit jacket"
	icon_state = "jacket_charcoal"
	item_state = "jacket_charcoal"

/obj/item/clothing/accessory/suitjacket/navy
	name = "navy suit jacket"
	icon_state = "jacket_navy"
	item_state = "jacket_navy"

/obj/item/clothing/accessory/suitjacket/burgundy
	name = "burgundy suit jacket"
	icon_state = "jacket_burgundy"
	item_state = "jacket_burgundy"

/obj/item/clothing/accessory/suitjacket/checkered
	name = "checkered suit jacket"
	icon_state = "jacket_checkered"
	item_state = "jacket_checkered"

///////////////////////
//Tactical Turtlnecks//
///////////////////////

/obj/item/clothing/accessory/turtleneck
	name = "black turtleneck"
	desc = "Extra cool. Extra fool."
	icon_state = "turtleneck"
	item_state = "turtleneck"
	minimize_when_attached = FALSE

/obj/item/clothing/accessory/turtleneck/red
	name = "red turtleneck"
	icon_state = "turtleneck_red"
	item_state = "turtleneck_red"

/obj/item/clothing/accessory/turtleneck/comfy
	name = "comfy turtleneck"
	icon_state = "turtleneck_comfy"
	item_state = "turtleneck_comfy"

/obj/item/clothing/accessory/turtleneck/tactifool
	name = "black sweaterneck"
	desc = "Extra fool. Extra cool."
	icon_state = "tactifool"
	item_state = "tactifool"

/obj/item/clothing/accessory/turtleneck/tactifool/green
	name = "green sweaterneck"
	icon_state = "tactifool_green"
	item_state = "tactifool_green"

/obj/item/clothing/accessory/turtleneck/tactifool/blue
	name = "blue sweaterneck"
	icon_state = "tactifool_blue"
	item_state = "tactifool_blue"

/obj/item/clothing/accessory/turtleneck/tactifool/syndicate
	name = "tactifool sweaterneck"
	icon_state = "tactifool_syndicate"
	item_state = "tactifool_syndicate"

/////////////////
//Miscellaneous//
/////////////////

/obj/item/clothing/accessory/maidapron
	name = "maid apron"
	desc = "The best part of a maid costume."
	icon_state = "maidapron"
	item_state = "maidapron"
	minimize_when_attached = FALSE

/obj/item/clothing/accessory/maidapron/polychromic
	name = "polychromic maid apron"
	icon_state = "polymaidapron"
	item_state = "polymaidapron"

/obj/item/clothing/accessory/maidapron/polychromic/ComponentInitialize()
	. = ..()
	AddElement(/datum/element/polychromic, list("#333333", "#FFFFFF"), 2)

/obj/item/clothing/accessory/sleevecrop
	name = "one sleeved crop top"
	desc = "Off the shoulder crop top, for those nights out partying."
	icon_state = "sleevecrop"
	item_state = "sleevecrop"
	minimize_when_attached = FALSE

//////////
//Medals//
//////////

#define MARINE_CONDUCT_MEDAL "Distinguished Conduct Medal"
#define MARINE_BRONZE_HEART_MEDAL "Bronze Heart Medal"
#define MARINE_VALOR_MEDAL "Medal of Valor"
#define MARINE_HEROISM_MEDAL "Medal of Exceptional Heroism"
#define MARINE_DELTA_MEDAL "Delta Squad Medal"

/obj/item/clothing/accessory/medal
	name = "bronze medal"
	desc = "A bronze medal."
	icon_state = "bronze"
	custom_materials = list(/datum/material/iron=1000)
	resistance_flags = FIRE_PROOF
	var/medaltype = "medal" //Sprite used for medalbox
	var/commended = FALSE

//Pinning medals on people
/obj/item/clothing/accessory/medal/attack(mob/living/carbon/human/M, mob/living/user)
	if(ishuman(M) && (user.a_intent == INTENT_HELP))

		if(M.wear_suit)
			if((M.wear_suit.flags_inv & HIDEJUMPSUIT)) //Check if the jumpsuit is covered
				to_chat(user, "<span class='warning'>Medals can only be pinned on jumpsuits.</span>")
				return

		if(M.w_uniform)
			var/obj/item/clothing/under/U = M.w_uniform
			var/delay = 20
			if(user == M)
				delay = 0
			else
				user.visible_message("[user] is trying to pin [src] on [M]'s chest.", \
									"<span class='notice'>You try to pin [src] on [M]'s chest.</span>")
			var/input
			if(!commended && user != M)
				input = stripped_input(user,"Please input a reason for this commendation, it will be recorded by Nanotrasen.", ,"", 140)
			if(do_after(user, delay, target = M))
				if(U.attach_accessory(src, user, 0)) //Attach it, do not notify the user of the attachment
					if(user == M)
						to_chat(user, "<span class='notice'>You attach [src] to [U].</span>")
					else
						user.visible_message("[user] pins \the [src] on [M]'s chest.", \
											"<span class='notice'>You pin \the [src] on [M]'s chest.</span>")
						if(input)
							SSblackbox.record_feedback("associative", "commendation", 1, list("commender" = "[user.real_name]", "commendee" = "[M.real_name]", "medal" = "[src]", "reason" = input))
							GLOB.commendations += "[user.real_name] awarded <b>[M.real_name]</b> the <span class='medaltext'>[name]</span>! \n- [input]"
							commended = TRUE
							desc += "<br>The inscription reads: [input] - [user.real_name]"
							log_game("<b>[key_name(M)]</b> was given the following commendation by <b>[key_name(user)]</b>: [input]")
							message_admins("<b>[key_name(M)]</b> was given the following commendation by <b>[key_name(user)]</b>: [input]")
							SSpersistence.medals += list(list(
								"ckey" = M.ckey,
								"round_id" = GLOB.round_id,
								"medal_type" = type,
								"medal_icon" = replacetext(type, " ", "-"),
								"recipient_name" = M.real_name,
								"recipient_role" = M.job,
								"giver_name" = user.real_name,
								"citation" = input
							))

		else
			to_chat(user, "<span class='warning'>Medals can only be pinned on jumpsuits!</span>")
	else
		..()

/obj/item/clothing/accessory/medal/conduct
	name = MARINE_CONDUCT_MEDAL
	desc = "A bronze medal awarded for distinguished conduct. Whilst a great honor, this is the most basic award given by Nanotrasen. It is often awarded by a captain to a member of his crew."
	icon_state = "bronze_b"

/obj/item/clothing/accessory/medal/bronze_heart
	name = MARINE_BRONZE_HEART_MEDAL
	desc = "A bronze heart-shaped medal awarded for sacrifice. It is often awarded posthumously or for severe injury in the line of duty."
	icon_state = "bronze_heart"

/obj/item/clothing/accessory/medal/engineer
	name = "\"Shift's Best Electrician\" award"
	desc = "An award bestowed upon engineers who have excelled at keeping the station running in the best possible condition against all odds."
	icon_state = "engineer"

/obj/item/clothing/accessory/medal/greytide
	name = "\"Greytider of the shift\" award"
	desc = "An award for only the most annoying of assistants.  Locked doors mean nothing to you and behaving is not in your vocabulary"
	icon_state = "greytide"

/obj/item/clothing/accessory/medal/delta
	name = MARINE_DELTA_MEDAL
	desc = "Proof of belonging to the \"Delta Squad\", as well as the strength and leadership in it."
	icon_state = "medal_delta"

/obj/item/clothing/accessory/medal/ribbon
	name = "ribbon"
	desc = "A ribbon"
	icon_state = "cargo"

/obj/item/clothing/accessory/medal/ribbon/cargo
	name = "\"cargo tech of the shift\" award"
	desc = "An award bestowed only upon those cargotechs who have exhibited devotion to their duty in keeping with the highest traditions of Cargonia."
	icon_state = "cargo_b"

/obj/item/clothing/accessory/medal/ribbon/medical_doctor
	name = "\"doctor of the shift\" award"
	desc = "An award bestowed only upon the most capable doctors who have upheld the Hippocratic Oath to the best of their ability"
	icon_state = "medical_doctor"

/obj/item/clothing/accessory/medal/silver
	name = "silver medal"
	desc = "A silver medal."
	icon_state = "silver"
	medaltype = "medal-silver"
	custom_materials = list(/datum/material/silver=1000)

/obj/item/clothing/accessory/medal/silver/valor
	name = MARINE_VALOR_MEDAL
	desc = "A silver medal awarded for acts of exceptional valor."
	icon_state = "silver_b"

/obj/item/clothing/accessory/medal/silver/security
	name = "robust security award"
	desc = "An award for distinguished combat and sacrifice in defence of Nanotrasen's commercial interests. Often awarded to security staff."
	icon_state = "silver_c"

/obj/item/clothing/accessory/medal/gold
	name = "gold medal"
	desc = "A prestigious golden medal."
	icon_state = "gold"
	medaltype = "medal-gold"
	custom_materials = list(/datum/material/gold=1000)

/obj/item/clothing/accessory/medal/gold/captain
	name = "medal of captaincy"
	desc = "A golden medal awarded exclusively to those promoted to the rank of captain. It signifies the codified responsibilities of a captain to Nanotrasen, and their undisputable authority over their crew."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	icon_state = "gold_b"

/obj/item/clothing/accessory/medal/gold/captain/family
	name = "old medal of captaincy"
	desc = "A rustic badge pure gold, has been through hell and back by the looks, the syndcate have been after these by the looks of it for generations..."
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, RAD = 0, FIRE = 0, ACID = 10) //Pure gold
	custom_materials = list(/datum/material/gold=2000)
	icon_state = "gold_c"

/obj/item/clothing/accessory/medal/gold/heroism
	name = MARINE_HEROISM_MEDAL
	desc = "An extremely rare golden medal awarded only by CentCom. To receive such a medal is the highest honor and as such, very few exist. This medal is almost never awarded to anybody but commanders."
	icon_state = "platinum"

/obj/item/clothing/accessory/medal/plasma
	name = "plasma medal"
	desc = "An eccentric medal made of plasma."
	icon_state = "plasma"
	medaltype = "medal-plasma"
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, RAD = 0, FIRE = -10, ACID = 0) //It's made of plasma. Of course it's flammable.
	custom_materials = list(/datum/material/plasma=1000)

/obj/item/clothing/accessory/medal/plasma/temperature_expose(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	if(exposed_temperature > 300)
		atmos_spawn_air("plasma=20;TEMP=[exposed_temperature]")
		visible_message("<span class='danger'> \The [src] bursts into flame!</span>","<span class='userdanger'>Your [src] bursts into flame!</span>")
		qdel(src)

/obj/item/clothing/accessory/medal/plasma/nobel_science
	name = "nobel sciences award"
	desc = "A plasma medal which represents significant contributions to the field of science or engineering."
	icon_state = "plasma_b"

////////////
//Armbands//
////////////

/obj/item/clothing/accessory/armband
	name = "Red Armband"
	desc = "An fancy red armband!"
	icon_state = "redband"

/obj/item/clothing/accessory/armband/deputy
	name = "Security Deputy Armband"
	desc = "An armband, worn by personnel authorized to act as a deputy of station security."

/obj/item/clothing/accessory/armband/cargo
	name = "Cargo Bay Guard Armband"
	desc = "An armband, worn by the station's security forces to display which department they're assigned to. This one is brown."
	icon_state = "cargoband"

/obj/item/clothing/accessory/armband/engine
	name = "Engineering Guard Armband"
	desc = "An armband, worn by the station's security forces to display which department they're assigned to. This one is orange with a reflective strip!"
	icon_state = "engieband"

/obj/item/clothing/accessory/armband/science
	name = "Science Guard Armband"
	desc = "An armband, worn by the station's security forces to display which department they're assigned to. This one is purple."
	icon_state = "rndband"

/obj/item/clothing/accessory/armband/hydro
	name = "Hydroponics Guard Armband"
	desc = "An armband, worn by the station's security forces to display which department they're assigned to. This one is green and blue."
	icon_state = "hydroband"

/obj/item/clothing/accessory/armband/med
	name = "Medical Guard Armband"
	desc = "An armband, worn by the station's security forces to display which department they're assigned to. This one is white."
	icon_state = "medband"

/obj/item/clothing/accessory/armband/medblue
	name = "Medical Guard Armband"
	desc = "An armband, worn by the station's security forces to display which department they're assigned to. This one is white and blue."
	icon_state = "medblueband"

/obj/item/clothing/accessory/armband/sfparmband
	name = "SFP Department Armpatch"
	desc = "Armpatch one of superior forces of Federal Agencies on territory of SolGov. This one belongs to Agent."
	icon_state = "sfp_patch"
	item_state = "sfp_patch"
	icon = 'modular_bluemoon/SmiLeY/icons/sfp_armpatch_obj.dmi'
	mob_overlay_icon = 'modular_bluemoon/SmiLeY/icons/sfp_armpatch.dmi'
	strip_delay = 60
	dog_fashion = null

//////////////
//OBJECTION!//
//////////////

/obj/item/clothing/accessory/lawyers_badge
	name = "attorney's badge"
	desc = "Fills you with the conviction of JUSTICE. Lawyers tend to want to show it to everyone they meet."
	icon_state = "lawyerbadge"

/obj/item/clothing/accessory/lawyers_badge/attack_self(mob/user)
	if(prob(1))
		user.say("The testimony contradicts the evidence!", forced = "attorney's badge")
	user.visible_message("[user] shows [user.p_their()] attorney's badge.", "<span class='notice'>You show your attorney's badge.</span>")

/obj/item/clothing/accessory/lawyers_badge/on_uniform_equip(obj/item/clothing/under/U, user)
	var/mob/living/L = user
	if(L)
		L.bubble_icon = "lawyer"

/obj/item/clothing/accessory/lawyers_badge/on_uniform_dropped(obj/item/clothing/under/U, user)
	var/mob/living/L = user
	if(L)
		L.bubble_icon = initial(L.bubble_icon)

////////////////
//HA HA! NERD!//
////////////////

/obj/item/clothing/accessory/pocketprotector
	name = "pocket protector"
	desc = "Can protect your clothing from ink stains, but you'll look like a nerd if you're using one."
	icon_state = "pocketprotector"
	pocket_storage_component_path = /datum/component/storage/concrete/pockets/pocketprotector
	max_stack = 3 // BLUEMOON EDIT - изменение аксессуаров

/obj/item/clothing/accessory/pocketprotector/full/Initialize(mapload)
	. = ..()
	new /obj/item/pen/red(src)
	new /obj/item/pen(src)
	new /obj/item/pen/blue(src)

/obj/item/clothing/accessory/pocketprotector/cosmetology/Initialize(mapload)
	. = ..()
	for(var/i in 1 to 3)
		new /obj/item/lipstick/random(src)

////////////////
//OONGA BOONGA//
////////////////

/obj/item/clothing/accessory/talisman
	name = "bone talisman"
	desc = "A hunter's talisman, some say the old gods smile on those who wear it."
	icon_state = "talisman"
	armor = list(MELEE = 5, BULLET = 5, LASER = 0, ENERGY = 0, BOMB = 10, BIO = 20, RAD = 5, FIRE = 0, ACID = 25)
	restricted_accessory = TRUE // BLUEMOON EDIT - изменение аксессуаров

/obj/item/clothing/accessory/skullcodpiece
	name = "skull codpiece"
	desc = "A skull shaped ornament, intended to protect the important things in life."
	icon_state = "skull"
	above_suit = TRUE
	armor = list(MELEE = 5, BULLET = 5, LASER = 0, ENERGY = 0, BOMB = 10, BIO = 20, RAD = 5, FIRE = 0, ACID = 25)
	restricted_accessory = TRUE // BLUEMOON EDIT - изменение аксессуаров

/obj/item/clothing/accessory/skullcodpiece/fake
	name = "false codpiece"
	desc = "A plastic ornament, intended to protect the important things in life. It's not very good at it."
	icon_state = "skull"
	above_suit = TRUE
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, RAD = 0, FIRE = 0, ACID = 0)
	restricted_accessory = TRUE // BLUEMOON EDIT - изменение аксессуаров

/////////////////////
//Syndie Accessories//
/////////////////////

/obj/item/clothing/accessory/padding
	name = "protective padding"
	desc = "A soft padding meant to cushion the wearer from melee harm."
	icon_state = "padding"
	armor = list(MELEE = 10, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 5, BIO = 0, RAD = 0, FIRE = -20, ACID = 45) // BLUEMOON CHANGE нёрф защиты в два раза
	flags_inv = HIDEACCESSORY //hidden from indiscrete mob examines.
	restricted_accessory = TRUE // BLUEMOON EDIT - изменение аксессуаров

/obj/item/clothing/accessory/kevlar
	name = "kevlar padding"
	desc = "A layered kevlar padding meant to cushion the wearer from ballistic harm."
	icon_state = "padding"
	armor = list(MELEE = 0, BULLET = 10, LASER = 0, ENERGY = 0, BOMB = 10, BIO = 0, RAD = 0, FIRE = 0, ACID = 25) // BLUEMOON CHANGE нёрф защиты в два раза
	flags_inv = HIDEACCESSORY
	restricted_accessory = TRUE // BLUEMOON EDIT - изменение аксессуаров

/obj/item/clothing/accessory/plastics
	name = "ablative padding"
	desc = "A thin ultra-refractory composite padding meant to cushion the wearer from energy lasers harm."
	icon_state = "plastics"
	armor = list(MELEE = 5, BULLET = 0, LASER = 10, ENERGY = 10, BOMB = 0, BIO = 0, RAD = 0, FIRE = 20, ACID = -40) // BLUEMOON CHANGE нёрф защиты в два раза
	flags_inv = HIDEACCESSORY
	restricted_accessory = TRUE // BLUEMOON EDIT - изменение аксессуаров

//necklace
/obj/item/clothing/accessory/necklace
	name = "necklace"
	desc = "A necklace."
	icon_state = "locket"
	obj_flags = UNIQUE_RENAME
	custom_materials = list(/datum/material/iron=100)
	resistance_flags = FIRE_PROOF


/obj/item/clothing/accessory/pride
	name = "pride pin"
	desc = "A Nanotrasen Diversity & Inclusion Center-sponsored holographic pin to show off your pride of sexuality or gender identity, reminding the crew of their unwavering commitment to equity, diversity, and inclusion!"
	icon_state = "pride"
	above_suit = TRUE
	obj_flags = UNIQUE_RENAME
	unique_reskin = list(
		"Rainbow Pride"     = list("icon_state" = "pride"),
		"Bisexual Pride"    = list("icon_state" = "pride_bi"),
		"Pansexual Pride"   = list("icon_state" = "pride_pan"),
		"Asexual Pride"     = list("icon_state" = "pride_ace"),
		"Non-binary Pride"  = list("icon_state" = "pride_enby"),
		"Transgender Pride" = list("icon_state" = "pride_trans")
	)

/obj/item/clothing/accessory/pride/reskin_obj(mob/M)
	. = ..()
	name = "[current_skin] pin"
