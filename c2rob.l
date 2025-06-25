
%{
#include <stdio.h>
#include <stdlib.h>

char *build_file_name;
bool force_print_tree = false;
class Node;

#include "c2rob.tab.h"

int yyerror(const char *s);
int yycolno = 0;

#define YY_USER_ACTION  yycolno += yyleng;
%}

%option yylineno

%x COMMENT

%%

[ \t\r] { /* ignora */ }
[\n] { yycolno = 0; }

"/*"					{ yymore(); BEGIN COMMENT; }
<COMMENT>[^*]			{ yymore(); }
<COMMENT>"*"/[^/]		{ yymore(); }
<COMMENT>"*/"			{ BEGIN(INITIAL); }

"//".*\n { /* ignora */ }

#include[\t ]*[<"].*[>"] {
    yylval.str = strndup(yytext, yyleng); 
    return TOK_INCLUDE;
}

"if"     { return TOK_IF; }
"else"   { return TOK_ELSE; }
"for"    { return TOK_FOR; }
"return" { return TOK_RETURN; }
"struct" { return TOK_STRUCT; }

"static"    { return TOK_STATIC; }
"volatile"  { return TOK_VOLATILE; }
"const"     { return TOK_CONST; }

">"  { yylval.str = ">";  return TOK_CMP_RELAT; }
"<"  { yylval.str = "<";  return TOK_CMP_RELAT; }
">=" { yylval.str = ">="; return TOK_CMP_RELAT; }
"<=" { yylval.str = "<="; return TOK_CMP_RELAT; }
"==" { yylval.str = "=="; return TOK_CMP_EQNEQ; }
"!=" { yylval.str = "!="; return TOK_CMP_EQNEQ; }

"++" { yylval.str = "++"; return TOK_UNARY_OPERATOR; }
"--" { yylval.str = "--"; return TOK_UNARY_OPERATOR; }

"&&" { return TOK_AND; }
"||" { return TOK_OR; }

"-" { return '-'; } // has two meanings: binary and unary operator
"/" { return '/'; }
"+" { return '+'; }
"%" { return '%'; }
"|" { return '|'; }
"&" { return '&'; }
"^" { return '^'; }
"!" { return '!'; }
"~" { return '~'; }

  /* attributions */
"="  { return '='; } // has two meanings: initialized decl and set variable values
"+=" { yylval.str = "+="; return TOK_ATTRIBUTION; }
"-=" { yylval.str = "-="; return TOK_ATTRIBUTION; }
"*=" { yylval.str = "*="; return TOK_ATTRIBUTION; }
"/=" { yylval.str = "/="; return TOK_ATTRIBUTION; }
"^=" { yylval.str = "^="; return TOK_ATTRIBUTION; }
"|=" { yylval.str = "|="; return TOK_ATTRIBUTION; }
"&=" { yylval.str = "&="; return TOK_ATTRIBUTION; }

"*" { return '*'; } // multiple meanings

";" { return ';'; }
"(" { return '('; }
")" { return ')'; }
"[" { return '['; }
"]" { return ']'; }
"{" { return '{'; }
"}" { return '}'; }
"," { return ','; }
":" { return ':'; }
"\." { return '.'; }

[a-zA-Z_][a-zA-Z0-9_\.]* {
    yylval.str = strndup(yytext, yyleng);
    return TOK_IDENT;
}

[0-9]+\.[0-9]* {
    yylval.flt = atof(yytext);
    return TOK_FLOAT;
}

[0-9]+U*L* {
    while (yytext[yyleng-1] == 'L')
        yyleng--;
    yylval.str = strndup(yytext, yyleng);
    return TOK_STRING;
}

"0x"[0-9a-fA-F]+U*L* {
    while (yytext[yyleng-1] == 'L')
        yyleng--;
    yylval.str = strndup(yytext, yyleng);
	return TOK_STRING;
}

\"([^\\\"]|\\.)*\"		{ yylval.str = strndup(yytext, yyleng);
						  return TOK_STRING; }

'\\?.'					{ yylval.itg = yytext[0];
						  return TOK_CHAR; }

. { 
    fprintf(stderr, "%s:%d:%d: Símbolo não reconhecido %c\n", build_file_name, yylineno, yycolno, yytext[0]);
  }


%%

int yywrap() {
    return 1;
}

extern int errorcount;
extern int yydebug;

int yyerror(const char *s) {
    fprintf(stderr, "%s:%d:%d: %s\n", 
        build_file_name, yylineno, yycolno, s);
    errorcount++;
    return 1;
}

int main(int argc, char *argv[]) {
    
    if (argc <= 1) {
        fprintf(stderr, "Sintaxe: %s nome_do_programa\n",
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
        fprintf(stderr, "Não foi possível abrir o arquivo %s.\n", build_file_name);
        return 1;
    }

    //yydebug = 1;
    yyparse();

    if (yyin)
        fclose(yyin);
    
    return errorcount;
}



