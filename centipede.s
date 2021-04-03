##################################################################### 
# 
# CSC258H Winter 2021 Assembly Final Project 
# University of Toronto, St. George 
# 
# Student: Mohit Bawa, 1006509574
# 
# Bitmap Display Configuration: 
# - Unit width in pixels: 8    
# - Unit height in pixels: 8 
# - Display width in pixels: 256 
# - Display height in pixels: 256 
# - Base Address for Display: 0x10008000 ($gp) 
# 
# Which milestone is reached in this submission? 
# (See the project handout for descriptions of the milestones) 
# - Milestone 1
# - Milestone 2
# - Milestone 3
# - Partially completed Milestone 4 (increasing level difficulty)
# 
# Which approved additional features have been implemented? 
# (See the project handout for the list of additional features)
# - N/A 
#
# Any additional information that the TA needs to know: 
# - I implemented a system for the flea to randomly generate mushrooms as it falls
# 
#####################################################################

.data
	displayAddress: .word 0x10008000
	playGame: .word -1
	numMushrooms: .word 2
	fleaRate: .word 128 # The chance of a flea spawning on each loop is 1/fleaRate
	
	bugLocation: .word 911
	bugHealth: .word 1
	
	centipedeLocation: .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 ,13 ,14, 15
	centipedeDirection: .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	centipedeLength: .word 10
	centipedeHealth: .word 3
	turnFlag: .word -1
	
	bulletLocation: .word -1
	behindBullet: .space 4
	
	fleaLocation: .word -1
	behindFlea: .space 4
	
	# Various Colours (The only condition is that mushrooms must have a unique colour code)
	backgroundColour: .word 0x000000
	mushroomColour: .word 0x7d7dff
	bugColour: .word 0xffffff
	bulletColour: .word 0xffffff
	fleaColour: .word 0xff0000
	centipedeColour: .word 0x48b069
	centipedeHeadColour: .word 0x69ff98
	byeColour: .word 0xf8ff24
	
.text

#####################################################################
# Start / Restart the game at this location

	jal init_display
	jal gen_mushrooms
	jal init_bug
	
START_MENU_LOOP:
	lw $t0, playGame
	bgtz $t0, GAME_LOOP
	
	jal check_keystroke
	
	li $v0, 32
	li $a0, 50
	syscall
	
	j START_MENU_LOOP

NEXT_LEVEL:
	la $t0, numMushrooms
	lw $t1, numMushrooms
	add $t1, $t1, $t1
	
	ble $t1, 672, SET_NUM_MUSH
		li $t1, 672
	SET_NUM_MUSH:
	sw $t1, 0($t0)
	
	la $t0, fleaRate
	lw $t1, fleaRate
	addi $t1, $t1, -16
	
	bgtz $t1, SET_RATE
		li $t1, 1
	SET_RATE:
	sw $t1, 0($t0)
	
	la $t0, centipedeLength
	lw $t1, centipedeLength
	addi $t1, $t1, 2
	
	ble $t1, 16, SET_LEN
		li $t1, 16
	SET_LEN:
	sw $t1, 0($t0)
	
	jal init_display
	jal gen_mushrooms
	jal init_centipede
	jal init_bug
	jal init_bullet
	jal init_flea
	jal init_flag
	
	j GAME_LOOP

RESTART:
	jal init_display
	jal draw_bye
	li $v0, 32 # sleep
	li $a0, 2000
	syscall
	
	la $t0, numMushrooms
	li $t1, 2
	sw $t1, 0($t0)
	
	la $t0, fleaRate
	li $t1, 128
	sw $t1, 0($t0)
	
	la $t0, centipedeLength
	li $t1, 10
	sw $t1, 0($t0)
	
	jal init_display
	jal gen_mushrooms
	jal init_centipede
	jal init_bug
	jal init_bullet
	jal init_flea
	jal init_flag
	
	la $t0, playGame
	li $t1, -1
	sw $t1, 0($t0) 
	
	j START_MENU_LOOP

#####################################################################
# Begin the game loop

