ALIGN 0x10

welcome_msg:    
                db "PainfulDiodes\n"
                db "MARVIN Z80 monitor\n"
                db "v1.2\n",0


ALIGN 0x10

bad_cmd_msg:    
                db "Bad command\n",0

ALIGN 0x10

cmd_w_null_msg: 
                db "No data\n",0