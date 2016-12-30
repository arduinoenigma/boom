;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; boom.asm
;
; Tank battle game for the Arduino.
;
; Dec 20, 2016 - Jim Shortz (hackaday.io/jimshortz)
;
; 2017 Hackaday 1KB challenge entry
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.equ	DEBUG = 0
.equ    SMOOTH_TERRAIN = 1  ; 30 extra bytes
.equ    FLASH_TANK = 0      ; 24 extra bytes

.include "m328Pdef.inc"
.include "macros.inc"

; Colors
.equ    CURSOR_COLOR =      0xffff
.equ    BUTTON_COLOR =      0xffff
.equ    PLAYER_1_COLOR =    0x001f
.equ    PLAYER_2_COLOR =    0xf800
.equ    SKY_COLOR =         0x0000
.equ    EARTH_COLOR =       0x07e0

; Simulation constants
.equ	SCALE =			6		; Scaling factor (in bits)
.equ	FRATE =			4		; Frames per second (in bits)
.equ	MAX_SCORE =		3		; Number of points you play to

; Graphics sizes
.equ	SCREEN_WIDTH =	320
.equ	SCREEN_HEIGHT =	240
.equ	TANK_WIDTH =	30
.equ	TANK_HEIGHT =	7
.equ	TURR_WIDTH =	10
.equ	TURR_HEIGHT =	7
.equ	BUTTON_WIDTH =	32
.equ	BUTTON_HEIGHT = TANK_HEIGHT + TURR_HEIGHT + 4
.equ	CURSOR_WIDTH =	10
.equ	CURSOR_HEIGHT =	CURSOR_WIDTH
.equ	TALLY_WIDTH	 =	6
.equ	TALLY_HEIGHT =	16
.equ    TERRAIN_WIDTH = 64
.equ    AVG_WINDOW =    16

.if SMOOTH_TERRAIN
.equ    PLAYER_1_X   =  8
.else
.equ    PLAYER_1_X   =  16
.endif
.equ    PLAYER_2_X   =  192+PLAYER_1_X

; Vector structure
.equ    VECT_X_L    =   0
.equ    VECT_X_H    =   1
.equ    VECT_Y_L    =   2
.equ    VECT_Y_H    =   3
.equ    VECTOR_SIZE =   4

; Rectangle structure
.equ	RECT_LEFT_L =	0
.equ	RECT_LEFT_H =	1
.equ	RECT_TOP_L =	2
.equ	RECT_TOP_H =	3
.equ	RECT_WIDTH_L =	4
.equ	RECT_WIDTH_H =	5
.equ	RECT_HEIGHT_L = 6
.equ	RECT_HEIGHT_H = 7
.equ	RECT_SIZE	=	8

    .dseg
    .org 0x200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Global data
; Everything in this section is 1) global and 2) needs its value 
; preserved from turn to turn.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    .def    rseed=r21               ; Random number generator seed
    .def    player=r7               ; Current player

terrain:    .byte   SCREEN_WIDTH    ; Height of terrain for each X 
            .byte   TERRAIN_WIDTH   ; Padding

.org	0x400
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Player data section
; Everthing here is either 1) player-specific, or 2) has its value
; reset on every turn.  Even though variables in category #2 are global
; we store them in the per-player section so we don't have to keep
; changing zl and yl to point at the global section.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

player1:

; Initialized data. These are copied from player_init to here on every turn
firing_pos: .byte   VECTOR_SIZE
cursor:     .byte   VECTOR_SIZE     ; Current position of aiming cursor
button:     .byte   RECT_SIZE
turr:       .byte   RECT_SIZE
tank:       .byte   RECT_SIZE
tally1:     .byte   RECT_SIZE
tally2:     .byte   RECT_SIZE
origin:     .byte   VECTOR_SIZE     ; 0,0
acc:        .byte   VECTOR_SIZE     ; Gravity acceleration vector

; Uninitialized data.
vel:        .byte   VECTOR_SIZE     ; Velocity of ball
pos:        .byte   VECTOR_SIZE     ; Position of ball (physical)
scn:        .byte   VECTOR_SIZE     ; Position of ball (screen)
touch:      .byte   VECTOR_SIZE     ; last position of touch screen
touch_z:    .byte   2
score:      .byte   1

.org    0x500
player2:
; This section contains copies of all data from player1.
.org    0x600

    .cseg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Startup code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
start:
    ; No interrupts please    
    cli

    ; Set up stack pointer
    loadyd RAMEND
    out SPL, yl
    out	SPH, yh

    ; Initialize random seed
    ldi     rseed, 1

    ; Initialize hardware
    dbgcall	txinit
    rcall	tft_init

new_game:
    ; Reset scores and player
    ldi     r16, 2          ; Actually, number of rects to draw
    ldi     yl, low(score)
    ldi     yh, high(player1)
    st      y, r16
    ldi     yh, high(player2)
    st      y, r16
    mov     player, yh         ; Storage location for current player
    rcall   gen_terrain