GAME_LOOP:
	
	jal disp_bullet
	
	jal handle_bullet_collisions
	lw $t0, centipedeHealth
	ble $t0, 0, NEXT_LEVEL
	
	jal disp_centipede	
	
	jal handle_bullet_collisions
	lw $t0, centipedeHealth
	ble $t0, 0, NEXT_LEVEL
	
	jal handle_bug_collisions
	lw $t1, bugHealth
	beq $t1, 0, RESTART
	
	jal disp_flea
	
	jal handle_bullet_collisions
	lw $t0, centipedeHealth
	ble $t0, 0, NEXT_LEVEL
	
	jal handle_bug_collisions
	lw $t1, bugHealth
	beq $t1, 0, RESTART
	
	jal spawn_flea
	
	jal handle_bullet_collisions
	lw $t0, centipedeHealth
	ble $t0, 0, NEXT_LEVEL
	
	jal handle_bug_collisions
	lw $t1, bugHealth
	beq $t1, 0, RESTART
	
	jal check_keystroke
	
	jal handle_bug_collisions
	lw $t1, bugHealth
	beq $t1, 0, RESTART
	
	li $v0, 32
	li $a0, 40
	syscall
	
	j GAME_LOOP

Exit:
      li $v0, 10 # terminate the program
      syscall

######################################################################
# The following function(s) handle centipede movement

# function to display a static centipede
disp_centipede:
	# move stack pointer a word and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $a3, centipedeLength	 # load a3 with the loop count
	la $a1, centipedeLocation # load the address of the array into $a1
	la $a2, centipedeDirection # load the address of the array into $a2

	arr_loop:	#iterate over the loops elements to draw each body in the centiped
		lw $t1, 0($a1)		 # load a word from the centipedLocation array into $t1
		lw $t5, 0($a2)		 # load a word from the centipedDirection  array into $t5
		
		lw $t2, displayAddress	# $t2 stores the base address for display
		
		lw $t3, centipedeHeadColour
		beq $a3, 1, HEAD
			lw  $t3, centipedeColour		# t3 stores the colour colour for this segment
		HEAD:
		
		bltz $t5 MOVE_LEFT
		bgtz $t5 MOVE_RIGHT
	
		MOVE_LEFT:
			addi $t6, $zero, 32	# Checks if the segment is at the left border of the display
			div $t1, $t6
			mfhi $t9
			beq $t9, $zero, MOVE_VERTICAL	# Moves down if it is at the left border
			j MOVE_HORIZONTAL
		
		MOVE_RIGHT:
			addi $t6, $zero, 32	# checks if segment is at the right border
			addi $t9, $t1, 1
			div $t9, $t6
			mfhi $t9
			beq $t9, $zero, MOVE_VERTICAL	 # Moves down if it is at the right border
			j MOVE_HORIZONTAL
		
		MOVE_HORIZONTAL:
			add $t9, $t1, $t5	# t9 stores the location of the pixel to the side
			sll $t4, $t9, 2
			add $t4, $t2, $t4	# t4 stores the address of the pixel to the side
			
			lw $t7, turnFlag
			beq $t9, $t7, MOVE_VERTICAL
			
			lw $t7, 0($t4)		# t7 stores the current colour of the pixel to the side
			lw $t6, mushroomColour	
			beq $t7, $t6, SET_TURN_FLAG	# Checks if there is a mushroom to the side and moves down if so
		
			lw $t6, fleaLocation
			bne $t9, $t6, DONE_CHECK_H # Checks if there is not a flea to the side
				lw $t6, behindFlea	# If there is a flea, we execute these lines
				lw $t8, mushroomColour
				beq $t6, $t8, SET_TURN_FLAG	# if there is a mushroom behind the flea, we move down
			DONE_CHECK_H:	# If there's no flea to the side, the centipede finally moves
			sw $t3, 0($t4)	# Sets the colour of the pixel
			sw $t9, 0($a1)	# Saves the new location in memory
			j END_MOVE		
		
		SET_TURN_FLAG:
			la $s1, turnFlag
			sw $t9, 0($s1)
			j MOVE_VERTICAL
		
		MOVE_VERTICAL:
			bge $t1, 896, CHANGE_DIRECTION	# checks if segment is at the bottom of the display and skips move down if so
			
			addi $t9, $t1, 32	# t9 stores the location 1 unit directly below t1
			sll $t4,$t9, 2
			add $t4, $t2, $t4
			sw $t3, 0($t4)		# Sets the correct segment colour on the display
			sw $t9, 0($a1)		# Updates the segment location in memory
	
			lw $t6, fleaLocation
			bne $t9, $t6, DONE_CHECK_V 	# Checks if there is not a flea below
				la $t6, behindFlea		# If there is a flea, we execute these lines
				lw $t7, backgroundColour
				sw $t7, 0($t6)			# Removes any mushroom potentially behind the flea
			DONE_CHECK_V:
	
		CHANGE_DIRECTION:				# changes the direction of the segment based on current direction
			addi $t8, $zero, -1
			bgtz $t5 TURN_LEFT
				addi $t8, $zero, 1
			TURN_LEFT:
			sw $t8, 0($a2)
	
		END_MOVE:
		
		lw $t7, centipedeLength
		beq $a3, $t7, DELETE_TAIL
			j KEEP_TAIL
	
		DELETE_TAIL:				# changes the previous location to background iff this is a tail segment
			lw $t7, backgroundColour 	# $t7 stores the backgroundColour code
			sll $t4,$t1, 2
			add $t4, $t2, $t4
			sw $t7, 0($t4) # Set the old location to background colour
	
		KEEP_TAIL:	# Do nothing, leave the tail as is
	
		addi $a1, $a1, 4	 	# increment $a1 by one, to point to the next element in the array
		addi $a2, $a2, 4		# increment $a2 by one, to point to the next element in the array
		addi $a3, $a3, -1	 # decrement $a3 by 1
	
	bne $a3, $zero, arr_loop
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

