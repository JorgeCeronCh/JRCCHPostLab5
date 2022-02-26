/*	
    Archivo:		postlab5mian.S
    Dispositivo:	PIC16F887
    Autor:		Jorge Cerón 20288
    Compilador:		pic-as (v2.30), MPLABX V6.00

    Programa:		Contador binario de 8 bits y en decimal incremento/decremento/TMR0 con interrupciones 
			
    Hardware:		LEDs en puerto A y 3 contadores de 7 segmentos en puerto D en dec.

    Creado:			23/02/22
    Última modificación:	26/02/22	
*/

PROCESSOR 16F887
#include <xc.inc>

; configuracion 1
  CONFIG  FOSC = INTRC_NOCLKOUT // Oscillador Interno sin salidas
  CONFIG  WDTE = OFF            // WDT (Watchdog Timer Enable bit) disabled (reinicio repetitivo del pic)
  CONFIG  PWRTE = OFF            // PWRT enabled (Power-up Timer Enable bit) (espera de 72 ms al iniciar)
  CONFIG  MCLRE = OFF           // El pin de MCL se utiliza como I/O
  CONFIG  CP = OFF              // Sin proteccion de codigo
  CONFIG  CPD = OFF             // Sin proteccion de datos
  
  CONFIG  BOREN = OFF           // Sin reinicio cunado el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            // Reinicio sin cambio de reloj de interno a externo
  CONFIG  FCMEN = OFF           // Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = OFF              // programación en bajo voltaje permitida

; configuracion  2
  CONFIG  WRT = OFF             // Protección de autoescritura por el programa desactivada
  CONFIG  BOR4V = BOR40V        // Reinicio abajo de 4V, (BOR21V = 2.1V)
  
UP	EQU 0			// Equivalencia de UP=0
DOWN	EQU 1			// Equivalencia de DOWN=1

PSECT udata_bank0
    CONTA:	    DS 1
    CENTENA:	    DS 1
    DECENA:	    DS 1
    UNIDADES:	    DS 1
    BANDERADISP:    DS 1
    DISPLAY:	    DS 3

;----------------MACROS--------------- Macro para reiniciar el valor del Timer0
RESETTIMER0 MACRO
    BANKSEL TMR0	// Direccionamiento al banco 00
    MOVLW   217		// Cargar literal en el registro W
    MOVWF   TMR0	// Configuración completa para que tenga 10ms de retardo
    BCF	    T0IF	// Se limpia la bandera de interrupción
    
    ENDM
; Status para interrupciones
PSECT udata_shr			// Variables globales en memoria compartida
    WTEMP:	    DS 1	// 1 byte
    STATUSTEMP:	    DS 1	// 1 byte
     
PSECT resVect, class=CODE, abs, delta=2	
;----------------vector reset----------------
ORG 00h				// Posición 0000h para el reset
resVect:
    PAGESEL	main		// Cambio de página
    GOTO	main

PSECT intVect, class=CODE, abs, delta=2 
;----------------vector interrupcion---------------
ORG 04h				// Posición 0004h para las interrupciones
PUSH:				// PC a pila
    MOVWF   WTEMP		// Se mueve W a la variable WTEMP
    SWAPF   STATUS, W		// Swap de nibbles del status y se almacena en W
    MOVWF   STATUSTEMP		// Se mueve W a la variable STATUSTEMP
ISR:				// Rutina de interrupción
    
    BTFSC   RBIF		// Analiza la bandera de cambio del PORTB si esta encendida (si no lo está salta una linea)
    CALL    INTERRUPIOCB	// Se llama la rutina de interrupción del puerto B
    BANKSEL PORTA

    BTFSC   T0IF		// Analiza la bandera de cambio del TMR0 si esta encendida (si no lo está salta una linea)
    CALL    INT_TMR0		// Se llama la rutina de interrupción del TMR0
    
POP:				// Intruccion movida de la pila al PC
    SWAPF   STATUSTEMP, W	// Swap de nibbles de la variable STATUSTEMP y se almacena en W
    MOVWF   STATUS		// Se mueve W a status
    SWAPF   WTEMP, F		// Swap de nibbles de la variable WTEMP y se almacena en WTEMP 
    SWAPF   WTEMP, W		// Swap de nibbles de la variable WTEMP y se almacena en w
    
    RETFIE

