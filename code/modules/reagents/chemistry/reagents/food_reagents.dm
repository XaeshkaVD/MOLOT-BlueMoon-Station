///////////////////////////////////////////////////////////////////
					//Food Reagents
//////////////////////////////////////////////////////////////////


// Part of the food code. Also is where all the food
// 	condiments, additives, and such go.


/datum/reagent/consumable
	name = "Consumable"
	taste_description = "generic food"
	taste_mult = 4
	value = REAGENT_VALUE_VERY_COMMON
	var/nutriment_factor = 1 * REAGENTS_METABOLISM
	var/max_nutrition = INFINITY
	var/quality = 0	//affects mood, typically higher for mixed drinks with more complex recipes

/datum/reagent/consumable/on_mob_life(mob/living/carbon/M)
	if(!HAS_TRAIT(M, TRAIT_NO_PROCESS_FOOD))
		current_cycle++
		M.adjust_nutrition(nutriment_factor, max_nutrition)
	M.CheckBloodsuckerEatFood(nutriment_factor)
	holder.remove_reagent(type, metabolization_rate)

/datum/reagent/consumable/reaction_mob(mob/living/M, method=TOUCH, reac_volume)
	if(method == INGEST)
		if (quality && !HAS_TRAIT(M, TRAIT_AGEUSIA))
			switch(quality)
				if (DRINK_NICE)
					SEND_SIGNAL(M, COMSIG_ADD_MOOD_EVENT, "quality_drink", /datum/mood_event/quality_nice)
				if (DRINK_GOOD)
					SEND_SIGNAL(M, COMSIG_ADD_MOOD_EVENT, "quality_drink", /datum/mood_event/quality_good)
				if (DRINK_VERYGOOD)
					SEND_SIGNAL(M, COMSIG_ADD_MOOD_EVENT, "quality_drink", /datum/mood_event/quality_verygood)
				if (DRINK_FANTASTIC)
					SEND_SIGNAL(M, COMSIG_ADD_MOOD_EVENT, "quality_drink", /datum/mood_event/quality_fantastic)
				if (RACE_DRINK)
					SEND_SIGNAL(M, COMSIG_ADD_MOOD_EVENT, "quality_drink", /datum/mood_event/race_drink)
	return ..()

/datum/reagent/consumable/nutriment
	name = "Nutriment"
	description = "All the vitamins, minerals, and carbohydrates the body needs in pure form."
	reagent_state = SOLID
	nutriment_factor = 10 * REAGENTS_METABOLISM
	color = "#664330" // rgb: 102, 67, 48

	var/brute_heal = 1
	var/burn_heal = 0

/datum/reagent/consumable/nutriment/on_hydroponics_apply(obj/item/seeds/myseed, datum/reagents/chems, obj/machinery/hydroponics/mytray, mob/user)
	. = ..()
	if(chems.has_reagent(type, 1))
		mytray.adjustHealth(round(chems.get_reagent_amount(type) * 0.2))

/datum/reagent/consumable/nutriment/on_mob_life(mob/living/carbon/M)
	if(!HAS_TRAIT(M, TRAIT_NO_PROCESS_FOOD))
		if(prob(50))
			M.heal_bodypart_damage(brute_heal,burn_heal, 0)
			. = 1
		..()

/datum/reagent/consumable/nutriment/on_new(list/supplied_data)
	// taste data can sometimes be ("salt" = 3, "chips" = 1)
	// and we want it to be in the form ("salt" = 0.75, "chips" = 0.25)
	// which is called "normalizing"
	if(!supplied_data)
		supplied_data = data

	// if data isn't an associative list, this has some WEIRD side effects
	// TODO probably check for assoc list?

	data = counterlist_normalise(supplied_data)

/datum/reagent/consumable/nutriment/on_merge(list/newdata, newvolume)
	if(!islist(newdata) || !newdata.len)
		return

	// data for nutriment is one or more (flavour -> ratio)
	// where all the ratio values adds up to 1

	var/list/taste_amounts = list()
	if(data)
		taste_amounts = data.Copy()

	counterlist_scale(taste_amounts, volume)

	var/list/other_taste_amounts = newdata.Copy()
	counterlist_scale(other_taste_amounts, newvolume)

	counterlist_combine(taste_amounts, other_taste_amounts)

	counterlist_normalise(taste_amounts)

	data = taste_amounts

/datum/reagent/consumable/nutriment/vitamin
	name = "Vitamin"
	description = "All the best vitamins, minerals, and carbohydrates the body needs in pure form."
	value = REAGENT_VALUE_VERY_COMMON //BLUEMOON CHANGE он есть в чистом виде в овощах
	nutriment_factor = 15 * REAGENTS_METABOLISM //The are the best food for you!
	brute_heal = 1
	burn_heal = 1

/datum/reagent/consumable/nutriment/vitamin/on_mob_life(mob/living/carbon/M)
	if(M.satiety < 600)
		M.satiety += 30
	. = ..()

/datum/reagent/consumable/cooking_oil
	name = "Cooking Oil"
	description = "A variety of cooking oil derived from fat or plants. Used in food preparation and frying."
	color = "#EADD6B" //RGB: 234, 221, 107 (based off of canola oil)
	taste_mult = 0.8
	value = REAGENT_VALUE_COMMON
	taste_description = "oil"
	nutriment_factor = 5 * REAGENTS_METABOLISM //Not very healthy on its own
	metabolization_rate = 10 * REAGENTS_METABOLISM
	var/fry_temperature = 450 //Around ~350 F (117 C) which deep fryers operate around in the real world
	var/boiling //Used in mob life to determine if the oil kills, and only on touch application