#####################################################################
# The following function(s) handle bullet movement

# function to display and update the location of the bullet
disp_bullet:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, displayAddress
	lw $t1, bulletLocation	# t1 stores current location
	
	bltz $t1, SKIP_BULL	# t1 < 0 -> no bullet on screen -> we don't display or update anything
	
	addi $t2, $t1, -32	# t2 stores new location
	
	sll $t3, $t1, 2
	add $t3, $t3, $t0	# t3 stores address of pixel of current location
	
	bltz $t2, RESET_BULL	# t2 < 0 -> bullet reached top of screen -> reset bullet to inital state
	
	sll $t4, $t2, 2
	add $t4, $t4, $t0	# t4 stores address of pixel of new location
	
	la $t5, bulletLocation
	sw $t2, 0($t5)		# update bullet location
	
	la $t5, behindBullet
	lw $t6, 0($t4)
	sw $t6, 0($t5)		# update behind bullet
	
	lw $t5, bulletColour
	sw $t5, 0($t4)		# paint the new bullet
	
	bge $t1, 896, SKIP_BULL
	lw $t5, backgroundColour
	sw $t5, 0($t3)		# clear the old bullet
	
	j SKIP_BULL
	
	RESET_BULL:
		jal reset_bullet
		
	SKIP_BULL:
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

#####################################################################
# The following function(s) handle flea movement

# function that randomly decides when and where to spawn a flea
spawn_flea:
	# move stack pointer a word and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, displayAddress
	lw $t1, fleaLocation
	bgez $t1, SKIP_SPAWN		# if there is already a flea on screen, don't spawn
	
	lw $a2, fleaRate			# chance of flea spawning is 1/fleaRate everytime this function is called
	
	li $v0, 42
	li $a0, 0
	addi $a1, $a2, 0
	syscall
	
	bne $a0, 0, SKIP_SPAWN		# generate rand number and only spawn if it is 0
	
	li $v0, 42
	li $a0, 0
	li $a1, 32
	syscall				# generate random location in top row to spawn at
	
	addi $t1, $a0, 0
	
	la $t2, fleaLocation
	sw $t1, 0($t2)			# updates location
	
	sll $t2, $t1, 2
	add $t2, $t2, $t0	# t2 stores address of flea location
	
	lw $t3, 0($t2)
	la $t4, behindFlea
	sw $t3, 0($t4)			# updates behind flea
	
	lw $t4, fleaColour
	sw $t4, 0($t2)			# paints the flea
		
	SKIP_SPAWN:
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

