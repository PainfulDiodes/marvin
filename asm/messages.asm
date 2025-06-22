ALIGN 0x10

welcome_msg:
                db "MARVIN v1.2\n"
                db "A simple Z80 homebrew monitor program\n"
                db "(c) Stephen Willcock 2024\n"
                db "https://github.com/PainfulDiodes\n\n",0

ALIGN 0x10

bad_cmd_msg:    
                db "Command not recognised\n",0

ALIGN 0x10

cmd_w_null_msg: 
                db "No data to write\n",0