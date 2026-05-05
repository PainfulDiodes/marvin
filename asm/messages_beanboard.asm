    PUBLIC WELCOME_MSG
    PUBLIC BAD_CMD_MSG
    PUBLIC CMD_W_NULL_MSG
    PUBLIC HELP_MSG
    PUBLIC BDFS_HELP_MSG

WELCOME_MSG:
                db "PainfulDiodes\n"
                db "MARVIN Z80 monitor\n"
                db "2026-05-05\n",0


BAD_CMD_MSG:    
                db "Bad command\n",0

CMD_W_NULL_MSG:
                db "No data\n",0

HELP_MSG:
                db "r=read w=write x=exec\n"
                db ":=hex b/B=BASIC ?=help\n",0

BDFS_HELP_MSG:
                db "@A-F=drive d=dir f=fmt\n",0