# function to display and update the location of the bullet
disp_flea:
	# move stack pointer a word and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, displayAddress
	lw $t1, fleaLocation	# t1 stores current location
	
	bltz $t1, SKIP_FLEA
	
	addi $t2, $t1, 32	# t2 stores new location
	
	sll $t3, $t1, 2
	add $t3, $t3, $t0	# t3 stores address of current location
	
	lw $t7, behindFlea
	lw $t8, mushroomColour
	beq $t7, $t8, TRAIL_SET			# if there is a mushroom behind flea, set trail = mushroomColour
		lw $t8, backgroundColour		# otherwise, randomly whether the flea should make a mushroom
		
		lw $a2, centipedeLength	 # load a2 with the loop count
		la $a1, centipedeLocation # load the address of the array into $a1
	
		flea_segment_loop:
			lw $t7, 0($a1)		# load a word from the centipedLocation array into $t7
			beq $t1, $t7, TRAIL_SET
			addi $a1, $a1, 4		# increment $a1 by one, to point to the next element in the array
			addi $a2, $a2, -1	# decrement $a2 by 1		
		bne $a2, $zero, flea_segment_loop
		
		li $v0, 42
		li $a0, 0
		li $a1, 5
		syscall
		
		bne $a0, 0, TRAIL_SET
		lw $t8, mushroomColour
	TRAIL_SET:
	
	bge $t2, 928, RESET_FLEA		# the flea reached the bottom, so reset it
	
	sll $t4, $t2, 2
	add $t4, $t4, $t0	# t4 stores address of new location
	
	la $t5, fleaLocation
	sw $t2, 0($t5)		# update flea location
	
	la $t5, behindFlea
	lw $t6, 0($t4)
	sw $t6, 0($t5)		# update behind flea
	
	lw $t5, fleaColour
	sw $t5, 0($t4)		# paint the flea
	
	#lw $t5, backgroundColour
	sw $t8, 0($t3)		# paint the trail based on what was underneath and random mushroom gen
	
	j SKIP_FLEA
	
	RESET_FLEA:
		jal reset_flea
	
	SKIP_FLEA:
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

######################################################################
# The following function(s) handle various types of collisions

# function that resets (or reloads) the bullet
reset_bullet:
	# move stack pointer a word and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# move stack pointer a work and push s0 onto it
	addi $sp, $sp, -4
	sw $s0, 0($sp)
	
	# move stack pointer a work and push s1 onto it
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	
	# Clear the bullet on the display
	lw $s0, bulletLocation
	sll $s0, $s0, 2
	lw $s1, displayAddress
	add $s0, $s0, $s1
	lw $s1, backgroundColour
	sw $s1, 0($s0)
	
	# Change bullet location to -1 indicating no bullet on the screen
	la $s0, bulletLocation
	addi, $s1, $zero, -1
	sw $s1, 0($s0)		
	
	# pop s1 off the stack and move the stack pointer
	lw $s1, 0($sp)
	addi $sp, $sp, 4
	
	# pop s0 off the stack and move the stack pointer
	lw $s0, 0($sp)
	addi $sp, $sp, 4
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

# function that resets the flea to its initial, off-screen state
reset_flea:
	# move stack pointer a word and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# move stack pointer a work and push s0 onto it
	addi $sp, $sp, -4
	sw $s0, 0($sp)
	
	# move stack pointer a work and push s1 onto it
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	
	# Clear the flea on the display
	lw $s0, fleaLocation
	sll $s0, $s0, 2
	lw $s1, displayAddress
	add $s0, $s0, $s1
	lw $s1, backgroundColour
	sw $s1, 0($s0)
	
	# Change flea location to -1 indicating no flea on the screen
	la $s0, fleaLocation
	addi, $s1, $zero, -1
	sw $s1, 0($s0)
	
	# pop s1 off the stack and move the stack pointer
	lw $s1, 0($sp)
	addi $sp, $sp, 4
	
	# pop s0 off the stack and move the stack pointer
	lw $s0, 0($sp)
	addi $sp, $sp, 4
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

handle_bug_collisions:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, bugLocation
	
	lw $a2, centipedeLength	 # load a2 with the loop count
	la $a1, centipedeLocation # load the address of the array into $a1
	
	bug_segment_loop:
		lw $t1, 0($a1)		 		# load a word from the centipedLocation array into $t1
		beq $t0, $t1, BUG_COLLISION
		addi $a1, $a1, 4		# increment $a2 by one, to point to the next element in the array
		addi $a2, $a2, -1	 # decrement $a3 by 1		
	bne $a2, $zero, bug_segment_loop
	
	lw $t1, fleaLocation
	beq $t0, $t1, BUG_COLLISION
	
	j STAYIN_ALIVE
	
	BUG_COLLISION:
		la $t1, bugHealth
		sw $zero, 0($t1)
	
	STAYIN_ALIVE:
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