PSECT code, abs, delta=2   
;----------------configuracion----------------
ORG 100h
main:
    CALL    CONFIGIO	    // Se llama la rutina configuración de entradas/salidas
    CALL    CONFIGRELOJ	    // Se llama la rutina configuración del reloj
    CALL    CONFIGTIMER0    // Se llama la rutina configuración del TMR0
    CALL    CONFIGINTERRUP  // Se llama la rutina configuración de interrupciones
    CALL    CONFIIOCB	    // Se llama la rutina configuración de interrupcion en PORTB
    BANKSEL PORTA 
    
loop:
    CALL    VALOR_DEC	    // Se llama la rutina de movimiento de valores decimales a 7SEG
    CALL    OBTENER_CENTENAS// Se llama la rutina para obtener las centenas/decenas/unidades
    GOTO    loop	    // Regresa a revisar	    

CONFIGRELOJ:
    BANKSEL OSCCON	// Direccionamiento al banco 01
    BSF OSCCON, 0	// SCS en 1, se configura a reloj interno
    BSF OSCCON, 6	// bit 6 en 1
    BSF OSCCON, 5	// bit 5 en 1
    BCF OSCCON, 4	// bit 4 en 0
    // Frecuencia interna del oscilador configurada a 4MHz
    RETURN 

CONFIGTIMER0:
    BANKSEL OPTION_REG	// Direccionamiento al banco 01
    BCF OPTION_REG, 5	// TMR0 como temporizador
    BCF OPTION_REG, 3	// Prescaler a TMR0
    BSF OPTION_REG, 2	// bit 2 en 1
    BSF	OPTION_REG, 1	// bit 1 en 1
    BSF	OPTION_REG, 0	// bit 0 en 1
    // Prescaler en 256
    // Sabiendo que N = 256 - (T*Fosc)/(4*Ps) -> 256-(0.01*4*10^6)/(4*256) = 216.93 (217 aprox)
    RESETTIMER0
    
    RETURN
    
CONFIGIO:
    BANKSEL ANSEL	// Direccionar al banco 11
    CLRF    ANSEL	// I/O digitales
    CLRF    ANSELH	// I/O digitales
    
    BANKSEL TRISA	// Direccionar al banco 01
    BSF	    TRISB, UP	// RB0 como entrada
    BSF	    TRISB, DOWN	// RB1 como entrada
    
    CLRF    TRISA	// PORTA como salida
    CLRF    TRISC	// PORTC como salida
    CLRF    TRISD	// PORTD como salida
    
    
    BCF	    OPTION_REG, 7   // RBPU habilita las resistencias pull-up 
    BSF	    WPUB, UP	    // Habilita el registro de pull-up en RB0 
    BSF	    WPUB, DOWN	    // Habilita el registro de pull-up en RB1
    
    BANKSEL PORTA	// Direccionar al banco 00
    CLRF    PORTA	// Se limpia PORTA
    CLRF    PORTB	// Se limpia PORTB
    CLRF    PORTC	// Se limpia PORTC
    CLRF    PORTD	// Se limpia PORTD
    CLRF    CENTENA	// Se limpia variable CENTENA
    CLRF    DECENA	// Se limpia variable DECENA
    CLRF    UNIDADES	// Se limpia variable UNIDADES
    CLRF    BANDERADISP	// Se limpia variable BANDERADISP
    
    RETURN
    
 CONFIGINTERRUP:
    BANKSEL INTCON
    BSF	    GIE		    // Habilita interrupciones globales
    BSF	    RBIE	    // Habilita interrupciones de cambio de estado del PORTB
    BCF	    RBIF	    // Se limpia la banderda de cambio del puerto B
    
    BSF	    T0IE	    // Habilita interrupción TMR0
    BCF	    T0IF	    // Se limpia de una vez la bandera de TMR0
    
    RETURN

CONFIIOCB:		    // Interrupt on-change PORTB register
    BANKSEL TRISA
    BSF	    IOCB, UP	    // Interrupción control de cambio en el valor de B
    BSF	    IOCB, DOWN	    // Interrupción control de cambio en el valor de B
    
    BANKSEL PORTA
    MOVF    PORTB, W	    // Termina la condición de mismatch, compara con W
    BCF	    RBIF	    // Se limpia la bandera de cambio de PORTB
    
    RETURN
    
