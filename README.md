Kundalini
I made Kundalini as a 3D puzzle game in Godot 4.7 for a one-month game jam. It is built around the kundalini spiral: the player has a spirit snake coiled at the base of the spine, and every level awakens a new chakra that gives the snake a new ability. The look is inspired by Junji Ito, with a decrepit house that turns into spiraling black and white surfaces when you cross into the spirit world.

Concept
- There are two worlds, the real world and the spirit world, and I can switch between them at any time with E.
- The snake is non-combat. It pushes, pulls, eats small spirits, spits them back out, and coils around objects.
- Each level is a puzzle shaped by a demon, and solving it exorcises the demon and unlocks the next ability.
- Spirit orbs are only visible in the spirit world, and spitting only works there, so the two worlds constantly feed into each other.

Controls
- WASD to move, mouse to look
- Left click: extend the snake to push blocks
- Right click: bite and pull blocks, pull levers, eat spirit orbs (spirit world)
- Space: spit a spirit orb (spirit world)
- E: switch between the real world and the spirit world
- C: constrict (wrap the snake around a block, or press it while a block is in the snake's jaws)
- Esc: release the mouse

Levels
- Level 1, The House: the tutorial. Pushing blocks onto plates and moving through the house.
- Level 2: unlocks pull. The puzzles are built so pushing alone is never enough, with blocks jammed in nooks, stuck in corners, and sealed behind bars you can only reach through with the snake.
- Level 3, The Undercroft: unlocks eat and spit. Four wings each hold a great brazier that has to be lit with a spit shot, and any three of the four open the exit, so I can skip the wing I like least.
- Level 4, The Convergence: unlocks phase walk, where some walls exist in only one world. A real wing and a mirrored spirit wing meet in the middle, and both hearts are needed to open the exit.
- Level 5, The Crown: unlocks constrict and is the final level. It is one interlocked machine where every area produces something another area needs, and the exit needs three conditions to be true at the same time.

Mechanics I built
- Spirit world shaders: when the level loads, every mesh gets a spiral shader that keeps its original color, and a screen overlay builds distortion the longer I stay in the spirit world.
- Phase walls and phase blocks: objects that exist in only one world. A wall can only form when its space is empty, so a block left in a doorway wedges it open in both worlds. Switching worlds is refused if a wall or phase block would appear on top of the player, so the player can never get stuck inside one.
- World-bound pressure plates: plates that only count while the player is in their world.
- Cord blocks: blocks on a cord that wind back to where they started. A linked door opens in proportion to how far the cord is pulled, so as the cord winds back the door slides shut again. Constrict holds a cord in place but tethers the player to it, and anything left in the cord's path jams it.
- Braziers, orb wells, breakable walls, levers, and reset shrines that put a room's blocks back where they started.
- Procedural decoration: house_decor.gd adds stains, debris, wall grime, and light flicker, and house_props.gd turns plain boxes into detailed furniture at runtime.
- Doors never close on the player. A closing door nudges the player out to the side they are standing on.

Project layout
- scenes/: one scene per level (house.tscn, level2.tscn to level5.tscn), plus player.tscn and pushable_block.tscn
- scripts/: GDScript for the player, snake, game manager, and every puzzle piece
- shaders/: the spirit world, spiral surface, spiral object, and spirit portal shaders
- GameManager is an autoload that tracks unlocked abilities between levels, shows notifications, and handles level transitions.

Running it
- Open the folder in Godot 4.7 (Forward Plus renderer) and press F5. The main scene is scenes/house.tscn.
- To test a later level directly, open its scene and press F6. The game manager unlocks the abilities that level expects automatically.
