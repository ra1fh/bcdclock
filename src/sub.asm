; Copyright (c) 2013 Ralf Horstmann <ralf@ackstorm.de>
; 
; Permission to use, copy, modify, and distribute this software for any
; purpose with or without fee is hereby granted, provided that the above
; copyright notice and this permission notice appear in all copies.
; 
; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
; WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
; ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
; ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
; OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;		Various subroutines used by bcdclock
;;;

list        p=16f505           
#include    <p16f505.inc>

		GLOBAL	clear_file_registers_R
		EXTERN	reg_a, reg_b, reg_c
		
SUB		CODE

;;; 	clear_file_registers_R
;;;
;;; 	* description:
;;; 	  clear all file registers 0x8-0x1F, 0x30-0x3f, 0x50-0x5f, 0x70-0x7f
;;; 	* input: nothing
;;;     * output: nothing
;;;     * temporary variables used: none
	
clear_file_registers_R
		;; clear bank 0
		movlw	0x08
		movwf	FSR
clear_file_registers_0
		clrf	INDF
		incf	FSR,f
		btfss	FSR,5
		goto	clear_file_registers_0

		;; clear bank 1
		movlw	0x30
		movwf	FSR
clear_file_registers_1
		clrf	INDF
		incf	FSR,f
		btfss	FSR,6
		goto	clear_file_registers_1

		;; clear bank 2
		movlw	0x50
		movwf	FSR
clear_file_registers_2
		clrf	INDF
		incf	FSR,f
		btfss	FSR,5
		goto	clear_file_registers_2

		;; clear bank 3
		movlw	0x70
		movwf	FSR
clear_file_registers_3
		clrf	INDF
		incf	FSR,f
		btfsc	FSR,6
		goto	clear_file_registers_3
		clrf	FSR				; reset FSR to bank 0
		retlw	0
		
		END