/datum/reagent/consumable/cooking_oil/reaction_obj(obj/O, reac_volume)
	if(holder && holder.chem_temp >= fry_temperature)
		if(isitem(O) && !O.GetComponent(/datum/component/fried) && !(O.resistance_flags & (FIRE_PROOF|INDESTRUCTIBLE)) && (!O.reagents || isfood(O))) //don't fry stuff we shouldn't
			O.loc.visible_message("<span class='warning'>[O] rapidly fries as it's splashed with hot oil! Somehow.</span>")
			O.fry(volume)
			if(O.reagents)
				O.reagents.add_reagent(/datum/reagent/consumable/cooking_oil, reac_volume)

/datum/reagent/consumable/cooking_oil/reaction_mob(mob/living/M, method = TOUCH, reac_volume, show_message = 1, touch_protection = 0)
	if(!istype(M))
		return
	if(holder && holder.chem_temp >= fry_temperature)
		boiling = TRUE
	if(method == VAPOR || method == TOUCH) //Directly coats the mob, and doesn't go into their bloodstream
		if(boiling)
			M.visible_message("<span class='warning'>The boiling oil sizzles as it covers [M]!</span>", \
			"<span class='userdanger'>You're covered in boiling oil!</span>")
			M.emote("realagony")
			playsound(M, 'sound/machines/fryer/deep_fryer_emerge.ogg', 25, TRUE)
			var/oil_damage = min((holder.chem_temp / fry_temperature) * 0.33,1) //Damage taken per unit
			M.adjustFireLoss(oil_damage * min(reac_volume,20)) //Damage caps at 20
	else
		..()
	return TRUE

/datum/reagent/consumable/cooking_oil/reaction_turf(turf/open/T, reac_volume)
	if(!istype(T) || isgroundlessturf(T))
		return
	if(reac_volume >= 5 && holder && holder.chem_temp >= fry_temperature)
		T.MakeSlippery(TURF_WET_LUBE, min_wet_time = 10 SECONDS, wet_time_to_add = reac_volume * 1.5 SECONDS)
		T.fry(reac_volume/4)

/datum/reagent/consumable/sugar
	name = "Sugar"
	description = "The organic compound commonly known as table sugar and sometimes called saccharose. This white, odorless, crystalline powder has a pleasing, sweet taste."
	reagent_state = SOLID
	color = "#FFFFFF" // rgb: 255, 255, 255
	taste_mult = 1.5 // stop sugar drowning out other flavours
	nutriment_factor = 3 * REAGENTS_METABOLISM
	metabolization_rate = 5 * REAGENTS_METABOLISM
	overdose_threshold = 200 // Hyperglycaemic shock
	taste_description = "sweetness"
	value = REAGENT_VALUE_NONE

// Plants should not have sugar, they can't use it and it prevents them getting water/ nutients, it is good for mold though...
/datum/reagent/consumable/sugar/on_hydroponics_apply(obj/item/seeds/myseed, datum/reagents/chems, obj/machinery/hydroponics/mytray, mob/user)
	. = ..()
	if(chems.has_reagent(type, 1))
		mytray.adjustWeeds(rand(2,3))
		mytray.adjustPests(rand(1,2))

/datum/reagent/consumable/sugar/overdose_start(mob/living/M)
	to_chat(M, "<span class='userdanger'>You go into hyperglycaemic shock! Lay off the twinkies!</span>")
	M.AdjustSleeping(20 SECONDS, FALSE)
	. = 1

/datum/reagent/consumable/sugar/overdose_process(mob/living/M)
	M.AdjustSleeping(40, FALSE)
	..()
	. = 1

//BlueMoon. Сахар токсичен для воксов
/datum/reagent/consumable/sugar/on_mob_life(mob/living/carbon/M)
	if(isvox(M))
		M.adjustToxLoss(3)
	return ..()

/datum/reagent/consumable/creamer
	name = "Coffee Creamer"
	description = "Powdered milk for cheap coffee. How delightful."
	taste_description = "milk"
	color = "#efeff0"
	nutriment_factor = 1.5

/datum/reagent/consumable/choccyshake
	name = "Chocolate Shake"
	description = "A frosty chocolate milkshake."
	color = "#541B00"
	quality = DRINK_VERYGOOD
	nutriment_factor = 8
	taste_description = "sweet creamy chocolate"
	chemical_flags = REAGENT_ALL_PROCESS
	value = REAGENT_VALUE_UNCOMMON

/datum/reagent/consumable/korta_nectar
	name = "Korta Nectar"
	description = "A sweet, sugary syrup made from crushed sweet korta nuts."
	color = "#d3a308"
	nutriment_factor = 5
	metabolization_rate = 1 * REAGENTS_METABOLISM
	taste_description = "peppery sweetness"

/datum/reagent/consumable/virus_food
	name = "Virus Food"
	description = "A mixture of water and milk. Virus cells can use this mixture to reproduce."
	nutriment_factor = 2 * REAGENTS_METABOLISM
	color = "#899613" // rgb: 137, 150, 19
	taste_description = "watery milk"

