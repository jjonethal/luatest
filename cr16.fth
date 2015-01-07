:L L:
\ generate kernel image
META>
: dup   ;          ( w -- w w )
: 2dup  ;          ( a b -- a b a b )
: drop  ;          ( w -- )
: 2drop ;          ( w w -- )
: swap  ;          ( a b -- b a )
: 2swap ;          ( a b c d -- c d a b )
: : ;                                 \ compile word to intern memory
: constant ;                          \ create 16 bit constant
: 2constant ;                         \ create a 32 bit constant
: variable ;
: + ;                                  
: - ;
: @ ;
: ! ;
: key ;
: emit ;
: create ;
: if ;
: then ;
: =0 ;
: <>0 ;
: ; ;

: HOST>                 \ compile to host directory
: META>                 \ compile to meta compiler
: TARGET>               \ compile to target
: META+TARGET>          \ compile to meta and target


\ 16 bit register definitions
0x000F constant SP_L      \ return stack pointer

\ 32 bit register pairs
0x0000 constant R1_R0     \ cr16c constant for register pair r1,r0
0x0002 constant R3_R2     \ cr16c constant for register pair r3,r2
0x0004 constant R5_R4     \ cr16c constant for register pair r5,r4

\ virtual machine definitions
R5_R4  constant TOS       \ top of stack
R3_R2  constant W         \ working register




\ constants we need in target dictionary and meta compiler
\ UART Registers
0xFF4906 2constant UART_CLEAR_RX_INT_REG
0xFF4904 2constant UART_CLEAR_TX_INT_REG
0xFF4900 2constant UART_CTRL_REG
0xFF490A 2constant UART_CTRL2_REG
0xFF4902 2constant UART_RX_TX_REG


META+TARGET>
: MOVD_IMM32 ( im32 reg -- ) 0x0070 or , , , ;             \ movd imm32 opcode 0000 0000 0111 xxxx fmt23

META>
:code init-pstack PSTACK_END PSPL MOVD_IMM32 ;              \ inititalize parameter stack
:code init-rstack ( -- )                                    \ inititalize return stack
                  RSTACK_END SP_L MOVD_IMM32 ;
:code init-istack ( -- )                                    \ initialize interrupt stack pointer
                  ISTACK_END TOS  MOVD_IMM32
                  TOS        ISP  LPRD ;
META>
VARIABLE CP         \ code pointer point to next adress in dictionary space
: org  CP ! ;
: here CP @ ;
: ALLOT here + CP ! ;
: cold ( -- )       \ reserve space for the FORTH entry jump
                    \ relocate dictionary to next adress
			        \ place the jump to FORTH entry
	here            \ remember origin for jump code
	2 CELLS allot   \ reserve space for the FORTH entry jump
	relocate        \ relocate dictionary to address after jump
	here            \ get new code pointer location
	2swap           \ swap with jump code location
	CP  !           \ compile pointer to jump code location
	' FORTH         \ get adress of FORTH entry from dictionary
	BAL(RA)         \ compile jump to FORTH entry
	CP  !           \ restore original code pointer location
	;

0x10080 org      \ image starts in RAM 

init-pstack
init-rstack
init-istack
init-int-vec
init-cfg
cold

