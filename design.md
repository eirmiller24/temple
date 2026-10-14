This is a preliminary design document for a temple exploration game I want to make.
Current working title is The Temple of Rhys. No particular structure to this design doc,
just throwing down all the ideas I have so far.

The Temple of Rhys is a dungeon exploration game with a targeted length of about 3-5 hours,
potentially way longer depending on how quickly players solve the central puzzle. The lore
is that a temple has been discovered in a collapsed crater deep in the jungle. The player is
and archeologist who is trying to explore the temple and uncover its mysteries. The real secret
is that the temple is a living creature that consumes organic matter within the temple structure
and eventually grows a set of artifacts. Removing the artifacts destroys the temple, but whoever
owns the artifacts eventually goes mad and builds a new temple. The temples and the artifacts
are almost like a Lovecraftian god. Cults worshipping this same god have popped up throughout
history, and they are ultimately all connected.

Rhys is a snake deity with four fangs in the roof of its mouth. The Fangs of Rhys are the
artifacts at the end of the temple, and they are capable of great powers. Immortality, wealth,
and power are all guaranteed to the owner of the Fangs, until they go mad and build a cult and a
temple and finally entomb themselves inside as their last act in deference to the snake god.

The player is introduced to the game through a cutscene that explains that this temple has been
discovered, and they have trekked for weeks through the jungle to arrive at this chasm that
supposedly has a temple inside. The player rappels down into the chasm and is greeted with a few
openings with obvious rooms behind them, but then they are violently attacked by bandits who take
all the player's gear and then knock out the player and go into the temple themselves.
With no food and no climbing gear, the player cannot get out of the chasm.
The only option is for them to enter the temple and hope they make a deal with the thieves.

The player has a couple of entrances that they can go through. It's clear that this temple is a
large underground mazelike structure, and something down below has given way which caused this
entire section to drop inwards and revealed the structure. Players initially can go through any
of the openings they choose, with a few different rooms and sets of puzzles. Exploration helps
them find a simple weapon, a lantern, cartographer's tools, and a set of climbing gear.
Also their radio, which connects via a relay station they had set up at the top of the cliff.
Technically only the climbing gear is required to get to the next section of the game, but the
goal will be to develop the puzzles and layout in such a way that it encourages the player to
get all the initial things they need.

One idea I like is that if you use a climbing gear, it remains in place until you pick it back
up. That requires being at the top of the rope where it is anchored. Acquiring multiple climbing
gears is necessary to explore every nook and cranny of the temple.

There will be a script in the temple that gives clues and ultimately reveals the true secret of
the temple. I'm thinking each character has three parts representing the initial consonant,
vowel, and ending consonant, so a word like "door" can be a single character. The script is
written vertically, and it's just English words - "door", "key", "safe", "death", etc. And then
longer sections of text that give lore, record prayers or history, etc.

A big idea I have is that the actual layout of the dungeon is itself formed of the script, and
the full map of the temple reveals the full name of the entity. Not sure how I am going to
implement this yet, but knowing the full name of the god is necessary in order to destroy it.
The player starts keeping a map as soon as they have the cartographer's tools. An important caveat
is that the section where the player entered rested on a large pillar below that collapsed, and
everything above it fell down intact. That means that players need to know how the script works
and know that they have to shift this one section up a character in order to actually read what
it says. I want the fact that the temple is partially collapsed and the current layout doesn't
exactly match the original design to be an important part of solving the main puzzle.

Once the player gets their radio back, they are able to contact a colleague who is a professor
at the university. The colleague is able to do research and give information as they discover it.
This is a major part of figuring out the secret of the temple. The colleague will over time
reveal to the player that these cults have shown up throughout history in very different locations
and that they always end in the leader going insane and then entombing themselves. The script
is the same across all the known temples, which is strange because it doesn't look like any
known human language and the various temples are thousands of miles and hundreds of years apart.

I want the game to play a lot like a Legend of Zelda game, specifically taking a lot of inspo
from Ocarina of Time and its adult dungeons in terms of puzzles and theming. The player should
feel lonely and isolated, in a creepy ancient place that can be explored but not truly
understood. Players can get through the game in a few hours if they only explore the dungeon
enough to find the Fangs of Rhys and the exit, and get out. This gets players the bad ending.
Getting the good ending requires identifying the full name of the snake god and accomplishing
some other steps I haven't decided yet to destroy the artifacts for good. If the player manages
to decipher the script and solve all the puzzles, they destroy the temple and the artifacts and
come out of it with nothing of value except their life.