// Compost for EVERYTHING
/datum/reagent/consumable/virus_food/on_hydroponics_apply(obj/item/seeds/myseed, datum/reagents/chems, obj/machinery/hydroponics/mytray, mob/user)
	. = ..()
	if(chems.has_reagent(type, 1))
		mytray.adjustHealth(-round(chems.get_reagent_amount(type) * 0.5))

/datum/reagent/consumable/soysauce
	name = "Soysauce"
	description = "A salty sauce made from the soy plant."
	color = "#792300" // rgb: 121, 35, 0
	taste_description = "umami"
	value = REAGENT_VALUE_COMMON

/datum/reagent/consumable/ketchup
	name = "Ketchup"
	description = "Ketchup, catsup, whatever. It's tomato paste."
	nutriment_factor = 3 * REAGENTS_METABOLISM
	color = "#731008" // rgb: 115, 16, 8
	taste_description = "ketchup"

/datum/reagent/consumable/mustard
	name = "Mustard"
	description = "Mustard, mostly used on hotdogs, corndogs and burgers."
	nutriment_factor = 3 * REAGENTS_METABOLISM
	color = "#DDED26" // rgb: 221, 237, 38
	taste_description = "mustard"

/datum/reagent/consumable/capsaicin
	name = "Capsaicin Oil"
	description = "This is what makes chilis hot."
	color = "#B31008" // rgb: 179, 16, 8
	taste_description = "hot peppers"
	taste_mult = 1.5

/datum/reagent/consumable/capsaicin/on_mob_life(mob/living/carbon/M)
	var/heating = 0
	switch(current_cycle)
		if(1 to 15)
			heating = 5 * TEMPERATURE_DAMAGE_COEFFICIENT
			if(holder.has_reagent(/datum/reagent/cryostylane))
				holder.remove_reagent(/datum/reagent/cryostylane, 5)
			if(isslime(M))
				heating = rand(5,20)
		if(15 to 25)
			heating = 10 * TEMPERATURE_DAMAGE_COEFFICIENT
			if(isslime(M))
				heating = rand(10,20)
		if(25 to 35)
			heating = 15 * TEMPERATURE_DAMAGE_COEFFICIENT
			if(isslime(M))
				heating = rand(15,20)
		if(35 to INFINITY)
			heating = 20 * TEMPERATURE_DAMAGE_COEFFICIENT
			if(isslime(M))
				heating = rand(20,25)
	M.adjust_bodytemperature(heating)
	..()

/datum/reagent/consumable/frostoil
	name = "Frost Oil"
	description = "A special oil that noticably chills the body. Extracted from Icepeppers and slimes."
	color = "#8BA6E9" // rgb: 139, 166, 233
	taste_description = "mint"
	value = REAGENT_VALUE_COMMON
	pH = 13 //HMM! I wonder

/datum/reagent/consumable/frostoil/on_mob_life(mob/living/carbon/M)
	var/cooling = 0
	switch(current_cycle)
		if(1 to 15)
			cooling = -10 * TEMPERATURE_DAMAGE_COEFFICIENT
			if(holder.has_reagent(/datum/reagent/consumable/capsaicin))
				holder.remove_reagent(/datum/reagent/consumable/capsaicin, 5)
			if(isslime(M))
				cooling = -rand(5,20)
		if(15 to 25)
			cooling = -20 * TEMPERATURE_DAMAGE_COEFFICIENT
			if(isslime(M))
				cooling = -rand(10,20)
		if(25 to 35)
			cooling = -30 * TEMPERATURE_DAMAGE_COEFFICIENT
			if(prob(1))
				M.emote("shiver")
			if(isslime(M))
				cooling = -rand(15,20)
		if(35 to INFINITY)
			cooling = -40 * TEMPERATURE_DAMAGE_COEFFICIENT
			if(prob(5))
				M.emote("shiver")
			if(isslime(M))
				cooling = -rand(20,25)
	M.adjust_bodytemperature(cooling, 50)
	..()

/datum/reagent/consumable/frostoil/reaction_turf(turf/T, reac_volume)
	if(reac_volume >= 5)
		for(var/mob/living/simple_animal/slime/M in T)
			M.adjustToxLoss(rand(15,30))
	if(reac_volume >= 1) // Make Freezy Foam and anti-fire grenades!
		if(isopenturf(T))
			var/turf/open/OT = T
			OT.MakeSlippery(wet_setting=TURF_WET_ICE, min_wet_time=100, wet_time_to_add=reac_volume SECONDS) // Is less effective in high pressure/high heat capacity environments. More effective in low pressure.
			OT.air.set_temperature(OT.air.return_temperature() - MOLES_CELLSTANDARD*100*reac_volume/OT.air.heat_capacity()) // reduces environment temperature by 5K per unit.

/datum/reagent/consumable/condensedcapsaicin
	name = "Condensed Capsaicin"
	description = "A chemical agent used for self-defense and in police work."
	color = "#B31008" // rgb: 179, 16, 8
	taste_description = "scorching agony"
	pH = 7.4

