
%{
#include <stdio.h>
%}

%%

"//".*\n { /* ignora */ }

"print" { return TOK_PRINT; }

"+" { return '+'; }
"-" { return '-'; }
"*" { return '*'; }
"/" { return '/'; }
"(" { return '('; }
")" { return ')'; }
";" { return ';'; }
"=" { return '='; }

[a-zA-Z_][a-zA-Z0-9_]* {
    return TOK_IDENT;
}

[0-9]+\.[0-9]* {
    return TOK_FLOAT;
}

[0-9]+ {
    return TOK_INT;
}

. { 
    printf("Símbolo não reconhecido %c\n", yytext[0]);
  }


%%

int main() {

}

