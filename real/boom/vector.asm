;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vector.asm
;
; Vector and rectangle manipulation routines.
;
; Dec 20, 2016 - Jim Shortz (hackaday.io/jimshortz)
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; add_vec
;
; Inputs:
;   Y - Destination vector
;   Z - Vector to add
;
; Outputs:
;   Y = Y+4
;   Z = Z+4
;
; Affected: r0-r3
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
add_vec:
    rcall   add_int

add_int:
    ld		r0, y
    ldd		r1, y+1
    ld		r2, z+
    ld		r3, z+
    add		r0, r2
    adc		r1, r3
    st		y+, r0
    st		y+, r1
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; subtract_vec
;
; Inputs:
;   Y - Destination vector
;   Z - Vector to subtract
;
; Outputs:
;   Y = Y+4
;   Z = Z+4
;
; Affected: r0-r3
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
subtract_vec:
    rcall   subtract_int

subtract_int:
    ld		r0, y
    ldd		r1, y+1
    ld		r2, z+
    ld		r3, z+
    sub		r0, r2
    sbc		r1, r3
    st		y+, r0
    st		y+, r1
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; scale_vec
;
; Multiplies vector by SCALE
;
; Inputs:
;   Y - Destination vector
;   Z - Source vector
;
; Outputs:
;   Y = Y+4
;   Z = Z+4
;
; Affected: r0-r4
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
scale_vec:
    rcall   scale_int

scale_int:
    ld      r2, z+
    ld      r3, z+
    ldi     r18, 1<<SCALE
    rcall   mul168u
    st      y+, r0
    st      y+, r1        
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; descale_vec
;
; Divides vector by SCALE
;
; Inputs:
;   Y - Destination vector
;   Z - Source vector
;
; Outputs:
;   Y = Y+4
;   Z = Z+4
;
; Affected: r0-r4, r16
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
descale_vec:
    rcall   descale_int

descale_int:
    ld      r0, z+
    ld      r1, z+
    ldi     r18, 1<<SCALE
    rcall   div168u
    st      y+, r0
    st      y+, r1        
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; copy_vec
;
; Copies a vector
;
; Inputs:
;   Y - Destination vector
;   Z - Source vector
;
; Affects - r16
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
copy_vec:
    ldi     r16, VECTOR_SIZE
    rjmp    copy

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; offset_rects
;
; Adjusts the x,y position of a number of rectangles by a given vector.
;
; Inputs:
;   r16 -   Number of rects
;   Y -     Rects to adjust
;   Z -     Pointer to vector to offset by
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
offset_rects:
    rcall   add_vec
    adiw    yl, VECTOR_SIZE
    sbiw    zl, VECTOR_SIZE
    dec     r16
    brne    offset_rects
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; hit_player
;
;   Determines if the tank was hit
;
; Inputs:
;   yh -    High word of target player structure
;	Z -     Pointer to point coordinates
;
; Outputs:
;   N   -   tank was NOT hit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
hit_player:
    ldi     zl, low(scn)
    ldi     yl, low(tank)
    ; Fall through

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; hit_test
;
; Determines if a point is within a rectangle
;
; Inputs:
;	Y - Pointer to rectangle structure
;	Z - Pointer to point coordinates
;
; Outputs:
;	N - Point is NOT in rectangle
;   Y - Y+4
;   Z - Z+4
;
; Affects: r0, r1, r2, r3
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
hit_test:
    ; Test X coordinates
    rcall	hit_test1
    brmi	hit_test9

    ; Fall through to Y
hit_test1:
    ld		r0, z+
    ld		r1, z+
    ld		r2, y+
    ld		r3, y+
    sub		r0, r2
    sbc		r1, r3
    brmi	hit_test9
    ldd		r2, y+2 
    ldd		r3, y+3
    cp		r2, r0
    cpc		r3, r1

hit_test9:
    ret
    