/datum/reagent/consumable/condensedcapsaicin/reaction_mob(mob/living/M, method=TOUCH, reac_volume)
	if(!ishuman(M) && !ismonkey(M))
		return

	var/mob/living/carbon/victim = M
	if(method == TOUCH || method == VAPOR)
		//check for protection
		var/mouth_covered = 0
		var/eyes_covered = 0
		var/obj/item/safe_thing = null

		//monkeys and humans can have masks
		if( victim.wear_mask )
			if ( victim.wear_mask.flags_cover & MASKCOVERSEYES )
				eyes_covered = 1
				safe_thing = victim.wear_mask
			if ( victim.wear_mask.flags_cover & MASKCOVERSMOUTH )
				mouth_covered = 1
				safe_thing = victim.wear_mask

		//only humans can have helmets and glasses
		if(ishuman(victim))
			var/mob/living/carbon/human/H = victim
			if( H.head )
				if ( H.head.flags_cover & HEADCOVERSEYES )
					eyes_covered = 1
					safe_thing = H.head
				if ( H.head.flags_cover & HEADCOVERSMOUTH )
					mouth_covered = 1
					safe_thing = H.head
			if(H.glasses)
				eyes_covered = 1
				if ( !safe_thing )
					safe_thing = H.glasses

		//actually handle the pepperspray effects
		if ( eyes_covered && mouth_covered )
			return
		else if ( mouth_covered )	// Reduced effects if partially protected
			if(prob(50))
				if(!HAS_TRAIT(victim, TRAIT_ROBOTIC_ORGANISM)) // BLUEMOON ADD - роботы не кричат от боли
					victim.emote("realagony")
			victim.blur_eyes(6)
			victim.blind_eyes(4)
			victim.confused = max(M.confused, 6)
			victim.damageoverlaytemp = 120
			victim.DefaultCombatKnockdown(160, override_hardstun = 0.1, override_stamdmg = min(reac_volume * 3, 15))
			victim.add_movespeed_modifier(/datum/movespeed_modifier/reagent/pepperspray)
			addtimer(CALLBACK(victim, TYPE_PROC_REF(/mob, remove_movespeed_modifier), /datum/movespeed_modifier/reagent/pepperspray), 10 SECONDS)
			return
		else if ( eyes_covered ) // Eye cover is better than mouth cover
			victim.blur_eyes(6)
			victim.damageoverlaytemp = 60
			return
		else // Oh dear :D
			if(!HAS_TRAIT(victim, TRAIT_ROBOTIC_ORGANISM)) // BLUEMOON ADD - роботы не кричат от боли
				victim.emote("realagony")
			victim.blur_eyes(10)
			victim.blind_eyes(6)
			victim.confused = max(M.confused, 12)
			victim.damageoverlaytemp = 150
			victim.DefaultCombatKnockdown(160, override_hardstun = 0.1, override_stamdmg = min(reac_volume * 5, 25))
			victim.add_movespeed_modifier(/datum/movespeed_modifier/reagent/pepperspray)
			addtimer(CALLBACK(victim, TYPE_PROC_REF(/mob, remove_movespeed_modifier), /datum/movespeed_modifier/reagent/pepperspray), 10 SECONDS)
		victim.update_damage_hud()

/datum/reagent/consumable/condensedcapsaicin/on_mob_life(mob/living/carbon/M)
	if(prob(5))
		M.visible_message("<span class='warning'>[M] [pick("dry heaves!","coughs!","splutters!")]</span>")
	..()

/datum/reagent/consumable/sodiumchloride
	name = "Table Salt"
	description = "A salt made of sodium chloride. Commonly used to season food."
	reagent_state = SOLID
	color = "#FFFFFF" // rgb: 255,255,255
	taste_description = "salt"

/datum/reagent/consumable/sodiumchloride/reaction_mob(mob/living/M, method=TOUCH, reac_volume)
	if(!istype(M))
		return
	if(M.has_bane(BANE_SALT))
		M.mind.disrupt_spells(-200)
	if(HAS_TRAIT(M, TRAIT_SALT_SENSITIVE)) // haha snails go brrr
		M.adjustFireLoss(2)
		M.emote("scream")

/datum/reagent/consumable/sodiumchloride/on_mob_life(mob/living/M)
	if(HAS_TRAIT(M, TRAIT_SALT_SENSITIVE))
		M.adjustFireLoss(1) // equal to a standard toxin

/datum/reagent/consumable/sodiumchloride/reaction_turf(turf/T, reac_volume) //Creates an umbra-blocking salt pile
	if(!istype(T))
		return
	if(reac_volume < 1)
		return
	new/obj/effect/decal/cleanable/salt(T)

/datum/reagent/consumable/blackpepper
	name = "Black Pepper"
	description = "A powder ground from peppercorns. *AAAACHOOO*"
	reagent_state = SOLID
	// no color (ie, black)
	taste_description = "pepper"

/datum/reagent/consumable/coco
	name = "Coco Powder"
	description = "A fatty, bitter paste made from coco beans."
	reagent_state = SOLID
	nutriment_factor = 3 * REAGENTS_METABOLISM
	color = "#302000" // rgb: 48, 32, 0
	taste_description = "bitterness"

/datum/reagent/consumable/hot_coco
	name = "Hot Chocolate"
	description = "Made with love! And coco beans."
	color = "#660000" // rgb: 221, 202, 134
	taste_description = "creamy chocolate"
	glass_icon_state  = "chocolateglass"
	glass_name = "glass of chocolate"
	glass_desc = "Tasty."
	quality = DRINK_NICE // BLUEMOON ADD

/datum/reagent/consumable/hot_coco/on_mob_life(mob/living/carbon/M)
	M.adjust_bodytemperature(5 * TEMPERATURE_DAMAGE_COEFFICIENT, 0, BODYTEMP_NORMAL)
	..()