INTERRUPIOCB:
    BANKSEL PORTA
    BTFSS   PORTB, UP		// Analiza RB0 si no esta presionado (si está presionado salta una linea)
    INCF    PORTA		
    BTFSS   PORTB, DOWN		// Analiza RB1 si no esta presionado (si está presionado salta una linea)
    DECF    PORTA
    BCF	    RBIF		// Se limpia la bandera de cambio de estado del PORTB
    
    RETURN    

INT_TMR0:
    RESETTIMER0			// Se reinicia TMR0 para 10ms  
    CALL    MOSTRAR_VALORDEC	// Se llama subrutina para la configuracion de encedido/apago de 7SEG
    
    RETURN
    
VALOR_DEC:
    MOVF    UNIDADES, W		// Se mueve valor de UNIDADES a W
    CALL    TABLA		// Se busca valor a cargar en PORTC
    MOVWF   DISPLAY		// Se guarda en nueva variable display1
    
    MOVF    DECENA, W		// Se mueve valor de DECENA a W
    CALL    TABLA		// Se busca valor a cargar en PORTC
    MOVWF   DISPLAY+1		// Se guarda en nueva variable display2
    
    MOVF    CENTENA, W		// Se mueve valor de CENTENA a W
    CALL    TABLA		// Se busca valor a cargar en PORTC
    MOVWF   DISPLAY+2		// Se guarda en nueva variable display3
    RETURN
    
MOSTRAR_VALORDEC:
    BCF	    PORTD, 0		// Se limpia set-display de centenas
    BCF	    PORTD, 1		// Se limpia set-display de decenas
    BCF	    PORTD, 2		// Se limpia set-display de unidades
    BTFSC   BANDERADISP, 0	// Se verifica bandera display centenas si esta apagada salta(bit 0 de la variable)
    GOTO    DISPLAY3		// Si está encendida nos movemos al display de centenas
    BTFSC   BANDERADISP, 1	// Se verifica bandera display decena si esta apagada salta(bit 1 de la variable)
    GOTO    DISPLAY2		// Si está encendida nos movemos al display de decenas
    BTFSC   BANDERADISP, 2	// Se verifica bandera display centena si esta apagada salta (bit 2 de la variable)
    GOTO    DISPLAY1		// Si está encendida nos movemos al display de unidades


DISPLAY1:
    MOVF    DISPLAY, W		// Se mueve valor de UNIDADES a W
    MOVWF   PORTC		// Se muestra en el display
    BSF	    PORTD, 2		// Se enciende set-display de unidades
    BCF	    BANDERADISP, 2	// Se apaga la bandera de unidades
    BSF	    BANDERADISP, 1	// Se enciende la bandera de decenas
    
    RETURN

DISPLAY2:
    MOVF    DISPLAY+1, W	// Se mueve valor de DECENA a W
    MOVWF   PORTC		// Se muestra en el display
    BSF	    PORTD, 1		// Se enciende set-display de decenas
    BCF	    BANDERADISP, 1	// Se apaga la bandera de decenas
    BSF	    BANDERADISP, 0	// Se enciende la bandera de centenas
 
    RETURN
    
DISPLAY3:
    MOVF    DISPLAY+2, W	// Se mueve valor de CENTENA a W
    MOVWF   PORTC		// Se muestra en el display
    BSF	    PORTD, 0		// Se enciende display de centenas
    BCF	    BANDERADISP, 0	// Se apaga la bandera de centena
    BSF	    BANDERADISP, 2	// Se enciende la bandera de unidades
    
    RETURN
    
OBTENER_CENTENAS:
    CLRF    CENTENA		// Se limpia variable CENTENA
    CLRF    DECENA		// Se limpia variable DECENA
    CLRF    UNIDADES		// Se limpia variable UNIDADES
    // Obtención de centenas
    MOVF    PORTA, W		// Se mueve el valor de PORTA a W
    MOVWF   CONTA		// Se mueve el valor de W a la variable CONTA
    MOVLW   100			// Se mueve 100 a W
    SUBWF   CONTA, F		// Se resta 100 a CONTA y se guarda en CONTA
    INCF    CENTENA		// Se incrementa en 1 la variable CENTENA
    BTFSC   STATUS, 0		// Se verifica si está apagada la bandera de BORROW
				//(si está apagada quiere decir que la resta obtuvo un valor negativo)
				// si está encendida quiere decir que hay un valor positivo
    GOTO    $-4			// Si está encedida se regresa 4 instrucciones atras
    DECF    CENTENA		// Si no está encedida se resta 1 a la variable CENTENA
				// para compensar el incremento de más que se hace
				// al momento en que se reevalua el valor de CONTA
    MOVLW   100			// Se mueve 100 a W
    ADDWF   CONTA, F		// Se añaden los 100 a lo que tenga en ese momento negativo en CONTA para que sea positivo
    CALL    OBTENER_DECENAS	// Se llama la subrutina para obtener las decenas
    
    RETURN
