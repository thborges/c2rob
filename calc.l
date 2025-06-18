
%{
#include <stdio.h>
#include <stdlib.h>

char *build_file_name;
bool force_print_tree = false;
class Node;
#include "calc.tab.h"

int yyerror(const char *s);

%}

%option yylineno

%x COMMENT

%%

[ \t\r\n] { /* ignora */ }
"/*"					{ yymore(); BEGIN COMMENT; }
<COMMENT>[^*]			{ yymore(); }
<COMMENT>"*"/[^/]		{ yymore(); }
<COMMENT>"*/"			{ BEGIN(INITIAL); }

"//".*\n { /* ignora */ }

"#include".* { /* ignora */ }

"static" { /* ignore */ }
"volatile" { /* ignore */ }
"print" { return TOK_PRINT; }

">=" { return TOK_LARGE_EQUAL; }
"<=" { return TOK_LESS_EQUAL; }
"+" { return '+'; }
"-" { return '-'; }
"*" { return '*'; }
"/" { return '/'; }
"(" { return '('; }
")" { return ')'; }
";" { return ';'; }
"=" { return '='; }
"[" { return '['; }
"]" { return ']'; }
"{" { return '{'; }
"}" { return '}'; }
">" { return '>'; }
"<" { return '<'; }
"," { return ','; }
"&" { return '&'; }
"|" { return '|'; }
"\"" { return '\"'; }
"'" { return '\''; }
"%" { return '%'; }
"^" { return '^'; }

[a-zA-Z_][a-zA-Z0-9_]* {
    yylval.str = strndup(yytext, yyleng);
    return TOK_IDENT;
}

[0-9]+\.[0-9]* {
    yylval.flt = atof(yytext);
    return TOK_FLOAT;
}

[0-9]+U*L* {
    yylval.itg = atoi(yytext);
    return TOK_INT;
}

"0x"[0-9a-fA-F]+U*L* {
    char *aux = strndup(yytext, yyleng);
	yylval.itg = strtoull(aux, NULL, 16);
	free(aux);
	return TOK_INT;
}

. { 
    printf("Símbolo não reconhecido %c\n", yytext[0]);
  }


%%

int yywrap() {
    return 1;
}

extern int errorcount;
extern int yydebug;

int yyerror(const char *s) {
    printf("%s:%d:0: %s\n", 
        build_file_name, yylineno, s);
    errorcount++;
    return 1;
}

int main(int argc, char *argv[]) {
    
    if (argc <= 1) {
        printf("Sintaxe: %s nome_do_programa\n",
            argv[0]);
        return 1;
    }

    int build_file_id = 1;

    if (strcmp(argv[1], "-f") == 0) {
        force_print_tree = true;
        build_file_id++;
    }

    build_file_name = argv[build_file_id];
    yyin = fopen(build_file_name, "r");
    if (yyin == NULL) {
        printf("Não foi possível abrir o arquivo %s.\n", build_file_name);
        return 1;
    }

    //yydebug = 1;
    yyparse();

    if (yyin)
        fclose(yyin);
    
    return 0;
}



