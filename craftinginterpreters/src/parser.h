#include "lox.h"

bool isAtEnd(Parser *parser);
bool match(Parser *parser, int count, ...);
Token consume(Lox *lox, TokenType type, const char *message);
Token advance(Parser *parser);
Token previous(Parser *parser);
Token peek(Parser *parser);