I haven't decided if I want a 2D or 3D game yet. There's good reasons for both. But gameplay is either side-scrolling 2D metroidvania or OoT-style 3D puzzling and combat.

Okay, I think it's going to be a 2d sidescroller. I'm also going to just add some notes of things I've thought of instead of editing the above document. So here are some ideas I just had.

First, the four Fangs represent knowledge, power, life, and wealth. And they give the player
special abilities. When the player picks up the first fang (knowledge), they will have run out of batteries in their lantern and have limited vision. Immediately upon picking it up they get a dialog that says something like "you feel your senses sharpen and your mind grow" or something like that and they get full vision again. The power fang doubles weapon damage and grants the ability to break certain walls and lift/push certain objects (maybe), and the life fang grants you a double jump and the ability to breathe under water.

Secretly the Fangs all have active abilities as well. By the time the player has picked up the knowledge fang, their radio will also be dead. If they never figure out that the fangs have active abilities, they get no more dialog from the professor and the plot doesn't really progress forward. If they do figure out how to activate the fang's ability, they gain the ability to telepathically communicate with the professor. This also gives them a scan function a la metroid prime, because they can share images and audio through the mental connection with the professor. Figuring out that the fang has an active ability, and how to activate it, is necessary to not get the bad end. I'm thinking we use a menu where like you press A to select the item, B to use, and Y to drop. The fangs don't show any menu, but the wall tells you that the fangs can be activated the same as other items by just bowing after using them. If the player presses to select the item and then use the item, and then immediately quits the pause menu and crouches, the active ability happens. With the knowledge fang this contacts the professor through telepathy, and the player doesn't have to use the fang active again.

The power fang does massive damage to all enemies in the room but on a long cooldown, and the life fang restores the player's life force, again on a cooldown. The wealth fang restores the full inventory of the next item you use. This is the next major secret. The wealth fang can restore your inventory of climbing gears, which lets you proceed even deeper into the temple than the game would "normally" allow.

The knowledge fang has a secondary active ability where if you use it in certain spots, it can transport you to an alternate dimension. The monsters in the other dimension are much more powerful, and the rooms connect differently. The script on the wall in the alternate dimension doesn't make any sense - it's the same script as the normal writing, but if you try to translate it you get nonsense. There is a cypher on the alternate-dimension script that has to be solved in order to read it, and it gives clues about how to purify the fangs. These are all super abstract and weird things that you do with the fangs, like "use this item while equipping this and in front of this statue" or whatever. Doing this with all 4 fangs is necessary to get the best ending.

At the end of the game, you fight a final boss before entering the final alter room. After you have collected the four fangs from the temple and defeated the final boss, you can go into the alter room and place the fangs in a statue's mouth. That opens the final door in the game and starts a timer collapsing the entire temple. The snake fangs automatically get picked up and put back in your inventory when this happens. If you just run out of the temple, you get the worst ending - you become rich and famous but then eventually go crazy and form your own cult. If you *drop* the fangs before leaving, they get buried in the collapsing temple and you get the good ending. You've successfully stopped the cycle, but anybody else could find the fangs and restart it. You also are hurt and alone in the jungle, and you die before making it back to civilization.

In the boss room, there are pillars with characters on them. If you drop the four fangs in front of the pillars with the correct characters in the right order to spell the god's name, you summon the god into the space and you can fight and kill them. This is the great ending, where you have an extra hard final boss fight but the deity is destroyed and the cycle is over forever. But you are still poor and stuck in the jungle and die on your way out. The best ending is achieved by purifying the four fangs and then dropping them in front of the correct pillars in the boss room. Here, after you kill the boss, you get to escape with the fangs and live happily ever after with infinite life and wealth and whatever you want. Happy ending.

I think I'm removing the idea of the temple itself being a living being. It doesn't reproduce by spreading artifacts that make people insane so they make new temples that grow new artifacts. Instead, you need all 4 artifacts to escape, the 4 together turn you into a long-lived super-strong all-knowing monarch with infinite wealth, but then you eventually turn your followers into a cult and build your own temple and entomb yourself inside it. It's not like the temples are growing in number, it's more that there's one at a time and it hides for a long time before showing itself to create a new cult and a new temple. 