handle_bullet_collisions:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, bulletLocation	# t0 refers to the location of the bullet		
	
	lw $a2, centipedeLength	 # load a2 with the loop count
	la $a1, centipedeLocation # load the address of the array into $a1
	
	bullet_segment_loop:
		lw $t1, 0($a1)		 		# load a word from the centipedLocation array into $t1
		beq $t0, $t1, BULL_CENT_COLLISION
		addi $a1, $a1, 4		# increment $a2 by one, to point to the next element in the array
		addi $a2, $a2, -1	 # decrement $a3 by 1		
	bne $a2, $zero, bullet_segment_loop
	
	lw $t1, behindBullet
	lw $t2, mushroomColour
	beq $t1, $t2, BULL_MUSH_COLLISION
	
	lw $t1, fleaLocation
	beq $t0, $t1, BULL_FLEA_COLLISION
	
	j NO_COLLISION
	
	BULL_CENT_COLLISION:
		la $t1, centipedeHealth
		lw $t2, centipedeHealth
		addi $t2, $t2, -1
		sw $t2, 0($t1)			# Update the centipede's health accordingly
	
		jal reset_bullet			# Reset the bullet
		j NO_COLLISION
	
	BULL_MUSH_COLLISION:			# mushroom is hit	
		jal reset_bullet
		j NO_COLLISION 
	
	BULL_FLEA_COLLISION:
		jal reset_bullet
		jal reset_flea
		j NO_COLLISION
	
	NO_COLLISION:
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

######################################################################
# The following function(s) perform initialization features

# function that initializes bitmap display to backgroundColour
init_display:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	add $t0, $zero, $zero
	INIT_DISPLAY:
		sll $t1, $t0, 2
		lw $t2, displayAddress
		add $t1, $t1, $t2
		lw $t2, backgroundColour
		sw $t2, 0($t1)
		addi $t0, $t0, 1
	bne $t0, 0x400, INIT_DISPLAY
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
# function that generates and paints random mushrooms
gen_mushrooms:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	li $v0, 42
	li $a0, 0
	lw $a1, numMushrooms
	syscall
	
	addi $t0, $a0, 0
	
	INIT_MUSH:
		li $v0, 42
		li $a0, 0
		li $a1, 896
		syscall					# Generates a random location to colour mushroom
		
		lw $t3, centipedeLength
		
		blt $a0, $t3, OUT_OF_BOUNDS		# Ensures the centipede's initial location is clear

		sll $a0, $a0, 2				# Paints the mushroom
		lw $t1, displayAddress
		add $a0, $t1, $a0
		lw $t1, mushroomColour
		sw $t1, 0($a0)
	
		OUT_OF_BOUNDS:				
	
		addi $t0, $t0, -1			# Decrements the loop counter t0
	bgtz $t0, INIT_MUSH
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

# function that initializes the centipede
init_centipede:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t4, centipedeLength
	
	addi $t0, $zero, 0
	addi $t1, $zero, 1
	la $a1, centipedeLocation
	la $a2, centipedeDirection
	INIT_CENT:
		sw $t0, 0($a1)
		sw $t1, 0($a2)	
		addi $a1, $a1, 4
		addi $a2, $a2, 4
		addi $t0, $t0, 1
	bne $t0, $t4, INIT_CENT

	la $t2, centipedeHealth
	li $t3, 3
	sw $t3, 0($t2)
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

# function that initializes bug
init_bug:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, bugLocation
	li $t1, 911
	sw $t1, 0($t0)
	
	lw $t0, displayAddress
	sll $t2, $t1, 2
	add $t2, $t2, $t0
	lw $t3, bugColour
	sw $t3, 0($t2)

	la $t0, bugHealth
	li $t1, 1
	sw $t1, 0($t0)
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
# function that initializes bullet
init_bullet:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, bulletLocation
	li $t1, -1
	sw $t1, 0($t0)
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

# function that initializes flea
init_flea:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, fleaLocation
	li $t1, -1
	sw $t1, 0($t0)
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

# function that initializes turnFlag
init_flag:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	la $t0, turnFlag
	li $t1, -1
	sw $t1, 0($t0)
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

######################################################################
# The following function(s) handle all keyboard input  
  