OBTENER_DECENAS:
    MOVLW   10			// Se mueve 10 a W
    SUBWF   CONTA, F		// Se resta 10 a CONTA y se guarda en CONTA
    INCF    DECENA		// Se incrementa en 1 la variable DECENA
    BTFSC   STATUS, 0		// Se verifica si está apagada la bandera de BORROW 
				//(si está apagada quiere decir que la resta obtuvo un valor negativo)
				// si está encendida quiere decir que hay un valor positivo
    GOTO    $-4			// Si está encedida se regresa 4 instrucciones atras
    DECF    DECENA		// Si no está encedida se resta 1 a la variable DECENA
				// para compensar el incremento de más que se hace
				// al momento en que se reevalua el valor de CONTA
    MOVLW   10			// Se mueve 10 a W
    ADDWF   CONTA, F		// Se añaden los 10 a lo que tenga en ese momento negativo en CONTA para que sea positivo
    CALL    OBTENER_UNIDADES	// Se llama la subrutina para obtener las unidades
    
    RETURN
OBTENER_UNIDADES:
    MOVLW   1			// Se mueve 1 a W
    SUBWF   CONTA, F		// Se resta 1 a CONTA y se guarda en CONTA
    INCF    UNIDADES		// Se incrementa en 1 la variable UNIDADES
    BTFSC   STATUS, 0		// Se verifica si está apagada la bandera de BORROW
				//(si está apagada quiere decir que la resta obtuvo un valor negativo)
				// si está encendida quiere decir que hay un valor positivo
    GOTO    $-4			// Si está encedida se regresa 4 instrucciones atras
    DECF    UNIDADES		// Si no está encedida se resta 1 a la variable DECENA
				// para compensar el incremento de más que se hace
				// al momento en que se reevalua el valor de CONTA
    MOVLW   1			// Se mueve 1 a W
    ADDWF   CONTA, F		// Se añaden 1 a lo que tenga en ese momento negativo en CONTA para que sea positivo (en este caso, cero)

    RETURN   
    
ORG 200h
TABLA:
    CLRF    PCLATH	// Se limpia el registro PCLATH
    BSF	    PCLATH, 1	
    ANDLW   0x0F	// Solo deja pasar valores menores a 16
    ADDWF   PCL		// Se añade al PC el caracter en ASCII del contador
    RETLW   00111111B	// Return que devuelve una literal a la vez 0 en el contador de 7 segmentos
    RETLW   00000110B	// Return que devuelve una literal a la vez 1 en el contador de 7 segmentos
    RETLW   01011011B	// Return que devuelve una literal a la vez 2 en el contador de 7 segmentos
    RETLW   01001111B	// Return que devuelve una literal a la vez 3 en el contador de 7 segmentos
    RETLW   01100110B	// Return que devuelve una literal a la vez 4 en el contador de 7 segmentos
    RETLW   01101101B	// Return que devuelve una literal a la vez 5 en el contador de 7 segmentos
    RETLW   01111101B	// Return que devuelve una literal a la vez 6 en el contador de 7 segmentos
    RETLW   00000111B	// Return que devuelve una literal a la vez 7 en el contador de 7 segmentos
    RETLW   01111111B	// Return que devuelve una literal a la vez 8 en el contador de 7 segmentos
    RETLW   01101111B	// Return que devuelve una literal a la vez 9 en el contador de 7 segmentos
    RETLW   01110111B	// Return que devuelve una literal a la vez A en el contador de 7 segmentos
    RETLW   01111100B	// Return que devuelve una literal a la vez b en el contador de 7 segmentos
    RETLW   00111001B	// Return que devuelve una literal a la vez C en el contador de 7 segmentos
    RETLW   01011110B	// Return que devuelve una literal a la vez d en el contador de 7 segmentos
    RETLW   01111001B	// Return que devuelve una literal a la vez E en el contador de 7 segmentos
    RETLW   01110001B	// Return que devuelve una literal a la vez F en el contador de 7 segmentos
END