The game's initial phase is collecting the first climbing gear and your radio, notebook, and at least one weapon. Also, I've changed cartographer's tools to just a notebook, and you need that in order to access all sorts of information. Once you have the radio you learn about the cult of Rhys from your professor, and about the four fangs. You have no real choice to escape except explore the temple and collect the fangs, so you do. If you never learn to read the script, you won't learn the buttons to activate the knowledge fang's ability that gives you access to the professor again, and you are basically locked into the bad ending because you get no more story progression. Reconnecting with the professor by using the knowledge fang gets you more lore dumps, which can be used to figure out more of what's going on and gain access to the alternate dimension and learn the secret of dropping the fangs in front of the pillars to spell the god's name. The alternate dimension has the information you need about purifying the fangs. Lots of steps to get you to the best ending. Somewhere we need another hint or two to push you to learn about the active abilities of the fangs... I'll think about that. You shouldn't necessarily need to activate the fang to get the information you need. Maybe you get a very weak connection when you pick up the fang, and that gives you enough information to help you get to the next stage if you need it. I don't know, still working on this part.

Okay, a few more ideas I'm working on. One is that because we can handle localization very easily using LLMs, we can actually make sure that the script in the temple is always in the language that the player has set. So if you change the in-game language, the characters in the background textures change. This is because the temple "wants" to be solved. Once you move into the alternate dimension, we have the scripts that explain how to purify the fangs be in a *different* language from the one the player has set. So like an English player might always get Russian in the background. Everything is still in the same Rhys script, but you never get it in the language you have it set to. We can even have the game file keep track of which languages it's been set to, so it always picks a different one if possible. So somebody who speaks both English and Russian and plays around with both maybe gets Mandarin as their language in the alternate dimension. That's just an idea for now.

I think the lore and story is coming together in my head. The temple is atop a small mountain deep in an unspecified jungle, and the top of the peak collapsing is observed by a nearby village. They investigate and eventually word gets out to the wider world about this temple, and that's when the player starts their journey as an archeological PhD student working for a famous professor. University budgets are tight but this is the opportunity of a lifetime, so the player character books their own travel and heads out on their own. The player sets up a satellite phone relay station at the top of the mountain, and then descends into the chasm where they are accosted by bandits who are also searching for the treasure. The player wakes up with no food, radio, notebook, weapons, climbing gear, or shoes. Their only option is to descend into the temple and hope they can find the bandits and bargain with them.

The player goes in, picks their way through some traps and minor enemies, eventually finds one of the bandits dead and gets an item, like their boots. They continue deeper into the temple, defeating bosses and puzzles, and over the course of the game grabs the rest of their gear. The climbing gear only lets them go down, because the ropes have to be anchored from the top, so the player can't escape the temple except by going down. Eventually the player recovers enough climbing gears to get to the bottom and recovers the four fangs, which gets them into the altar room at the bottom of the temple. Here they fight a final guardian, and if they defeat it they can place the fangs into the mouth of a statue that opens the final door and lets them out. The temple collapses behind them as they escape with the artifacts, but then the game ends with text explaining that they eventually go mad with power and build their own temple of Rhys and entomb themselves in it. Alternatively, the players may drop the Fangs in the altar room before they leave. This gets you the neutral ending, where the player escapes but the threat of Rhys still exists in the world, just buried under rubble.

If the player can get the knowledge fang activated, they receive lore dumps from the professor about how these temples seem to pop up in a bunch of different locations around the world, and every historian talks about how odd it is that the written script in the temple can be translated so easily even though the temple is ancient and whatever researcher may come from a totally different part of the world. There's also similarities in the symbols and religious practices of the cults across all different parts of the world, and everybody who has ended up with the Fangs has eventually gone mad with power and then disappeared.

The lore plus the scripts on the walls is enough to help players solve some extra puzzles and reveals some extra writing, which gives you the clues you need to get into the alternate dimension. The alternate dimension is necessary to access some of the optional items and areas in the game, and it is also where you find the text explaining the ways to purify each of the four Fangs. 

One last major optional item is your lost gun. The gun is a 6-shot weapon that actually has six shots, period, but it does way more damage than your slingshot (retrieved much earlier, infinite ammo). The gun is all but necessary to kill Rhys at the end of the game, and it can only be found by using the wealth fang to clone climbing gear to get even lower into the temple than you can usually go. We need some way to make sure you can't duplicate gun ammo with the wealth fang. Maybe just a 10-minute cooldown on the wealth fang, and all fang actives go on cooldown when you summon Rhys. 

With all four fangs gathered, you can choose to drop them in front of the correct pillars in the altar room to summon Rhys at the end. If you don't have all four Fangs purified, the snake god declares you unworthy and tries to kill you. You can fight and incapacitate the god, which allows you to escape. But if you bring the Fangs with you, you still get the bad ending regardless, or you can leave the Fangs in the temple when you leave to get the neutral ending. The game flips the default options here, where you now have to actively go and pick the fangs back up to escape with them. Simply running gives you the neutral ending, whereas without fighting Rhys you had to intentionally drop the fangs. This gives you a tendancy towards better endings by fighting Rhys, and it happens naturally because you have to drop them to summon him.

