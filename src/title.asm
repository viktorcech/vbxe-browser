; ============================================================================
; Title Screen - Welcome / about screen with GMON gradient banner
; ============================================================================

.proc show_welcome
        jsr vbxe_cls
        jsr title_gfx_init

        ; === Title (row 1, centered) ===
        lda #1
        ldx #34
        jsr vbxe_setpos
        lda #ATTR_H1
        jsr vbxe_setattr
        lda #<tw_title
        ldx #>tw_title
        jsr vbxe_print

        ; === Version (row 3, centered) ===
        lda #3
        ldx #msg_welcome_col
        jsr vbxe_setpos
        lda #ATTR_NORMAL
        jsr vbxe_setattr
        lda #<msg_welcome
        ldx #>msg_welcome
        jsr vbxe_print

        ; === Subtitle (row 5, centered) ===
        lda #5
        ldx #23
        jsr vbxe_setpos
        lda #ATTR_NORMAL
        jsr vbxe_setattr
        lda #<tw_subtitle
        ldx #>tw_subtitle
        jsr vbxe_print

        ; === Separator (row 7) ===
        lda #7
        ldx #0
        jsr vbxe_setpos
        lda #ATTR_H2
        jsr vbxe_setattr
        ldx #SCR_COLS
?fl1    stx zp_tmp2
        lda #$A0               ; inverse space = solid block
        jsr vbxe_putchar
        ldx zp_tmp2
        dex
        bne ?fl1

        ; === Requirements (row 9, centered) ===
        lda #9
        ldx #17
        jsr vbxe_setpos
        lda #ATTR_DECOR
        jsr vbxe_setattr
        lda #<tw_req
        ldx #>tw_req
        jsr vbxe_print

        ; === Press I hint (row 14, centered) ===
        lda #14
        ldx #20
        jsr vbxe_setpos
        lda #ATTR_H2
        jsr vbxe_setattr
        lda #<tw_press_i
        ldx #>tw_press_i
        jsr vbxe_print

        ; === Separator (row 18) ===
        lda #18
        ldx #0
        jsr vbxe_setpos
        lda #ATTR_DECOR
        jsr vbxe_setattr
        ldx #SCR_COLS
?fl2    stx zp_tmp2
        lda #$A0               ; inverse space = solid block
        jsr vbxe_putchar
        ldx zp_tmp2
        dex
        bne ?fl2

        ; === Proxy status (row 20) ===
        lda #20
        ldx #25
        jsr vbxe_setpos
        lda use_proxy
        beq ?poff
        lda #COL_GREEN
        jsr vbxe_setattr
        lda #<tw_pon
        ldx #>tw_pon
        jmp ?pshow
?poff   lda #ATTR_DECOR
        jsr vbxe_setattr
        lda #<tw_poff
        ldx #>tw_poff
?pshow  jsr vbxe_print

        ; === Press U prompt (row 22, centered) ===
        lda #22
        ldx #27
        jsr vbxe_setpos
        lda #ATTR_LINK
        jsr vbxe_setattr
        lda #<tw_press_u
        ldx #>tw_press_u
        jsr vbxe_print

        ; === Author (row 24, centered) ===
        lda #24
        ldx #18
        jsr vbxe_setpos
        lda #ATTR_DECOR
        jsr vbxe_setattr
        lda #<msg_author
        ldx #>msg_author
        jsr vbxe_print

        lda #ATTR_NORMAL
        jmp vbxe_setattr
.endp

; Title screen strings
tw_title    dta c'C A C T U S',0
tw_subtitle dta c'The Internet on your Atari XL/XE!',0
tw_req      dta c'Requires: VBXE + FujiNet + ST Mouse (port 2)',0
tw_ctrl_hdr dta c'Controls:',0
tw_ctrl1    dta c'U - Enter URL              B - Back',0
tw_ctrl2    dta c'H - Skip to heading        Q - Quit page',0
tw_ctrl3    dta c'Space/Return - Next page   Click - follow link',0
tw_ctrl4    dta c'P - Toggle proxy (fast)    IMG links: click to view',0
tw_search   dta c'Tip: press U, type words (e.g. ATARI 800XL) to search',0
tw_press_u  dta c'Press U to start browsing.',0
tw_press_i  dta c'Press I for controls / help',0
tw_pon      dta c'Proxy: ON  (P to toggle)',0
tw_poff     dta c'Proxy: OFF (P to toggle)',0