/datum/reagent/drug/mushroomhallucinogen
	name = "Mushroom Hallucinogen"
	description = "A strong hallucinogenic drug derived from certain species of mushroom."
	color = "#E700E7" // rgb: 231, 0, 231
	metabolization_rate = 0.2 * REAGENTS_METABOLISM
	taste_description = "mushroom"
	pH = 11
	value = REAGENT_VALUE_COMMON

/datum/reagent/drug/mushroomhallucinogen/on_mob_life(mob/living/carbon/M)
	M.slurring = max(M.slurring,50)
	switch(current_cycle)
		if(1 to 5)
			M.Dizzy(5)
			M.set_drugginess(30)
			if(prob(10))
				M.emote(pick("twitch","giggle"))
		if(5 to 10)
			M.Jitter(10)
			M.Dizzy(10)
			M.set_drugginess(35)
			if(prob(20))
				M.emote(pick("twitch","giggle"))
		if (10 to INFINITY)
			M.Jitter(20)
			M.Dizzy(20)
			M.set_drugginess(40)
			if(prob(30))
				M.emote(pick("twitch","giggle"))
	..()

/datum/reagent/consumable/garlic //NOTE: having garlic in your blood stops vampires from biting you.
	name = "Garlic Juice"
	//id = "garlic"
	description = "Crushed garlic. Chefs love it, but it can make you smell bad."
	color = "#FEFEFE"
	taste_description = "garlic"
	metabolization_rate = 0.15 * REAGENTS_METABOLISM
	value = REAGENT_VALUE_COMMON

/datum/reagent/consumable/garlic/on_mob_life(mob/living/carbon/M)
	if(isvampire(M)) //incapacitating but not lethal. Unfortunately, vampires cannot vomit.
		if(prob(min(25, current_cycle)))
			to_chat(M, "<span class='danger'>You can't get the scent of garlic out of your nose! You can barely think...</span>")
			M.Stun(10)
			M.Jitter(10)
			return

	else if(ishuman(M))
		var/mob/living/carbon/human/H = M
		if(H.job == "Cook")
			if(prob(20)) //stays in the system much longer than sprinkles/banana juice, so heals slower to partially compensate
				H.heal_bodypart_damage(1, 1, 0)
				. = 1
	..()

/datum/reagent/consumable/garlic/reaction_mob(mob/living/M, method, reac_volume)
	if(AmBloodsucker(M, TRUE)) //Theyll be immune to garlic as long as they masquarade, but they cant do it if they already have it.
		switch(method)
			if(INGEST)
				if(prob(min(30, current_cycle)))
					to_chat(M, "<span class='warning'>You cant get the smell of garlic out of your nose! You cant think straight because of it!</span>")
					M.Jitter(15)
				if(prob(min(15, current_cycle)))
					M.visible_message("<span class='danger'>Something you ate is burning your stomach!</span>", "<span class='warning'>[M] clutches their stomach and falls to the ground!</span>")
					M.Knockdown(20)
					M.emote("scream")
				if(prob(min(5, current_cycle)) && iscarbon(M))
					var/mob/living/carbon/C
					C.vomit()
			if(INJECT)
				if(prob(min(20, current_cycle)))
					to_chat(M, "<span class='warning'>You feel like your veins are boiling!</span>")
					M.emote("scream")
					M.adjustFireLoss(5)
	..()
/datum/reagent/consumable/sprinkles
	name = "Sprinkles"
	description = "Multi-colored little bits of sugar, commonly found on donuts. Loved by cops."
	color = "#FF00FF" // rgb: 255, 0, 255
	taste_description = "childhood whimsy"
	value = REAGENT_VALUE_COMMON

/datum/reagent/consumable/sprinkles/on_mob_life(mob/living/carbon/M)
	if(M.mind && HAS_TRAIT(M.mind, TRAIT_LAW_ENFORCEMENT_METABOLISM))
		M.heal_bodypart_damage(1,1, 0)
		. = 1
	..()

/datum/reagent/consumable/peanut_butter
	name = "Peanut Butter"
	description = "A popular food paste made from ground dry-roasted peanuts."
	color = "#C29261"
	value = REAGENT_VALUE_UNCOMMON
	nutriment_factor = 10 * REAGENTS_METABOLISM
	taste_description = "peanuts"

/datum/reagent/consumable/cornoil
	name = "Corn Oil"
	description = "An oil derived from various types of corn."
	nutriment_factor = 12 * REAGENTS_METABOLISM
	value = REAGENT_VALUE_UNCOMMON
	color = "#302000" // rgb: 48, 32, 0
	taste_description = "slime"

/datum/reagent/consumable/cornoil/reaction_turf(turf/open/T, reac_volume)
	if (!istype(T))
		return
	T.MakeSlippery(TURF_WET_LUBE, min_wet_time = 10 SECONDS, wet_time_to_add = reac_volume*2 SECONDS)
	var/obj/effect/hotspot/hotspot = (locate(/obj/effect/hotspot) in T)
	if(hotspot)
		var/datum/gas_mixture/lowertemp = T.return_air()
		lowertemp.set_temperature(max( min(lowertemp.return_temperature()-2000,lowertemp.return_temperature() / 2) ,TCMB))
		lowertemp.react(src)
		qdel(hotspot)