If you've purified all four Fangs, however, then after you have beaten Rhys in combat it offers you a final bargain. You can bow to it and become its vassal and the "final Emperor of Humanity". Choosing "yes" is the True Bad ending - you become the all-powerful mad ruler of the world and plunge the planet into darkness. Choosing not to become Rhys's pawn instead results in you killing it by stabbing it with the four Fangs, which destroys them and spits you out at the exit to the temple. The True Good ending of the game is you escape with your life and nothing else, but the world is saved.

Mmm, I actually do want a really good extra best ending where Rhys is slain but you get to keep the Fangs and use them to cure the world's ills. We'll have to think about what kind of puzzle is advanced enough to gatekeep an item that can be used in place of the fangs to kill Rhys. What if you just need to fire 6 shots into Rhys after incapacitating him? I kinda like that. Just have a line somewhere in the game that "enough bullets can kill anything." When you've incapacitated him, you can take the option to do a final blow with the four fangs to kill him and destroy the fangs. But you can instead just shoot him a bunch of times. This means that if you fight Rhys and defeat it *without using the gun*, you can get the game's best ending. Yeah, I think that's good.


## Script

For script, I've had a few ideas, but I think I'm settling on a set of characters that can be written top-to-bottom or right-to-left, depending on orientation. The odd numbered characters are consonants and the even numbered characters are vowels, and they can be chained together. Two consonants fit in a single line. I'll draw up a document with the script written out, but the hope is that you can write the word "Rhys" using a single unbroken line that looks like a snake, or if not that, then at least it definitely looks like an ancient script. The deity's full name is "Rhys'sthylceras," which is very snakelike in sound but also alien and Lovecraftian. Currently I have the image saved to script.xcf in this directory.

## Items

I don't like items that only have one use and that use is just to be a key for a door. We'll use actual small keys and large keys for that purpose, like small keys and boss keys in zelda. Climbing gear also technically works as a key but you can remove them and replace them to give access to different areas.

- Ratty Boots: Increase movespeed, gives some small protection on ground hazards
- Radio: Opens up contact with the professor. The professor will occasionally radio directly after you enter a room, and time is paused while the radio is on. This makes it hard/impossible for the player to glitch this. After a certain point the radio runs out of batteries.
- Whip: Standard indiana jones/castlevania whip. Hits enemies at short range. Can be freely aimed.
- Slingshot: Infinite projectiles, can be freely aimed, long range but less damage than whip
- Axe: Standard melee weapon, does good damage
- Notebook: enables keeping track of maps and other things
- Climbing Gear: I'm thinking 3 sets of climbing gear, they let you descend vertical shafts. One climbing gear goes all the way to the bottom of the shaft and hits every possible exit to the shaft along the way. This creates a map-wide puzzle system where you need to maintain access to all the floors. So first climbing gear gets you from floor 1 to floor 2, second one gets you from 2 to 3, then a path can be opened up that lets you go from floor 1 to either 2 or 3 along the same shaft, and now you can retrieve a climbing gear and use it to continue to floor 4, etc. We have a map where climbing gear can be managed quickly, and we keep track of which floors players can access and which climbing gears they can reach. That way players don't need to manually backtrack all over the place for hours just to move their gear
- Gun: optional item, required for the goodest ending. Has 6 shots, does 10 times the slingshot damage per hit. Cannot be refilled except with the wealth fang
- Explosive charge: item that can be placed and then remotely detonated. Can be retrieved from certain enemy remains. Used to solve puzzles and also do damage to enemies.
- The 4 Fangs, already detailed
- Quality Boots: enable dash, slightly better protection against ground hazards
- Grappling Hook: Can be free fired, grabs on to certain things and pulls you to them or pulls them to you depending on the item
- wooden dart: can be refilled from certain enemies, can be free-fired, and if caught on fire can be used to light distant objects on fire.

This list isn't exhaustive, it's just what I have so far. We could use a couple more weapons, and either those weapons should have added functionality or we could add a couple more items that can be used to solve puzzles. But even if all we have is this, that's legit pretty good. Remember that we don't want the game to go super long just to finish it, so maybe this is enough. We can have an axe, whip, and slingshot upgrade hidden in the alternate dimension that just add double damage. I don't want players to feel comfortable in this game. It should feel like you *can* solve the puzzles and defeat the enemies but it's always dangerous to fight.