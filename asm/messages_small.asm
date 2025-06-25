ALIGN 0x10

welcome_msg:    
                db "PainfulDiodes\n"
                db "MARVIN Z80 monitor\n"
                db "v1.2\n",0


ALIGN 0x10

BAD_CMD_MSG:    
                db "Bad command\n",0

ALIGN 0x10

CMD_W_NULL_MSG: 
                db "No data\n",0