/datum/reagent/consumable/enzyme
	name = "Universal Enzyme"
	value = REAGENT_VALUE_COMMON
	description = "A universal enzyme used in the preperation of certain chemicals and foods."
	color = "#365E30" // rgb: 54, 94, 48
	taste_description = "sweetness"

/datum/reagent/consumable/dry_ramen
	name = "Dry Ramen"
	description = "Space age food, since August 25, 1958. Contains dried noodles, vegetables, and chemicals that boil in contact with water."
	reagent_state = SOLID
	color = "#302000" // rgb: 48, 32, 0
	taste_description = "dry and cheap noodles"

/datum/reagent/consumable/hot_ramen
	name = "Hot Ramen"
	description = "The noodles are boiled, the flavors are artificial, just like being back in school."
	nutriment_factor = 5 * REAGENTS_METABOLISM
	color = "#302000" // rgb: 48, 32, 0
	taste_description = "wet and cheap noodles"

/datum/reagent/consumable/nutraslop
	name = "Nutraslop"
	description = "Mixture of leftover prison foods served on previous days."
	nutriment_factor = 5 * REAGENTS_METABOLISM
	color = "#3E4A00" // rgb: 62, 74, 0
	taste_description = "your imprisonment"

/datum/reagent/consumable/hot_ramen/on_mob_life(mob/living/carbon/M)
	M.adjust_bodytemperature(10 * TEMPERATURE_DAMAGE_COEFFICIENT, 0, BODYTEMP_NORMAL)
	..()

/datum/reagent/consumable/hell_ramen
	name = "Hell Ramen"
	description = "The noodles are boiled, the flavors are artificial, just like being back in school."
	nutriment_factor = 5 * REAGENTS_METABOLISM
	color = "#302000" // rgb: 48, 32, 0
	taste_description = "wet and cheap noodles on fire"

/datum/reagent/consumable/hell_ramen/on_mob_life(mob/living/carbon/M)
	M.adjust_bodytemperature(10 * TEMPERATURE_DAMAGE_COEFFICIENT)
	..()

/datum/reagent/consumable/flour
	name = "Flour"
	description = "This is what you rub all over yourself to pretend to be a ghost."
	reagent_state = SOLID
	color = "#FFFFFF" // rgb: 0, 0, 0
	taste_description = "chalky wheat"

/datum/reagent/consumable/flour/reaction_turf(turf/T, reac_volume)
	if(!isspaceturf(T))
		var/obj/effect/decal/cleanable/flour/reagentdecal = new/obj/effect/decal/cleanable/flour(T)
		reagentdecal = locate() in T //Might have merged with flour already there.
		if(reagentdecal)
			reagentdecal.reagents.add_reagent(/datum/reagent/consumable/flour, reac_volume)

/datum/reagent/consumable/cherryjelly
	name = "Cherry Jelly"
	description = "Totally the best. Only to be spread on foods with excellent lateral symmetry."
	color = "#801E28" // rgb: 128, 30, 40
	value = REAGENT_VALUE_COMMON
	taste_description = "cherry"

/datum/reagent/consumable/bluecherryjelly
	name = "Blue Cherry Jelly"
	description = "Blue and tastier kind of cherry jelly."
	color = "#00F0FF"
	value = REAGENT_VALUE_UNCOMMON
	taste_description = "blue cherry"

/datum/reagent/consumable/rice
	name = "Rice"
	description = "tiny nutritious grains"
	reagent_state = SOLID
	nutriment_factor = 3 * REAGENTS_METABOLISM
	color = "#FFFFFF" // rgb: 0, 0, 0
	taste_description = "rice"

/datum/reagent/consumable/vanilla
	name = "Vanilla Powder"
	value = REAGENT_VALUE_UNCOMMON
	description = "A fatty, bitter paste made from vanilla pods."
	reagent_state = SOLID
	nutriment_factor = 5 * REAGENTS_METABOLISM
	color = "#FFFACD"
	taste_description = "vanilla"

/datum/reagent/consumable/eggyolk
	name = "Egg Yolk"
	description = "It's full of protein."
	nutriment_factor = 3 * REAGENTS_METABOLISM
	color = "#FFB500"
	taste_description = "egg"

/datum/reagent/consumable/corn_starch
	name = "Corn Starch"
	description = "A slippery solution."
	color = "#f7f6e4"
	taste_description = "slime"

/datum/reagent/consumable/corn_syrup
	name = "Corn Syrup"
	value = REAGENT_VALUE_UNCOMMON
	description = "Decays into sugar."
	color = "#fff882"
	metabolization_rate = 3 * REAGENTS_METABOLISM
	taste_description = "sweet slime"

/datum/reagent/consumable/corn_syrup/on_mob_life(mob/living/carbon/M)
	holder.add_reagent(/datum/reagent/consumable/sugar, 3)
	..()

/datum/reagent/consumable/honey
	name = "honey"
	description = "Sweet sweet honey that decays into sugar. Has antibacterial and natural healing properties."
	color = "#d3a308"
	value = REAGENT_VALUE_COMMON
	nutriment_factor = 10 * REAGENTS_METABOLISM
	metabolization_rate = 1 * REAGENTS_METABOLISM
	taste_description = "sweetness"