# function to detect any keystroke
check_keystroke:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t8, 0xffff0000
	beq $t8, 1, get_keyboard_input # if key is pressed, jump to get this key
	addi $t8, $zero, 0
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
# function to get the input key
get_keyboard_input:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t2, 0xffff0004
	addi $v0, $zero, 0	#default case
	beq $t2, 0x6A, respond_to_j
	beq $t2, 0x6B, respond_to_k
	beq $t2, 0x78, respond_to_x
	beq $t2, 0x73, respond_to_s
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
# Call back function of j key
respond_to_j:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, bugLocation	# load the address of buglocation from memory
	lw $t1, 0($t0)		# load the bug location itself in t1
	
	lw $t2, displayAddress	# $t2 stores the base address for display
	lw $t3, backgroundColour	# $t3 stores the black colour code
	
	sll $t4,$t1, 2		# $t4 the bias of the old buglocation
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sw $t3, 0($t4)		# paint the first (top-left) unit white.
	
	beq $t1, 896, skip_movement # prevent the bug from getting out of the canvas
	addi $t1, $t1, -1	# move the bug one location to the left
	
	skip_movement:
	
	sw $t1, 0($t0)		# save the bug location

	lw $t3, bugColour	# $t3 stores the white colour code
	
	sll $t4,$t1, 2
	add $t4, $t2, $t4
	sw $t3, 0($t4)		# paint the first (top-left) unit white.
	
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

# Call back function of k key
respond_to_k:
	# move stack pointer a word and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, bugLocation	# load the address of buglocation from memory
	lw $t1, 0($t0)		# load the bug location itself in t1
	
	lw $t2, displayAddress	# $t2 stores the base address for display
	lw $t3, backgroundColour	# $t3 stores the black colour code
	
	sll $t4,$t1, 2		# $t4 the bias of the old buglocation
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sw $t3, 0($t4)		# paint the block with black
	
	beq $t1, 927, skip_movement2 #prevent the bug from getting out of the canvas
	addi $t1, $t1, 1	# move the bug one location to the right
	
	skip_movement2:
	
	sw $t1, 0($t0)		# save the bug location

	lw $t3, bugColour	# $t3 stores the white colour code
	
	sll $t4,$t1, 2
	add $t4, $t2, $t4
	sw $t3, 0($t4)		# paint the block with white
	
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
respond_to_x:
	# move stack pointer a word and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t3, playGame
	bltz $t3, SKIP_SHOT		# don't allow shooting if game has not begun
	
	lw $t0, bulletLocation
	bgez $t0, SKIP_SHOT		# don't allow shooting if there is already a bullet on-screen
		la $t1, bulletLocation
		lw $t2, bugLocation
		sw $t2, 0($t1)
		la $t1, behindBullet
		lw $t2, backgroundColour
		sw $t2, 0($t1)
		
	SKIP_SHOT:
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
respond_to_s:
	# move stack pointer a word and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, playGame
	li $t1, 1
	sw $t1, 0($t0)
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

delay:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	li $a2, 10000
	addi $a2, $a2, -1
	bgtz $a2, delay
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

#########################################################################
# User Interface Enhancements

# function that draws "byE!" on the screen
draw_bye:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# draw b
	lw $t0, displayAddress
	addi $t0, $t0, 1576		# jumps to pixel 394, from which every pixel is drawn
	lw $t1, byeColour
	sw $t1, 128($t0)
	sw $t1, 256($t0)
	sw $t1, 384($t0)
	sw $t1, 388($t0)
	sw $t1, 392($t0)
	sw $t1, 520($t0)
	sw $t1, 512($t0)
	sw $t1, 640($t0)
	sw $t1, 644($t0)
	sw $t1, 648($t0)
	#draw y
	sw $t1, 400($t0)
	sw $t1, 528($t0)
	sw $t1, 656($t0)
	sw $t1, 408($t0)
	sw $t1, 536($t0)
	sw $t1, 660($t0)
	sw $t1, 664($t0)
	sw $t1, 792($t0)
	sw $t1, 920($t0)
	sw $t1, 916($t0)
	sw $t1, 912($t0)
	#draw E
	sw $t1, 672($t0)
	sw $t1, 676($t0)
	sw $t1, 680($t0)
	sw $t1, 544($t0)
	sw $t1, 416($t0)
	sw $t1, 420($t0)
	sw $t1, 424($t0)
	sw $t1, 288($t0)
	sw $t1, 160($t0)
	sw $t1, 164($t0)
	sw $t1, 168($t0)
	#draw !
	sw $t1, 176($t0)
	sw $t1, 304($t0)
	sw $t1, 432($t0)
	sw $t1, 688($t0)
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
