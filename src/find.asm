; ============================================================================
; Find in page
; Ctrl+F opens "Find: " prompt. Scans visible content rows for the typed
; string (case-insensitive, ASCII). Highlights all matches in yellow.
; Any key closes find mode and restores original attributes.
; ============================================================================

FIND_MAX_LEN    = 16
FIND_MAX_MATCH  = 16
FIND_HILITE     = COL_YELLOW

; Find state in page 5 (free RAM)
find_buf         = $0500          ; 16 B search string
find_match_row   = $0510          ; 16 B row per match
find_match_col   = $0520          ; 16 B col (0..79) per match
find_len         = $0530          ; search string length
find_count       = $0531          ; number of VIEWPORT matches (highlighted)
find_total       = $0532          ; total matches in full page buffer (counted only)
find_mpos        = $0533          ; full-scan: partial match position
find_intag       = $0534          ; full-scan: inside HTML tag flag

; Saved attributes — packed linearly as matches are processed.
; For match i we save find_len bytes, running total <= FIND_MAX_MATCH*FIND_MAX_LEN = 256.
find_saved       = $0700          ; 256 B in page 7

; ----------------------------------------------------------------------------
; find_start - Entry point (called from Ctrl+F dispatch)
; ----------------------------------------------------------------------------
.proc find_start
        ; "Find: " prompt on status bar
        lda #STATUS_ROW
        ldx #COL_GREEN
        jsr vbxe_fill_row
        lda #STATUS_ROW
        ldx #0
        jsr vbxe_setpos
        lda #COL_GREEN
        jsr vbxe_setattr
        lda #<m_prompt
        ldx #>m_prompt
        jsr vbxe_print

        ; Read into find_buf
        lda #<find_buf
        sta zp_tmp_ptr
        lda #>find_buf
        sta zp_tmp_ptr+1
        ldx #FIND_MAX_LEN-1
        jsr kbd_get_line
        bcs ?bail                   ; ESC
        sty find_len
        cpy #0
        beq ?bail                   ; empty

        jsr find_scan
        lda find_count
        bne ?have
        status_msg COL_RED, m_nomatch
        jsr kbd_get
        jmp ui_status_end

?have   jsr find_highlight
        jsr find_scan_full          ; count total matches in whole page
        status_msg COL_YELLOW, m_found
        lda find_count
        jsr find_print_num
        lda #<m_visible
        ldx #>m_visible
        jsr vbxe_print
        lda find_total
        jsr find_print_num
        lda #<m_total
        ldx #>m_total
        jsr vbxe_print
        jsr kbd_get
        jsr find_restore
        jmp ui_status_end

?bail   jmp ui_status_end
.endp