/datum/reagent/consumable/honey/on_mob_life(mob/living/carbon/M)
	M.reagents.add_reagent(/datum/reagent/consumable/sugar,3)
	if(prob(55))
		M.adjustBruteLoss(-1*REM, 0)
		M.adjustFireLoss(-1*REM, 0)
		M.adjustOxyLoss(-1*REM, 0)
		M.adjustToxLoss(-1*REM, 0, TRUE) //heals TOXINLOVERs
	..()

/datum/reagent/consumable/honey/reaction_mob(mob/living/M, method=TOUCH, reac_volume)
	if(iscarbon(M) && (method in list(TOUCH, VAPOR, PATCH)))
		var/mob/living/carbon/C = M
		for(var/s in C.surgeries)
			var/datum/surgery/S = s
			S.success_multiplier = max(0.6, S.success_multiplier) // +60% success probability on each step, compared to bacchus' blessing's ~46%
	..()

/datum/reagent/consumable/mayonnaise
	name = "Mayonnaise"
	description = "An white and oily mixture of mixed egg yolks."
	color = "#DFDFDF"
	value = 5
	taste_description = "mayonnaise"
	value = REAGENT_VALUE_COMMON

/datum/reagent/consumable/tearjuice
	name = "Tear Juice"
	description = "A blinding substance extracted from certain onions."
	color = "#c0c9a0"
	taste_description = "bitterness"
	pH = 5
	value = REAGENT_VALUE_COMMON

/datum/reagent/consumable/tearjuice/reaction_mob(mob/living/M, method=TOUCH, reac_volume)
	if(!istype(M))
		return
	var/unprotected = FALSE
	switch(method)
		if(INGEST)
			unprotected = TRUE
		if(INJECT)
			unprotected = FALSE
		else	//Touch or vapor
			if(!M.is_mouth_covered() && !M.is_eyes_covered())
				unprotected = TRUE
	if(unprotected)
		if(!M.getorganslot(ORGAN_SLOT_EYES))	//can't blind somebody with no eyes
			to_chat(M, "<span class = 'notice'>Your eye sockets feel wet.</span>")
		else
			if(!M.eye_blurry)
				to_chat(M, "<span class = 'warning'>Tears well up in your eyes!</span>")
			M.blind_eyes(2)
			M.blur_eyes(5)
	..()

/datum/reagent/consumable/tearjuice/on_mob_life(mob/living/carbon/M)
	..()
	if(M.eye_blurry)	//Don't worsen vision if it was otherwise fine
		M.blur_eyes(4)
		if(prob(10))
			to_chat(M, "<span class = 'warning'>Your eyes sting!</span>")
			M.blind_eyes(2)


/datum/reagent/consumable/nutriment/stabilized
	name = "Stabilized Nutriment"
	description = "A bioengineered protien-nutrient structure designed to decompose in high saturation. In layman's terms, it won't get you fat."
	reagent_state = SOLID
	nutriment_factor = 12 * REAGENTS_METABOLISM
	max_nutrition = NUTRITION_LEVEL_FULL - 25
	color = "#664330" // rgb: 102, 67, 48
	value = REAGENT_VALUE_RARE


////Lavaland Flora Reagents////


/datum/reagent/consumable/entpoly
	name = "Entropic Polypnium"
	description = "An ichor, derived from a certain mushroom, makes for a bad time."
	color = "#1d043d"
	taste_description = "bitter mushroom"
	pH = 12
	value = REAGENT_VALUE_RARE

/datum/reagent/consumable/entpoly/on_mob_life(mob/living/carbon/M)
	if(current_cycle >= 10)
		M.Unconscious(40, 0)
		. = 1
	if(prob(20))
		M.losebreath += 4
		M.adjustOrganLoss(ORGAN_SLOT_BRAIN, 2*REM, 150)
		M.adjustToxLoss(3*REM,0)
		M.adjustStaminaLoss(10*REM,0)
		M.blur_eyes(5)
		. = TRUE
	..()

/datum/reagent/consumable/tinlux
	name = "Tinea Luxor"
	description = "A stimulating ichor which causes luminescent fungi to grow on the skin. "
	color = "#b5a213"
	taste_description = "tingling mushroom"
	pH = 11.2
	value = REAGENT_VALUE_RARE

/datum/reagent/consumable/tinlux/reaction_mob(mob/living/M)
	M.set_light(2)

/datum/reagent/consumable/tinlux/on_mob_end_metabolize(mob/living/M)
	M.set_light(-2)

/datum/reagent/consumable/vitfro
	name = "Vitrium Froth"
	description = "A bubbly paste that heals wounds of the skin."
	color = "#d3a308"
	nutriment_factor = 3 * REAGENTS_METABOLISM
	taste_description = "fruity mushroom"
	pH = 10.4
	value = REAGENT_VALUE_RARE

/datum/reagent/consumable/vitfro/on_mob_life(mob/living/carbon/M)
	if(prob(80))
		M.adjustBruteLoss(-1*REM, 0)
		M.adjustFireLoss(-1*REM, 0)
		. = TRUE
	..()

// BLUEMOON ADD START - кактусы с лаваленда, а также никтотиновые листья дают эффект обезболивающего для операций
/datum/reagent/consumable/vitfro/on_mob_metabolize(mob/living/M) //modularisation for miners salve painkiller.
	..()
	if(iscarbon(M))
		ADD_TRAIT(M, TRAIT_PAINKILLER, PAINKILLER_VITFRUIT)
		M.throw_alert("painkiller", /atom/movable/screen/alert/painkiller)

