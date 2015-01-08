// fth.c



typedef struct UART_CTRL_REG_STRUCT {
	UINT UART_REN  : 1;
	UINT UART_TEN  : 1;
	UINT BAUDRATE  : 3;
	UINT TI        : 1;
	UINT RI        : 1;
	UINT UART_MODE : 1;
	UINT IRDA_EN   : 1;
	UINT INV_URX   : 1;
	UINT INV_UTX   : 1;
} UART_CTRL_REG_T, * UART_CTRL_REG_P;
#define UART_CTRL_REG (*(UART_CTRL_REG_P)0xFF4900)

CHAR tib[TIB_SIZE];
UINT tibcnt;

void initUart()
{
}

void checkUart()
{
	if(bCharReceived())
	{
		tib[tibcnt++]= UART_RX_TX_REG;
	}
}

