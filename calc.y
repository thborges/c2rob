
%{
#include "nodes.h"

int yyerror(const char *s);
int yylex(void);
int errorcount = 0;
extern bool force_print_tree;
%}

%define parse.error verbose
%define parse.trace

%union {
    char *str;
    int64_t itg;
    double flt;
    Node *node;
}

%token TOK_IDENT 
%token TOK_PRINT
%token TOK_FLOAT
%token TOK_INT

%token TOK_LARGE_EQUAL
%token TOK_LESS_EQUAL

%type<str> TOK_IDENT
%type<itg> TOK_INT
%type<flt> TOK_FLOAT
%type<node> globals global expr term factor unary array_decl 
%type<node> array_values array_value
%type<node> locals local scalar scalar_init array

%printer { fprintf(yyo, "%s", $$); } <str>
%printer { fprintf(yyo, "%lld", $$); } <itg>
%printer { fprintf(yyo, "%lf", $$); } <flt>

%printer { fprintf(yyo, "%s",
    $$->toDebug().c_str()); } <node>

%start program

%%

program : globals {
    Node *program = new Program();
    program->append($globals);

    // aqui vai a analise semantica
    CheckVarDecl cvd;
    cvd.check(program);

    CheckVarTypeMixed cvt;
    cvt.check(program);

    if (errorcount > 0)
        cout << errorcount << " error(s) found." << endl;
    if (errorcount == 0 || force_print_tree) 
        printf_tree(program);
}

globals : globals[gg] global {
    $gg->append($global);
    $$ = $gg;
}

globals : global {
    Node *n = new Node();
    n->append($global);
    $$ = n;
}

global : scalar
       | scalar_init
       | array
       ;

/* function decl */
global : TOK_IDENT[type] TOK_IDENT[name] '(' TOK_IDENT[void] ')' ';' {
    $$ = new Function($type, $name, nullptr);
}

/* function impl */
global : TOK_IDENT[type] TOK_IDENT[name] '(' TOK_IDENT[void] ')' '{' locals '}' {
    $$ = new Function($type, $name, nullptr, $locals);
}

global : error ';' { $$ = new Node(); }

locals : locals[gg] local {
    $gg->append($local);
    $$ = $gg;
}

locals : local {
    Node *n = new Node();
    n->append($local);
    $$ = n;
}

local : scalar
      | scalar_init
      | array
      ; 

/* scalars */
scalar_init : TOK_IDENT[type] TOK_IDENT[name] '=' expr ';' {
    $$ = new Variable($type, $name, $expr);
}

/* not initialized scalars */
scalar : TOK_IDENT[type] TOK_IDENT[name] ';' {
    $$ = new Variable($type, $name);
}

/* arrays */
array : TOK_IDENT[type] TOK_IDENT[name] '[' expr[idx] ']' '=' array_decl[value] ';' {
    $$ = new Variable($type, $name, $idx, $value);
}

array_decl : '{' array_values '}' { $$ = $array_values; } ;

array_values : array_values[gg] ',' array_value {
    $gg->append($array_value);
    $$ = $gg;
}

array_values : array_value {
    Node *n = new Node();
    n->append($array_value);
    $$ = n;
}

array_value : factor ;

expr : expr[ee] '+' term {
    $$ = new BinaryOp($ee, $term, '+');
}

expr : expr[ee] '-' term {
    $$ = new BinaryOp($ee, $term, '-');
}

expr : term {
    $$ = $term;
}

term : term[tt] '*' factor {
    $$ = new BinaryOp($tt, $factor, '*');
}

term : term[tt] '/' factor {
    $$ = new BinaryOp($tt, $factor, '/');
}

term : factor {
    $$ = $factor;
}

factor : '(' expr ')' {
    $$ = $expr;
}

factor : TOK_IDENT[str] {
    $$ = new Ident($str);
}

factor : TOK_INT[itg] {
    $$ = new Integer($itg);
}

factor : TOK_FLOAT[flt] {
    $$ = new Float($flt);
}

factor : unary[u] {
    $$ = $u;
}

unary : '-' factor[f] {
    $$ = new Unary($f, '-');
}


%%