/datum/reagent/consumable/vitfro/on_mob_end_metabolize(mob/living/M)
	..()
	if(iscarbon(M))
		REMOVE_TRAIT(M, TRAIT_PAINKILLER, PAINKILLER_VITFRUIT)
		M.clear_alert("painkiller", /atom/movable/screen/alert/painkiller)
// BLUEMOON ADD END

/datum/reagent/consumable/clownstears
	name = "Clown's Tears"
	description = "The sorrow and melancholy of a thousand bereaved clowns, forever denied their Honkmechs."
	nutriment_factor = 5 * REAGENTS_METABOLISM
	color = "#eef442" // rgb: 238, 244, 66
	taste_description = "mournful honking"
	pH = 9.2

/datum/reagent/consumable/liquidelectricity
	name = "Liquid Electricity"
	description = "The blood of Ethereals, and the stuff that keeps them going. Great for them, horrid for anyone else."
	nutriment_factor = 5 * REAGENTS_METABOLISM
	color = "#97ee63"
	taste_description = "pure electricity"

/datum/reagent/consumable/liquidelectricity/reaction_mob(mob/living/M, method=TOUCH, reac_volume) //can't be on life because of the way blood works.
	if((method == INGEST || method == INJECT || method == PATCH) && iscarbon(M))

		var/mob/living/carbon/C = M
		var/obj/item/organ/stomach/ethereal/stomach = C.getorganslot(ORGAN_SLOT_STOMACH)
		if(istype(stomach))
			stomach.adjust_charge(reac_volume * REM)

/datum/reagent/consumable/liquidelectricity/on_mob_life(mob/living/carbon/M)
	if(prob(25) && !isethereal(M))
		M.electrocute_act(rand(10,15), "Liquid Electricity in their body", 1) //lmao at the newbs who eat energy bars
		playsound(M, "sparks", 50, TRUE)
	return ..()

/datum/reagent/consumable/astrotame
	name = "Astrotame"
	description = "A space age artifical sweetener."
	nutriment_factor = 0
	metabolization_rate = 2 * REAGENTS_METABOLISM
	reagent_state = SOLID
	color = "#FFFFFF" // rgb: 255, 255, 255
	taste_mult = 8
	taste_description = "sweetness"
	overdose_threshold = 17
	value = 0.2

/datum/reagent/consumable/astrotame/overdose_process(mob/living/carbon/M)
	if(M.disgust < 80)
		M.adjust_disgust(10)
	..()
	. = TRUE

/datum/reagent/consumable/caramel
	name = "Caramel"
	description = "Who would have guessed that heated sugar could be so delicious?"
	nutriment_factor = 4 * REAGENTS_METABOLISM
	color = "#D98736"
	taste_mult = 2
	taste_description = "caramel"
	reagent_state = SOLID
	value = REAGENT_VALUE_COMMON

/datum/reagent/consumable/secretsauce
	name = "secret sauce"
	description = "What could it be."
	nutriment_factor = 2 * REAGENTS_METABOLISM
	color = "#792300"
	taste_description = "indescribable"
	taste_mult = 100
	can_synth = FALSE
	pH = 6.1
	value = REAGENT_VALUE_AMAZING

/datum/reagent/consumable/secretsauce/reaction_obj(obj/O, reac_volume)
	//splashing any amount above or equal to 1u of secret sauce onto a piece of food turns its quality to 100
	if(reac_volume >= 1 && isfood(O))
		var/obj/item/reagent_containers/food/splashed_food = O
		splashed_food.adjust_food_quality(100)
		// if it's a customisable food, we need to edit its total quality too, to prevent its quality resetting from adding more ingredients!
		if(istype(O, /obj/item/reagent_containers/food/snacks/customizable))
			var/obj/item/reagent_containers/food/snacks/customizable/splashed_custom_food = O
			splashed_custom_food.total_quality += 10000

/datum/reagent/consumable/char
	name = "Char"
	description = "Essence of the grill. Has strange properties when overdosed."
	reagent_state = LIQUID
	nutriment_factor = 5 * REAGENTS_METABOLISM
	color = "#C8C8C8"
	taste_mult = 6
	taste_description = "smoke"
	overdose_threshold = 25
	value = REAGENT_VALUE_COMMON

/datum/reagent/consumable/char/overdose_process(mob/living/carbon/M)
	if(prob(10))
		M.say(pick("I hate my grill.", "I just want to grill something right for once...", "I wish I could just go on my lawnmower and cut the grass.", "Yep, Tetris. That was a good game..."))

/datum/reagent/consumable/bbqsauce
	name = "BBQ Sauce"
	description = "Sweet, Smokey, Savory, and gets everywhere. Perfect for Grilling."
	nutriment_factor = 5 * REAGENTS_METABOLISM
	color = "#78280A" // rgb: 120 40, 10
	taste_mult = 2.5 //sugar's 1.5, capsacin's 1.5, so a good middle ground.
	taste_description = "smokey sweetness"
	value = REAGENT_VALUE_COMMON

/datum/reagent/consumable/laughsyrup
	name = "Laughin' Syrup"
	description = "The product of juicing Laughin' Peas. Fizzy, and seems to change flavour based on what it's used with!"
	nutriment_factor = 5 * REAGENTS_METABOLISM
	color = "#803280"
	taste_mult = 2
	taste_description = "fizzy sweetness"
	value = REAGENT_VALUE_COMMON

