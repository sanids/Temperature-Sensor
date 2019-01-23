$NOLIST
$MODLP51
$NOLIST

org 0000H
   ljmp MainProgram

CLK  EQU 22118400
BAUD equ 115200
BRG_VAL equ (0x100-(CLK/(16*BAUD)))

; These ’EQU’ must match the wiring between the microcontroller and ADC
CE_ADC EQU P2.0
MY_MOSI EQU P2.1
MY_MISO EQU P2.2
MY_SCLK EQU P2.3 

dseg at 30H
Result:		  ds 4
print:		  ds 4
BCD_counter:  ds 4
x:   		  ds 4
y:   	  	  ds 4
bcd: 		  ds 5

bseg
mf: 		  dbit 1

cseg
LCD_RS equ P1.1
LCD_RW equ P1.2
LCD_E  equ P1.3
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5

$NOLIST
$include(LCD_4bit.inc)
$include(math32.inc)
$LIST

Initial_Message: db  '   temp: xx C   ', 0

;---------------------------------;
; SPI LOGIC                       ;
;---------------------------------;
INIT_SPI:
	 setb MY_MISO ; Make MISO an input pin
	 clr MY_SCLK ; For mode (0,0) SCLK is zero
	 ret
DO_SPI_G:
	 push acc
	 mov R1, #0 ; Received byte stored in R1
	 mov R2, #8 ; Loop counter (8-bits)
DO_SPI_G_LOOP:
	 mov a, R0 ; Byte to write is in R0
	 rlc a ; Carry flag has bit to write
	 mov R0, a
	 mov MY_MOSI, c
	 setb MY_SCLK ; Transmit
	 mov c, MY_MISO ; Read received bit
	 mov a, R1 ; Save received bit in R1
	 rlc a
	 mov R1, a
	 clr MY_SCLK
	 djnz R2, DO_SPI_G_LOOP
	 pop acc
	 ret 

; Configure the serial port and baud rate
InitSerialPort:
    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, otherwise we risk displaying gibberish!
    mov R1, #222
    mov R0, #166
    djnz R0, $   ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, $-4 ; 22.51519us*222=4.998ms
    ; Now we can proceed with the configuration
	orl	PCON,#0x80
	mov	SCON,#0x52
	mov	BDRCON,#0x00
	mov	BRL,#BRG_VAL
	mov	BDRCON,#0x1E ; BDRCON=BRR|TBCK|RBCK|SPD;
    ret
    
; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret
    
Delay:
	Wait_Milli_Seconds(#200)
	Wait_Milli_Seconds(#200)
	Wait_Milli_Seconds(#200)
	Wait_Milli_Seconds(#200)
	Wait_Milli_Seconds(#200)
	ret
    
Do_Something_With_Result:
	mov x+0, Result+0
	mov x+1, Result+1
	mov x+2, #0
	mov x+3, #0
	Load_y(410)
	lcall mul32
	Load_y(1023)
	lcall div32
	Load_y(273)
	lcall sub32
	mov a, x
	da a
	mov print, a
	lcall print2lcd
	lcall hex2bcd
	mov a, bcd+1
	swap a
	anl a, #0x0f
	orl a, #0x30
	lcall putchar
	mov a, bcd+1
	anl a, #0x0f
	orl a, #0x30
	lcall putchar
	mov a, bcd+0
	swap a
	anl a, #0x0f
	orl a, #0x30
	lcall putchar
	mov a, bcd+0
	anl a, #0x0f
	orl a, #0x30
	lcall putchar
	mov a, #'\r'
	lcall putchar
	mov a, #'\n'
	lcall putchar
	ret
	
print2lcd:
	mov BCD_counter, print
	Set_Cursor(1, 10)
	Display_BCD(BCD_counter)
	ret

MainProgram:
    mov SP, #7FH ; Set the stack pointer to the begining of idata
    mov P0M0, #0
    mov P0M1, #0
    lcall LCD_4BIT
    Set_Cursor(1,1)
    Send_Constant_String(#Initial_Message)
    lcall InitSerialPort
    lcall INIT_SPI
    
Forever:
	clr CE_ADC
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov R0, #10000000B ; Single ended, read channel 0
	lcall DO_SPI_G
	mov a, R1 ; R1 contains bits 8 and 9
	anl a, #00000011B ; We need only the two least significant bits
	mov Result+1, a ; Save result high.
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov Result, R1 ; R1 contains bits 0 to 7. Save result low.
	setb CE_ADC
	lcall Delay
	lcall Do_Something_With_Result
	sjmp Forever

END
