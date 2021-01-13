SECTION "bootrom", ROM0[$0000]
main:
.loop:
    ; Init stackpointer
    ld SP, $FFFE
    
    ; Enable LCD and background tilemap
    ld A, $91
    ld [$FF00+$40], A

    ; Set color palette to 11111100
    ld A, $fc
    ld [$FF00+$47], A

    ; ####################
    ; Tile data copying
    ; ####################

    ; Copy 48 bytes of logo data to VRAM
    ld B, 48     ; Write length
    ld C, 1      ; Use double write
    ld HL, .logo ; Logo data start
    ld DE, $8010 ; Place it 1 tile in, so tile 0 stays white
    call .memcpy
    dec C        ; Don't double write again

    ; ####################
    ; Tile placement
    ; ####################
    ; Add two upper part of P for the P and B
    ld A, 1             ; P1 tile index
    ld HL, $9808+($20*8)
    ld [HL+], A         ; The P position
    inc HL              ; Empty space above y
    ld [HL], A          ; The B position

    ; Add lower part of P, upper part of y, a wrong tile for the lower part of B, and the O. We'll correct the B later.
    ld B, 4             ; Loop counter
    ld A, 2             ; P2 tile index
    ld HL, $9808+($20*9)
.four_range
    ld [HL+], A
    inc A
    dec B
    jp NZ, .four_range

    ; Add the upper part of the last Y at the current HL position
    ld A, 3             ; Y1 tile index
    ld [HL], A

    add A, A            ; Y2 tile index coincidentally 2xA
    ld HL, $9808+($20*10)+1
    ld [HL+], A
    inc HL
    inc HL
    ld [HL], A

    ; #########################
    ; Graphics effect and wait
    ; #########################

    ; Wait an arbitrary 60 frames

    ld C, 60        ; Frame count

    xor A
    ld D, A         ; Reset D
    ld B, A         ; Reset B
.wait_vblank
    ; Test vblank
    ld A, [$FF00+$44]
    cp $90
    jp Z, .exit_vblank

    ld E, A         ; Save LY in E

    ; Invert frame counter to 1-60 instead of 60-1
    ld A, C
    xor $FF
    sub ($ff-16*7)  ; Start X lines down. Do it in multiple of 16 to fit wave

    ; Cut out one wave
    ; Is A larger than LY? Then we want the effect
    cp E
    jp C, .no_effect
    ; Is LY no more than 16 lines larger than A?
    sub A, 16
    cp E
    jp C, .effect
    ; Fall through to no effect
.no_effect
    xor a
    ld [$FF00+$43], A
    jp .wait_vblank

.wave_table
    DB 0, 0, 1, 2, 2, 3, 3, 3, 2, 1, 1, 0, 0, 0, 0, 0

.effect
    ld A, C        ; Load frame counter for "time"
    add A, E         ; add LY from E
    and $0F         ; Clamp LY value to lookup table length
    ld E, A         ; Save LY in E
    ld HL, .wave_table
    add HL, DE      ; look up in wave table
    ld A, [HL]

    ld [$FF00+$43], A
    jp .wait_vblank

.exit_vblank
    ld A, [$FF00+$44]
    cp $90
    jp Z, .exit_vblank
    ; One frame has passed, decrement counter
    dec C
    jp NZ, .wait_vblank

    ; ###############################
    ; Recreate state of DMG boot ROM
    ; ###############################

    ld B, 6
    ld HL, .sec0
    ld DE, $FF0F
    call .memcpy

    ld B, 3
    ld HL, .sec1
    ld DE, $FF24
    call .memcpy

    ld B, 4
    ld HL, .sec2
    ld DE, $FF41
    call .memcpy

    ; Call stack.. Hard to leave in exact state
    ; ld B, 3
    ; ld HL, .sec3
    ; ld DE, $FFFA
    ; call .memcpy

    ; TODO: Restore register values?
    jp end

.memcpy
    ; Regular memcpy. HL is source, DE is target, B is length
    ; If first bit of C is non-zero, write all value double. Because the logo is black and white, we can use the same
    ; pixel data twice. This gives colors in the color palette of '00' and '11'. For more info, see documentation of
    ; the tile graphics format.
    ld A, [HL+]
    ld [DE], A
    inc DE
    BIT 0,C                 ; Test C for zero
    jp Z, .memcpy_not_double
    ld [DE], A
    inc DE
.memcpy_not_double
    dec B
    jp NZ, .memcpy
    RET

; Section 0, 1, 2 and 3 of arbitrary values, which the original boot ROM writes.
.sec0: ; 0xFF0F
    DB $01, $00, $80, $F3, $C1, $87
.sec1: ; 0xFF24
    DB $77, $F3, $80
.sec2: ; 0xFF41
    DB $01, $00, $00, $99
;.sec3: ; 0xFFFA
;    DB $39, $01, $2E

; Logo generated by png_to_tiles.py. Remember to update values for 'logo_memcpy' and 'range' if dimensions change
INCLUDE "logo.asm"

SECTION "epilog", ROM0[$00FC]
end:
    ld A, $1
    ld [$FF00+$50], A

