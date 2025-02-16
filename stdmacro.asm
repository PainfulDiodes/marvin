MACRO PADORG addr
    IF $ < addr
    BLOCK addr-$
    ENDIF
    ORG addr
ENDM