ready:
    rcall   draw_terrain

    ; Switch players
    ldi     yl, 1
    eor     player, yl
    mov     yh, player
        
    ; Draw the fire button
    ldi     yl, low(button)
    ldi     r26, low(BUTTON_COLOR)
    ldi     r27, high(BUTTON_COLOR)
    rcall   draw_rect

    ; Draw players
    ldi     yh, high(player1)
    rcall   draw_player
    inc     yh
    rcall   draw_player
    mov     yh, player

aim:
    ; Draw cursor
    ldi     yl, low(cursor)
    ldi		r26, low(CURSOR_COLOR)
    ldi		r27, high(CURSOR_COLOR)
    rcall	draw_cursor

aim1:
    ; Wait for touch input
    rcall   rand
    ldi     yl, low(touch)
    rcall	touch_read
    brne	aim1

    ; Screen pressed - erase old cursor
    ldi     yl, low(cursor)
    ldi		r26, low(SKY_COLOR)
    ldi		r27, high(SKY_COLOR)
    rcall	draw_cursor

    ; Was the fire button clicked?
    mov     zh, yh
    ldi     zl, low(touch)
    ldi     yl, low(button)
    rcall	hit_test
    brpl	fire

    ; Button not pressed - move cursor
    ldi     yl, low(cursor)
    ldi     zl, low(touch)
    rcall   copy_vec
    rjmp	aim

fire:
    ; Erase fire button
    ldi     yl, low(button)
    rcall	erase_rect
    rcall   draw_player

    ; vel := cursor
    ldi     zl, low(cursor)
    ldi     yl, low(vel)
    rcall   copy_vec

    ; vel -= fpos
    ldi     yl, low(vel)
    ldi     zl, low(firing_pos)
    rcall   subtract_vec

    ; pos = fpos*SCALE
    ldi     yl, low(pos)
    ldi     zl, low(firing_pos)
    rcall   scale_vec

    dbgcall	print_all		

fire1:
    ; vel += acc
    ldi     zl, low(acc)
    ldi     yl, low(vel)
    rcall   add_vec

    ; pos += vel
    rcall   add_vec

    ; scn = descale(pos)
    rcall   descale_vec
    dbgcall	print_all

    ; Ideally we would check overall bounds here, but the ball
    ; doesn't fly fast enough for weirdness to happen.

    ; Get terrain[x]
    ldi     yl, low(scn)
    ld      xl, y+
    ld      xh, y+
    ori     xh, high(terrain)
    ld      r0, x

    ; Did we hit terrain?
    ld      r20, y+
    cp      r20, r0
    brlo    ready

    ; Did we hit a player?
    ldi     yh, high(player1)
    rcall   hit_player
    brpl    hit
    inc     yh
    rcall   hit_player
    brpl    hit
    mov     yh, player

    ; Draw the ball
    ldi     yl, low(scn)
    rcall	draw_point
    rcall	delay50
    rjmp	fire1

hit:
.if FLASH_TANK
    ldi     r17, 8
hit1:
    ldi     yl, low(button)
    rcall   draw_player
    rcall   delay50
    rcall   erase_player
    rcall   delay50
    dec     r17
    brne    hit1
.endif

    ; Increase score of other player
    ldi     r16, 1
    eor     yh, r16
    ldi     yl, low(score)
    ld      r16, y
    inc     r16
    st      y, r16

    ; Is the game over?
    cpi     r16, 2+MAX_SCORE
    brne    hit2
    rjmp    new_game

hit2:
    ; Reset terrain and continue game
    rcall   gen_terrain
    rjmp    ready

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; gen_terrain
;
; Randomly generates terrain
;
; Outputs:
;   terrain - Array of random heights
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gen_terrain:
    ; Generate plateaus of TERRAIN_WIDTH - enough to fill the screen
    ldi     r17, SCREEN_WIDTH/TERRAIN_WIDTH+1
    loadyd  terrain

gen_terrain1:
    ; Generate a random height for this plateau
    rcall   rand
    andi    r18, 127        ; Limit to 127
    ldi     r16, TERRAIN_WIDTH

gen_terrain2:
    st      y+, r18
    dec     r16
    brne    gen_terrain2

    dec     r17
    brne    gen_terrain1

.if SMOOTH_TERRAIN
    ldi     r18, AVG_WINDOW
avg_terrain1:
    loadyd  terrain
;    add     yl, r18
avg_terrain2:
    ld      r0, y
    ldd     r1, y+1
    add     r0, r1
    lsr     r0
    st      y+, r0
    cpi     yl, low(terrain+SCREEN_WIDTH)
    brne    avg_terrain2
    cpi     yh, high(terrain+SCREEN_WIDTH)
    brne    avg_terrain2
    dec     r18
    brne    avg_terrain1