; ----------------------------------------------------------------------------
; find_scan - Scan content rows for find_buf. Populates match arrays.
; Case-insensitive for ASCII letters (ORA #$20).
; ----------------------------------------------------------------------------
.proc find_scan
        lda #0
        sta find_count

        memb_on 0

        ldx #CONTENT_TOP
?rowlp  stx ?row
        lda row_addr_lo,x
        sta zp_scr_ptr
        lda row_addr_hi,x
        sta zp_scr_ptr+1

        ldy #0                      ; Y = char-byte offset within row (0,2,4,...)
?collp  ; Check col + find_len <= 80
        tya
        lsr                         ; col = Y/2
        clc
        adc find_len
        cmp #SCR_COLS+1
        bcs ?next_row

        sty ?startY
        ldx #0                      ; index into find_buf
?cmplp  cpx find_len
        beq ?hit
        lda (zp_scr_ptr),y
        and #$7F                    ; ignore inverse video bit
        ora #$20                    ; case-fold
        sta ?tmp
        lda find_buf,x
        ora #$20
        cmp ?tmp
        bne ?miss
        iny
        iny
        inx
        jmp ?cmplp

?hit    ldx find_count
        lda ?row
        sta find_match_row,x
        lda ?startY
        lsr
        sta find_match_col,x
        inx
        stx find_count
        cpx #FIND_MAX_MATCH
        beq ?done
?miss   ldy ?startY
        iny
        iny
        cpy #SCR_STRIDE
        bcc ?collp

?next_row
        ldx ?row
        inx
        cpx #CONTENT_BOT+1
        bcc ?rowlp

?done   memb_off
        rts

?row    dta 0
?startY dta 0
?tmp    dta 0
.endp

; ----------------------------------------------------------------------------
; find_highlight - Save original attrs and write highlight to all matches
; ----------------------------------------------------------------------------
.proc find_highlight
        memb_on 0
        lda #0
        sta ?sidx
        lda #0
        sta ?mi
?mlp    lda ?mi
        cmp find_count
        bcs ?done

        ldx ?mi
        lda find_match_row,x
        tax
        lda row_addr_lo,x
        sta zp_scr_ptr
        lda row_addr_hi,x
        sta zp_scr_ptr+1

        ldx ?mi
        lda find_match_col,x
        asl
        tay
        iny                         ; Y = attr offset for first char

        ldx #0                      ; char counter 0..find_len-1
?clp    cpx find_len
        bcs ?nm
        lda (zp_scr_ptr),y          ; read original attr
        stx ?cx
        ldx ?sidx
        sta find_saved,x
        inc ?sidx
        ldx ?cx
        lda #FIND_HILITE
        sta (zp_scr_ptr),y
        iny
        iny
        inx
        jmp ?clp
?nm     inc ?mi
        jmp ?mlp
?done   memb_off
        rts

?mi     dta 0
?sidx   dta 0
?cx     dta 0
.endp

; ----------------------------------------------------------------------------
; find_restore - Write saved attrs back (mirrors find_highlight layout)
; ----------------------------------------------------------------------------
.proc find_restore
        memb_on 0
        lda #0
        sta ?sidx
        lda #0
        sta ?mi
?mlp    lda ?mi
        cmp find_count
        bcs ?done

        ldx ?mi
        lda find_match_row,x
        tax
        lda row_addr_lo,x
        sta zp_scr_ptr
        lda row_addr_hi,x
        sta zp_scr_ptr+1

        ldx ?mi
        lda find_match_col,x
        asl
        tay
        iny

        ldx #0
?clp    cpx find_len
        bcs ?nm
        stx ?cx
        ldx ?sidx
        lda find_saved,x
        inc ?sidx
        ldx ?cx
        sta (zp_scr_ptr),y
        iny
        iny
        inx
        jmp ?clp
?nm     inc ?mi
        jmp ?mlp
?done   memb_off
        rts

?mi     dta 0
?sidx   dta 0
?cx     dta 0
.endp

; ----------------------------------------------------------------------------
; find_print_num - Print A as 1-2 digit decimal at cursor
; ----------------------------------------------------------------------------
.proc find_print_num
        ldx #0
?t      cmp #10
        bcc ?o
        sbc #10
        inx
        jmp ?t
?o      pha
        cpx #0
        beq ?no_t
        txa
        clc
        adc #'0'
        jsr vbxe_putchar
?no_t   pla
        clc
        adc #'0'
        jmp vbxe_putchar
.endp

; ----------------------------------------------------------------------------
; find_scan_full - Walk the entire VRAM page buffer, count matches of find_buf
; while skipping content inside HTML tags (<...>). Case-insensitive (ASCII).
; Saves and restores the parser's read pointer so rendering can resume.
; ----------------------------------------------------------------------------
.proc find_scan_full
        ; Save parser read state
        lda pb_rd_bank
        sta ?sv_bank
        lda zp_pb_rd_ptr
        sta ?sv_lo
        lda zp_pb_rd_ptr+1
        sta ?sv_hi
        lda pb_read
        sta ?sv_rd0
        lda pb_read+1
        sta ?sv_rd1
        lda pb_read+2
        sta ?sv_rd2
        lda zp_rx_len
        sta ?sv_rxlen

        ; Rewind to start of page buffer
        jsr vbxe_pb_init_read

        lda #0
        sta find_total
        sta find_mpos
        sta find_intag

?cloop  ; Compute remaining = pb_total - pb_read (24-bit)
        lda pb_total
        sec
        sbc pb_read
        sta ?rem_lo
        lda pb_total+1
        sbc pb_read+1
        sta ?rem_hi
        lda pb_total+2
        sbc pb_read+2
        bne ?has_upper              ; hi byte nonzero → remaining >= 65536
        lda ?rem_hi
        bne ?has_upper              ; mid byte nonzero → remaining >= 256
        lda ?rem_lo
        beq ?done                   ; remaining = 0
        jmp ?do_read
?has_upper
        lda #255
?do_read
        jsr vbxe_pb_read_chunk      ; reads A bytes, zp_rx_len = A
        ; Advance pb_read by zp_rx_len (caller's responsibility)
        clc
        lda pb_read
        adc zp_rx_len
        sta pb_read
        bcc ?npr
        inc pb_read+1
        bne ?npr
        inc pb_read+2
?npr
        ldy #0
?slp    cpy zp_rx_len
        bcs ?cloop

        lda rx_buffer,y
        cmp #'<'
        bne ?no_lt
        lda #1
        sta find_intag
        lda #0
        sta find_mpos
        jmp ?adv
?no_lt  cmp #'>'
        bne ?no_gt
        lda #0
        sta find_intag
        jmp ?adv
?no_gt  lda find_intag
        bne ?adv                    ; inside tag, skip

        ; Try to match against find_buf[find_mpos]
        lda rx_buffer,y
        and #$7F
        ora #$20
        sta ?tmp
        ldx find_mpos
        lda find_buf,x
        ora #$20
        cmp ?tmp
        bne ?reset_m
        inc find_mpos
        lda find_mpos
        cmp find_len
        bne ?adv
        ; Complete match
        inc find_total
        lda #0
        sta find_mpos
        jmp ?adv
?reset_m
        lda #0
        sta find_mpos
?adv    iny
        jmp ?slp

?done   ; Restore parser state
        lda ?sv_bank
        sta pb_rd_bank
        lda ?sv_lo
        sta zp_pb_rd_ptr
        lda ?sv_hi
        sta zp_pb_rd_ptr+1
        lda ?sv_rd0
        sta pb_read
        lda ?sv_rd1
        sta pb_read+1
        lda ?sv_rd2
        sta pb_read+2
        lda ?sv_rxlen
        sta zp_rx_len
        rts

?sv_bank  dta 0
?sv_lo    dta 0
?sv_hi    dta 0
?sv_rd0   dta 0
?sv_rd1   dta 0
?sv_rd2   dta 0
?sv_rxlen dta 0
?tmp      dta 0
?rem_lo   dta 0
?rem_hi   dta 0
.endp

m_prompt  dta c'Find: ',0
m_nomatch dta c' No matches (press a key)',0
m_found   dta c' Matches: ',0
m_visible dta c' visible, ',0
m_total   dta c' total',0