; ============================================================================
; show_info - Full-screen help/controls popup (triggered by 'I' in main loop)
; ============================================================================
.proc show_info
        jsr vbxe_cls

        ; Header (row 1, centered)
        lda #1
        ldx #35
        jsr vbxe_setpos
        lda #ATTR_H1
        jsr vbxe_setattr
        lda #<in_hdr
        ldx #>in_hdr
        jsr vbxe_print

        ; Main browser controls
        lda #3
        ldx #4
        jsr vbxe_setpos
        lda #ATTR_H2
        jsr vbxe_setattr
        lda #<in_main_hdr
        ldx #>in_main_hdr
        jsr vbxe_print

        ldx #0
?ml1    stx ?i
        lda in_main_lo,x
        sta zp_tmp_ptr
        lda in_main_hi,x
        sta zp_tmp_ptr+1
        lda ?i
        clc
        adc #4
        pha
        ldx #6
        jsr vbxe_setpos
        pla
        lda #ATTR_NORMAL
        jsr vbxe_setattr
        lda zp_tmp_ptr
        ldx zp_tmp_ptr+1
        jsr vbxe_print
        ldx ?i
        inx
        cpx #IN_MAIN_N
        bne ?ml1

        ; Search tip (between sections)
        lda #16
        ldx #6
        jsr vbxe_setpos
        lda #ATTR_DECOR
        jsr vbxe_setattr
        lda #<tw_search
        ldx #>tw_search
        jsr vbxe_print

        ; Bookmarks controls
        lda #18
        ldx #4
        jsr vbxe_setpos
        lda #ATTR_H2
        jsr vbxe_setattr
        lda #<in_bk_hdr
        ldx #>in_bk_hdr
        jsr vbxe_print

        ldx #0
?bl1    stx ?i
        lda in_bk_lo,x
        sta zp_tmp_ptr
        lda in_bk_hi,x
        sta zp_tmp_ptr+1
        lda ?i
        clc
        adc #19
        pha
        ldx #6
        jsr vbxe_setpos
        pla
        lda #ATTR_NORMAL
        jsr vbxe_setattr
        lda zp_tmp_ptr
        ldx zp_tmp_ptr+1
        jsr vbxe_print
        ldx ?i
        inx
        cpx #IN_BK_N
        bne ?bl1

        ; Footer (row 25, centered)
        lda #25
        ldx #25
        jsr vbxe_setpos
        lda #ATTR_LINK
        jsr vbxe_setattr
        lda #<in_foot
        ldx #>in_foot
        jsr vbxe_print

        lda #ATTR_NORMAL
        jsr vbxe_setattr

        ; Wait for any key (MAG-style CH poll)
?wait   lda RTCLOK+2
?wvs    cmp RTCLOK+2
        beq ?wvs
        lda CH
        cmp #$FF
        beq ?wait
        lda #$FF
        sta CH
        rts
?i      dta 0
.endp

IN_MAIN_N = 12
in_main_hdr dta c'Browser',0
in_main_lo  dta <in_m1,<in_m2,<in_m3,<in_m4,<in_m5,<in_m6,<in_m7,<in_m8,<in_m9,<in_m10,<in_m11,<in_m12
in_main_hi  dta >in_m1,>in_m2,>in_m3,>in_m4,>in_m5,>in_m6,>in_m7,>in_m8,>in_m9,>in_m10,>in_m11,>in_m12
in_m1   dta c'U             Enter URL, or search words (no dot)',0
in_m2   dta c'B             Back (history)',0
in_m3   dta c'Q             Quit to welcome screen',0
in_m4   dta c'P             Toggle proxy (fast rendering)',0
in_m5   dta c'H             Skip to next heading on page',0
in_m6   dta c'Ctrl+B        Open bookmarks window',0
in_m7   dta c'F (Ctrl+F)   Find text on page',0
in_m8   dta c'I             This help screen',0
in_m9   dta c'TAB           Highlight next link',0
in_m10  dta c'RETURN        Follow highlighted link / next page',0
in_m11  dta c'SPACE         Next page (during --More--)',0
in_m12  dta c'Click         Follow link under mouse cursor',0

IN_BK_N = 4
in_bk_hdr dta c'Bookmarks window',0
in_bk_lo  dta <in_b1,<in_b2,<in_b3,<in_b4
in_bk_hi  dta >in_b1,>in_b2,>in_b3,>in_b4
in_b1   dta c'Joy / - =     Move cursor',0
in_b2   dta c'RETURN        Open URL / edit empty slot',0
in_b3   dta c'D             Delete selected slot',0
in_b4   dta c'ESC           Close window',0

in_hdr  dta c'Controls',0
in_foot dta c'Press any key to close',0