.endif

    ; Position players on terrain
    ldi     yh, high(player1)
    ldi     xl, PLAYER_1_X
    rcall   setup_player

    ldi     yh, high(player2)
    ldi     xl, PLAYER_2_X
    rjmp    setup_player

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; setup_player
;
; Positions player's rectangles on the newly generated terrain
;
; Inputs:
;   yh - player
;   xl - Starting X position
;
; Outputs:
;   firing_pos, button, tank, turr adjusted to correct positions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
setup_player:
    ; Copy data from ROM
    clr     yl
    loadzp  player_init
    ldi     r16, (player_init_end-player_init)*2
    rcall   copyp

    ; Move tallies
    ldi     zl, low(tank)
    mov     zh, yh
    st      z, xl
    ldi     yl, low(tally1)
    ldi     r16, 2
    rcall   offset_rects

    ; Randomly add 64 to starting position.
    rcall   rand
    andi    r18, 64
    clr     xh
    add     xl, r18
    adc     xh, xh

    ; Store starting position in tank.x
    ldi     yl, low(tank)
    st      y+, xl
    st      y+, xh

    ; tank.y := terrain[x] + 2
    ori     xh, high(terrain)
    ld      r24, x
    adiw    r24, 2
    st      y+, r24

    ; Offset remaining rects by (tank.x, tank.y)
    mov     zh, yh
    ldi     zl, low(tank)
    ldi     yl, low(firing_pos)
    ldi     r16, 3      ; firing_pos, button, turr
    rcall   offset_rects
    
    dbgcall print_player
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; draw_terrain
;
; Draws terrain and sky on the screen.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
draw_terrain:
    ; Set vertical orienation and home cursor
    rcall   tft_vert
    ldi     yl, low(origin)
    rcall   move_xy
    ldi		r22, TFT_WRD
    rcall	send_command

    loadyd  terrain

draw_terrain1:
    ; Draw terrain for this column
    ld      r16, y
    ldi     r26, low(EARTH_COLOR)
    ldi     r27, high(EARTH_COLOR)
    rcall   draw_line1

    ; Fill remainder of column with sky
    ldi     r16, SCREEN_HEIGHT
    ld      r17, y+
    sub     r16, r17
    ldi     r26, low(SKY_COLOR)
    ldi     r27, high(SKY_COLOR)
    rcall   draw_line1

    ; More columns left?
    cpi     yl, low(terrain+SCREEN_WIDTH)
    brne    draw_terrain1
    cpi     yh, high(terrain+SCREEN_WIDTH)
    brne    draw_terrain1

    ret
    
.if FLASH_TANK
erase_player:
    ldi     r26, low(SKY_COLOR)
    ldi     r27, high(SKY_COLOR)
    ldi     r19,2                   ; Only erase tank & turret
    rjmp    draw_player1
.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; draw_player
;
; Draws the turret and tank of the given player.
;
; Inputs:
;   yh - high byte of player structure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
draw_player:
    ldi     yl, low(score)
    ld      r19, y          ; score + 2 (tank, turr)

    ldi     r26, low(PLAYER_1_COLOR)
    ldi     r27, high(PLAYER_1_COLOR)

    cpi     yh, high(player1)
    breq    draw_player1

    ; Override color if player2
    ldi     r26, low(PLAYER_2_COLOR)
    ldi     r27, high(PLAYER_2_COLOR)

draw_player1:
    ldi     yl, low(turr)
    rjmp    draw_rects

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Variable initializers
;
; Everything in this block is copied to data space during new_game
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
player_init:   
    defvect TANK_WIDTH/2, TURR_HEIGHT+TANK_HEIGHT       ; firing position
    defvect SCREEN_WIDTH/2, 192                         ; cursor
    defrect -1, -2, BUTTON_WIDTH, BUTTON_HEIGHT         ; button
    defrect (TANK_WIDTH-TURR_WIDTH)/2, TANK_HEIGHT, TURR_WIDTH, TURR_HEIGHT ; turret
    defrect 0, 0, TANK_WIDTH, TANK_HEIGHT               ; tank
    defrect 0, SCREEN_HEIGHT-TALLY_HEIGHT, TALLY_WIDTH, TALLY_HEIGHT   ; tally1
    defrect 0+TALLY_WIDTH*2, SCREEN_HEIGHT-TALLY_HEIGHT, \
            TALLY_WIDTH, TALLY_HEIGHT                   ; tally2
    defvect 0, 0                                        ; origin
    defvect 0, -2                                       ; acc (0, -9.8*SCALE/FRATE/FRATE)

player_init_end:

; Include utility modules    
.include    "touch.asm"
.include    "tft.asm"
.include    "vector.asm"
.include    "util.asm"

.if	DEBUG
.include "debug.asm"
.endif

theend:
