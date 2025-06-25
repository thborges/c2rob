
%{
#include "nodes.h"

int yyerror(const char *s);
int yylex(void);
int errorcount = 0;
extern bool force_print_tree;
%}

%define parse.error detailed
%define parse.trace
%define parse.lac full

%union {
    const char *str;
    int64_t itg;
    double flt;
    Node *node;
}

%token TOK_IDENT TOK_ATTRIBUTION
%token TOK_FLOAT TOK_INT
%token TOK_OR TOK_AND TOK_CHAR
%token TOK_CMP_EQNEQ TOK_CMP_RELAT TOK_UNARY_OPERATOR TOK_STRING
%token TOK_IF TOK_ELSE TOK_FOR TOK_RETURN
%token TOK_INCLUDE TOK_STRUCT
%token TOK_STATIC TOK_VOLATILE TOK_CONST

%type<str> TOK_STRING TOK_IDENT TOK_CMP_EQNEQ TOK_CMP_RELAT TOK_UNARY_OPERATOR TOK_ATTRIBUTION
%type<str> TOK_INCLUDE
%type<itg> TOK_INT
%type<flt> TOK_FLOAT
%type<node> globals global expr factor array_decl array_init_decl
%type<node> array_values array_values_decls array_values_decl struct_values_decl
%type<node> locals local scalar_decl scalar_init_decl attribution
%type<node> scalar_or_array
%type<node> func_arg func_args func_decl func_impl function_call func_call_args
%type<node> ifstmt elseblock forstmt returnstmt include
%type<node> struct_decl struct_field struct_fields
%type<node> qualifiers qualifier

%printer { fprintf(yyo, "%s", $$); } <str>
%printer { fprintf(yyo, "%lld", $$); } <itg>
%printer { fprintf(yyo, "%lf", $$); } <flt>

%left TOK_OR
%left TOK_AND
%left TOK_CMP_EQNEQ
%left TOK_CMP_RELAT
%left '|'
%left '^'
%left '&'
%left '+' '-'
%left '*' '/' '%'
%right UMINUS
%right '!' '~'
%left '(' ')'

%start program

%%

program : globals {
    Node *program = $globals;

    if (errorcount == 0 || force_print_tree) 
        cout << program->toStr(-1);
    
    exit(errorcount);
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

global : qualifiers scalar_decl ';'         { $$ = $2; }
       | qualifiers scalar_init_decl ';'    { $$ = $2; }
       | qualifiers array_init_decl ';'     { $$ = $2; }
       | qualifiers array_decl ';'          { $$ = $2; }
       | qualifiers func_decl ';'           { $$ = $2; }
       | qualifiers func_impl               { $$ = $2; }
       | scalar_decl ';'
       | scalar_init_decl ';'
       | array_init_decl ';'
       | array_decl ';'
       | func_decl ';'
       | func_impl
       | include
       | struct_decl
       ;

qualifiers : qualifiers[gg] qualifier {
    $gg->append($qualifier);
    $$ = $gg;
}

qualifiers : qualifier {
    Node *n = new Qualifiers();
    n->append($qualifier);
    $$ = n;
}

qualifier : TOK_CONST       { $$ = new Ident("const"); }
          | TOK_VOLATILE    { $$ = new Ident("volatile"); }
          | TOK_STATIC      { $$ = new Ident("static"); }
          | TOK_STRUCT      { $$ = new Ident("struct"); }
          ;

include : TOK_INCLUDE[name] {
    string name($name);
    size_t start = name.find_first_of("<\"") + 1;
    name = name.substr(start, name.length()-3-start);
    $$ = new Ident("use " + name + ";\n");
}

struct_decl : TOK_STRUCT TOK_IDENT[name] '{' struct_fields '}' ';' {
    $$ = new Type($name, $struct_fields);
}

struct_fields : struct_fields[gg] struct_field {
    $gg->append($struct_field);
    $$ = $gg;
}

struct_fields : struct_field {
    Node *n = new TypeFields();
    n->append($struct_field);
    $$ = n;
}

struct_field : scalar_decl ';' {
    $$ = $scalar_decl;
}

struct_field : qualifiers scalar_decl ';' {
    $$ = $scalar_decl;
}

struct_field : TOK_IDENT[type] TOK_IDENT[name] ':' TOK_STRING[bitfield] ';' {
    $$ = new VariableDecl($type, $name, atoi($bitfield));
}

func_decl : TOK_IDENT[type] TOK_IDENT[name] '(' func_args ')' {
    $$ = new Function($type, $name, $func_args);
}

func_impl : TOK_IDENT[type] TOK_IDENT[name] '(' func_args ')' '{' locals '}' {
    $$ = new Function($type, $name, $func_args, $locals);
}

func_args : func_args[gg] ',' func_arg {
    $gg->append($func_arg);
    $$ = $gg;
}

func_args : func_arg {
    Node *n = new NodeArgs();
    n->append($func_arg);
    $$ = n;
}

// void func(void)
func_args : TOK_IDENT[type] {
    $$ = new Ident(""); // unamed parameter is not used, ignore them
}

func_arg : TOK_IDENT[type] TOK_IDENT[name] {
    $$ = new FuncArg($type, $name);
}

func_arg : TOK_IDENT[type] '*' TOK_IDENT[name] {
    string atype = $type;
    atype.push_back('*'); //TODO: check what to do with pointers as rob doesn't have them
    $$ = new FuncArg(atype, $name);
}

func_arg : TOK_IDENT[type] '*' TOK_IDENT[name] '[' ']' {
    string atype = $type;
    atype.push_back('*'); //TODO: check what to do with pointers as rob doesn't have them
    $$ = new FuncArg(atype, $name); //TODO: need [] or is just main arg?
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

local : qualifiers scalar_decl ';'      { $$ = $2; }
      | qualifiers scalar_init_decl ';' { $$ = $2; }
      | qualifiers array_init_decl ';'  { $$ = $2; }
      | qualifiers array_decl ';'       { $$ = $2; }
      | scalar_decl ';'
      | scalar_init_decl ';'
      | array_init_decl ';'
      | array_decl ';'
      | attribution ';'
      | function_call ';'   { ((FunctionCall*)$1)->setInExpr(false); $$ = $1; }
      | ifstmt
      | forstmt
      | returnstmt
      ; 

returnstmt : TOK_RETURN expr ';' {
    $$ = new Return($expr);
}

// a = expr;
attribution : scalar_or_array '=' expr {
    $$ = new Store($scalar_or_array, "=", $expr);
}

// a += expr;
// a[x] -= expr;
attribution : scalar_or_array TOK_ATTRIBUTION[at] expr {
    $$ = new Store($scalar_or_array, $at, $expr);
}

// a--;
attribution : factor[f] TOK_UNARY_OPERATOR[op] {
    $$ = new UnaryAttribution($f, $op);
}

forstmt : TOK_FOR '(' attribution[a1] ';' expr ';' attribution[a2] ')' local {
    Node *nfor = new Container();
    nfor->append($a1);
    Node *body = new Node();
    body->append($local);
    body->append($a2);
    nfor->append(new While($expr, body));
    $$ = nfor;
}

forstmt : TOK_FOR '(' attribution[a1] ';' expr ';' attribution[a2] ')' '{' locals '}' {
    Node *nfor = new Container();
    nfor->append($a1);
    $locals->append($a2);
    nfor->append(new While($expr, $locals));
    $$ = nfor;
}

ifstmt : TOK_IF '(' expr ')' local {
    $$ = new IfStmt($expr, $local);
}

ifstmt : TOK_IF '(' expr ')' local elseblock {
    $$ = new IfStmt($expr, $local, $elseblock);
}

ifstmt : TOK_IF '(' expr ')' '{' locals '}' {
    $$ = new IfStmt($expr, $locals);
}

ifstmt : TOK_IF '(' expr ')' '{' locals '}' elseblock {
    $$ = new IfStmt($expr, $locals, $elseblock);
}

elseblock : TOK_ELSE '{' locals '}' { $$ = $locals; }
elseblock : TOK_ELSE local          { $$ = $local; }

/* scalars */
scalar_init_decl : TOK_IDENT[type] TOK_IDENT[name] '=' expr {
    $$ = new VariableDecl($type, $name, $expr);
}

/* initialized structs */
scalar_init_decl : TOK_IDENT[type] TOK_IDENT[name] '=' array_values_decl[value] {
    $$ = new InitializedType($type, $name, $value);
}

/* not initialized scalars */
scalar_decl : TOK_IDENT[type] TOK_IDENT[name] {
    $$ = new VariableDecl($type, $name);
}

/* arrays */
array_init_decl : TOK_IDENT[type] TOK_IDENT[name] '[' expr[idx] ']' '=' array_values_decl[value] {
    ((NodeArgs*)$value)->setArrayInitType($type);
    $$ = new VariableDecl($type, $name, $idx, $value);
}

array_decl : TOK_IDENT[type] TOK_IDENT[name] '[' expr[idx] ']' {
    $$ = new VariableDecl($type, $name, $idx, nullptr);
}

array_init_decl : TOK_IDENT[type] TOK_IDENT[name] '[' expr[idx] ']' '=' struct_values_decl[value] {
    $$ = new StructVariableDecl($type, $name, $idx, $value);
}

struct_values_decl : '{' array_values_decls[decl] '}' { $$ = $decl; }

array_values_decls : array_values_decls[gg] ',' array_values_decl {
    $gg->append($array_values_decl);
    $$ = $gg;
}

array_values_decls : array_values_decl {
    Node *n = new NodeArgs();
    n->append($array_values_decl);
    $$ = n;
}

array_values_decl : '{' array_values '}' { $$ = $array_values; } ;

array_values : array_values[gg] ',' expr {
    $gg->append($expr);
    $$ = $gg;
}

array_values : expr {
    Node *n = new NodeArgs();
    n->append($expr);
    $$ = n;
}

expr: expr[e1] TOK_CMP_RELAT[op] expr[e2] { $$ = new BinaryOp($e1, $e2, $op); }
expr: expr[e1] TOK_CMP_EQNEQ[op] expr[e2] { $$ = new BinaryOp($e1, $e2, $op); }
expr: expr[e1] TOK_AND expr[e2] { $$ = new BinaryOp($e1, $e2, "and"); }
expr: expr[e1] TOK_OR expr[e2]  { $$ = new BinaryOp($e1, $e2, "or"); }
expr: expr[e1] '+' expr[e2]     { $$ = new BinaryOp($e1, $e2, "+"); }
expr: expr[e1] '-' expr[e2]     { $$ = new BinaryOp($e1, $e2, "-"); }
expr: expr[e1] '*' expr[e2]     { $$ = new BinaryOp($e1, $e2, "*"); }
expr: expr[e1] '/' expr[e2]     { $$ = new BinaryOp($e1, $e2, "/"); }
expr: expr[e1] '%' expr[e2]     { $$ = new BinaryOp($e1, $e2, "%"); }
expr: expr[e1] '&' expr[e2]     { $$ = new BinaryOp($e1, $e2, "&"); }
expr: expr[e1] '|' expr[e2]     { $$ = new BinaryOp($e1, $e2, "|"); }
expr: expr[e1] '^' expr[e2]     { $$ = new BinaryOp($e1, $e2, "^"); }
expr: '!' expr[e1]              { $$ = new Unary($e1, "!"); }
expr: '~' expr[e1]              { $$ = new Unary($e1, "~"); }
expr: '-' expr[e1] %prec UMINUS { $$ = new Unary($e1, "-"); }
expr: '+' expr[e1] %prec UMINUS { $$ = $e1; }
expr: '(' expr[e1] ')'          { $$ = new Parenthesis($e1); }
expr: factor

factor : function_call
factor : scalar_or_array 

factor : TOK_INT[itg] {
    $$ = new Integer($itg);
}

factor : TOK_FLOAT[flt] {
    $$ = new Float($flt);
}

factor : TOK_STRING[str] {
    $$ = new Ident($str);
}

factor : factor[f] TOK_UNARY_OPERATOR[op] {
    $$ = new Unary($f, $op);
}

scalar_or_array : TOK_IDENT[id] {
    $$ = new Ident($id);
}

scalar_or_array : TOK_IDENT[id] '[' expr ']' {
    $$ = new LoadArray($id, $expr);
}

scalar_or_array : TOK_IDENT[id] '[' expr ']' '.' TOK_IDENT[id2] {
    $$ = new LoadArrayField($id, $expr, $id2);
}

function_call : TOK_IDENT[id] '(' ')' {
    $$ = new FunctionCall($id);
}

function_call : TOK_IDENT[id] '(' func_call_args[args] ')' {
    $$ = new FunctionCall($id, $args);
}

func_call_args : func_call_args[gg] ',' expr {
    $gg->append($expr);
    $$ = $gg;
}

func_call_args : expr {
    Node *n = new NodeArgs();
    n->append($expr);
    $$ = n;
}

%%



