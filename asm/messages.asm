    PUBLIC WELCOME_MSG
    PUBLIC BAD_CMD_MSG
    PUBLIC CMD_W_NULL_MSG
    PUBLIC BASIC_PROMPT_MSG

WELCOME_MSG:
                db "MARVIN v1.2.1\n"
                db "A simple Z80 homebrew monitor program\n"
                db "(c) Stephen Willcock 2024\n"
                db "https://github.com/PainfulDiodes\n",0

BAD_CMD_MSG:    
                db "Command not recognised\n",0

CMD_W_NULL_MSG:
                db "No data to write\n",0

BASIC_PROMPT_MSG:
                db "BBC BASIC\nw: warm start\nc: cold start\n",0