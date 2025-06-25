ALIGN 0x10

welcome_msg:
                db "MARVIN v1.2\n"
                db "A simple Z80 homebrew monitor program\n"
                db "(c) Stephen Willcock 2024\n"
                db "https://github.com/PainfulDiodes\n\n",0

ALIGN 0x10

BAD_CMD_MSG:    
                db "Command not recognised\n",0

ALIGN 0x10

CMD_W_NULL_MSG: 
                db "No data to write\n",0