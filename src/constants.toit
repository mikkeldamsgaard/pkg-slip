SLIP_DELIMETER_      ::= 0xC0
SLIP_ESCAPE_         ::= 0xDB
SLIP_C0_REPLACEMENT_ ::= #[SLIP_ESCAPE_, 0xDC]
SLIP_DB_REPLACEMENT_ ::= #[SLIP_ESCAPE_, 0xDD]
SLIP_DELIMETER_BUF_  ::= #[SLIP_DELIMETER_]
