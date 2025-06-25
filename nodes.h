
#include <iostream>
#include <vector>
#include <map>
#include <set>
#include <regex>
#include <format>

extern int errorcount;
extern int yylineno;
extern char *build_file_name;

using namespace std;

class Type;
map<string, Type*> declared_types;

class Node {
protected:
    vector<Node*> children;
    int lineno;

    string identation(int level) {
        string result;
        while (level > 0) {
            result += "\t";
            level--;
        }
        return result;
    }

public:
    Node() {
        lineno = yylineno;
    }
    int getLineNo() {
        return lineno;
    }
    virtual string toStr(int il) {
        string sb;
        for(Node *n : children) {
            sb += n->toStr(il+1);
        }
        return sb;
    }
    void append(Node *n) {
        children.push_back(n);
    }
    vector<Node*>& getChildren() {
        return children;
    }
    
    virtual const string getName() {
        return "";
    }
};

class Container : public Node {
public:
    virtual string toStr(int il) override {
        return "\n" + Node::toStr(il-1);
    }
};

class StmtContainer : public Node {
protected:
    Node *node;
public:
    StmtContainer(Node *_node) {
        node = _node;
    }

    virtual string toStr(int il) override {
        return identation(il) + node->toStr(il-1) + ";\n";
    }
};

class Program : public Node {
public:
};

class Integer : public Node {
protected:
    int value;
public:
    Integer(const int v) {
        value = v;
    }

    virtual string toStr(int il) override {
        return to_string(value);
    }
};

class Float : public Node {
protected:
    float value;
public:
    Float(const float v) {
        value = v;
    }

    virtual string toStr(int il) override {
        return to_string(value);
    }
};

class Ident : public Node {
protected:
    string name;
public:
    Ident(const string n) {
        name = n;
    }

    virtual string toStr(int il) override {
        return name;
    }
};

class Return : public Node {
protected:
    Node *expr;
public:
    Return(Node *e) {
        expr = e;
    }

    virtual string toStr(int il) override {
        return identation(il) + "return " + expr->toStr(0) + ";\n";
    }
};

class IfStmt : public Node {
protected:
    Node *cmp = nullptr;
    Node *localsIf = nullptr;
    Node *localsElse = nullptr;
public:
    IfStmt(Node *_cmp, Node *_if) {
        cmp = _cmp;
        localsIf = _if;
    }

    IfStmt(Node *_cmp, Node *_if, Node *_else) {
        cmp = _cmp;
        localsIf = _if;
        localsElse = _else;
    }

    virtual string toStr(int il) override {
        string elsestr = "\n";
        if (localsElse) {
            elsestr = " else {\n";
            
            int elseil = il;
            if (localsElse->getChildren().size() == 0) // one line else stmt
                elseil += 1;
            elsestr += localsElse->toStr(elseil);
            
            elsestr += identation(il) + "}\n";
        }
        string result = "\n" + identation(il);
        result += "if ";
        
        result += cmp->toStr(0);
        // if (a) {...} -> if (a != 0) {...}
        if (cmp->getChildren().size() == 0)
            result += " != 0";

        result += " {\n";

        int ifil = il;
        if (localsIf->getChildren().size() == 0) // one line if stmt
            ifil += 1;
        result += localsIf->toStr(ifil);
        
        result += identation(il);
        result += "}";
        result += elsestr;
        result += "\n";
        return result;
    }
};

class LoadArray : public Node {
protected:
    string name;
    Node *expr = nullptr;
public:
    LoadArray(const string n, Node *e) {
        name = n;
        expr = e;
    }

    virtual string toStr(int il) override {
        return name + "[" + expr->toStr(il)+ "]";
    }
};

class LoadArrayField : public Node {
protected:
    string name, field;
    Node *expr = nullptr;
public:
    LoadArrayField(const string _name, Node *_expr, const string _field) {
        name = _name;
        expr = _expr;
        field = _field;
    }

    virtual string toStr(int il) override {
        string result = "aux = " + name + "[" + expr->toStr(0)+ "];\n";
        result += identation(il) + "aux." + field;
        return result;
    }
};

class VariableDecl : public Node {
protected:
    string name;
    string type;
    Node *value = nullptr;
    Node *idx = nullptr;
public:
    VariableDecl(const string t, const string n, Node *v) {
        name = n;
        type = convertTypeToRob(t);
        value = v;
        children.push_back(v);
    }

    VariableDecl(const string t, const string n) {
        name = n;
        type = convertTypeToRob(t);
    }

    VariableDecl(const string t, const string n, int bitfield) {
        name = n;
        type = convertTypeToRob(t);
        size_t first_number = type.find_first_of("0123456789");
        if (first_number != string::npos)
            type = type.substr(0, first_number);
        if (type == "int")
            type = "uint";
        type += std::to_string(bitfield);
    }

    VariableDecl(const string t, const string n, Node *i, Node *v) {
        name = n;
        type = convertTypeToRob(t);
        value = v;
        idx = i;
    }

    const string getName() override {
        return name;
    }

    static string convertTypeToRob(string type) {
        std::regex inttypes("u?int[0-9]+_t");
        if (regex_match(type, inttypes))
            return type.substr(0, type.length()-2);
        
        std::regex pointertypes("[a-z0-9]+ ?\\*");
        if (regex_match(type, pointertypes))
            return type.substr(0, type.length()-1) + "[]";

        if (type == "int" || type == "signed")
            return "int32";

        if (type == "long")
            return "int64";

        if (type == "unsigned")
            return "uint32";

        return type;
    }

    virtual string toStr(int il) override {
        string result = identation(il);
        if (idx && value) {
            result += format("{} = {{{}}}", name, value->toStr(0));
        } else if (idx) {
            string values;
            for(int i = 0; i < atoi(idx->toStr(0).c_str()); i++) {
                if (i == 0) values += type + "(0)";
                else values += ", 0";
            }
            result += format("{} = {{{}}}", name, values);
        } else if (value) {
            result += format("{} = {}({})", name, type, value->toStr(0));
        } else {
            result += format("{} = {}(0)", name, type);
        }
        result += ";\n";
        return result;
    }
};


class NodeArgs : public Node {
private:
    string arrayInitType = "";
public:
    NodeArgs() {
    }
    void setArrayInitType(string type) {
        arrayInitType = VariableDecl::convertTypeToRob(type);
    }
    virtual string toStr(int il) override {
        string sb;
        if (arrayInitType != "")
             sb += arrayInitType + "(" + children[0]->toStr(0) + ")";
        else
            sb += children[0]->toStr(0);

        for(int i = 1; i < children.size(); i++) {
            sb += ", " + children[i]->toStr(0);
        }
        return sb;
    }
};


class StructVariableDecl : public Node {
protected:
    string name;
    string type;
    Node *value = nullptr;
    Node *idx = nullptr;
public:
    StructVariableDecl(const string t, const string n, Node *i, Node *v) {
        name = n;
        type = VariableDecl::convertTypeToRob(t);
        value = v;
        idx = i;
    }

    const string getName() override {
        return name;
    }

    virtual string toStr(int il) override {
        string result = identation(il);
        //struct S1 l_3[2] = {{-30,-762},{-30,-762}};
        //l_3 = {S1():2}
        result += format("{} = {{{}():{}}}", name, type, idx->toStr(0));
        result += ";\n";
        return result;
    }
};


class FuncArg : public Node {
protected:
    string name;
    string type;
public:
    FuncArg(const string t, const string n) {
        name = n;
        type = t;
    }

    virtual string toStr(int il) override {
        string newType = VariableDecl::convertTypeToRob(type);
        return newType + " " + name;
    }
};

class Store : public Node {
protected:
    Node *left;
    string op;
    Node *value = nullptr;
public:
    Store(Node *_left, string _op, Node *_value) {
        left = _left;
        op = _op;
        value = _value;
    }

    virtual string toStr(int il) override {
        string result = identation(il);
        result += left->toStr(il);
        result += " ";
        result += op;
        result += " ";
        result += value->toStr(il);
        result += ";\n";
        return result;
    }
};


class Type : public Node {
protected:
    string name;
    Node *fields = nullptr;
public:
    Type(const string n, Node *fs) {
        name = n;
        fields = fs;
        declared_types[name] = this;
    }

    virtual string toStr(int il) override {
        string result = "\ntype ";
        result += name + "{\n";
        result += fields->toStr(il+1);
        result += "}\n\n";
        return result;
    }

    Node* getFields() {
        return fields;
    }
};

class InitializedType : public Node {
protected:
    string name;
    string type;
    Node *initvalues = nullptr;
public:
    InitializedType(const string _type, const string _name, Node *_initvalues) {
        type = _type;
        name = _name;
        initvalues = _initvalues;
    }

    virtual string toStr(int il) override {
        string result = identation(il);
        result += name;
        result += " = ";
        result += type + "();\n";
        
        auto fields = declared_types[type]->getFields();
        auto inits = initvalues->getChildren();
        int i = 0;
        for(Node *f : fields->getChildren()) {
            result += identation(il);
            result += name + "." + f->getName();
            result += " = " + inits[i]->toStr(0);
            result += ";\n";
            i++;
        }

        result += "\n";
        return result;
    }
};

class TypeFields : public Node {
public:
    TypeFields() {
    }
    virtual string toStr(int il) override {
        string sb;
        for(int i = 0; i < children.size(); i++) {
            sb += identation(il) + children[i]->toStr(0);
        }
        return sb;
    }
};

class Function : public Node {
protected:
    string name;
    string type;
    Node *args = nullptr;
    Node *commands = nullptr;
public:
    Function(const string t, const string n, Node *a) {
        name = n;
        type = VariableDecl::convertTypeToRob(t);
        args = a;
        children.push_back(a);
    }

    Function(const string t, const string n, Node *a, Node *c) {
        name = n;
        type = VariableDecl::convertTypeToRob(t);
        args = a;
        commands = c;
        children.push_back(a);
        children.push_back(c);
    }

    virtual string toStr(int il) override {
        string sargs;
        if (args) {
            sargs += args->toStr(il);
        }
        string stmts;
        if (commands) {
            stmts += commands->toStr(il);
        }
        string result = "\n";
        result += type;
        result += " ";
        result += name;
        result += '(';
        result += sargs;
        result += ')';
        if (!commands)
            result += ";\n";
        else {
            result += " {\n";
            result += stmts;
            result += "}\n\n";
        }
        return result;
    }
};

class FunctionCall : public Node {
protected:
    string name;
    Node *args = nullptr;
    bool inExpr = true;
public:
    FunctionCall(const string n) {
        name = n;
    }

    FunctionCall(const string n, Node *a) {
        name = n;
        args = a;
    }

    void setInExpr(bool v) {
        inExpr = v;
    }

    virtual string toStr(int il) override {
        string result;
        
        if (!inExpr)
            result += identation(il);
        
        result += name;
        result += "(";
        if (args) {
            result += args->toStr(0);
        }
        result += ")";
        
        if (!inExpr)
            result += ";\n";
        
        return result;
    }
};

class While : public Node {
protected:
    Node *logicexpr = nullptr;
    Node *commands = nullptr;
public:
    While(Node *expr, Node *comm) {
        logicexpr = expr;
        commands = comm;
    }

    virtual string toStr(int il) override {
        string result = identation(il);
        result += "while ";
        result += logicexpr->toStr(0);
        result += " {\n";
        result += commands->toStr(il);
        result += identation(il);
        result += "}\n\n";
        return result;
    }
};

class Unary : public Node {
protected:
    Node *value;
    string operation;

public:
    Unary(Node *v, string op) {
       value = v;
       operation = op;
       children.push_back(v);
    }

    virtual string toStr(int il) override {
        if (operation == "!" || operation == "-" || operation == "~")
            return operation + value->toStr(0);
        else
            return value->toStr(0) + operation;
    }

    friend class UnaryAttribution;
};

class UnaryAttribution : public Unary {
public:
    UnaryAttribution(Node *v, string op) : Unary(v, op) {}
    UnaryAttribution(Unary *un) : Unary(un->value, un->operation) {}
    virtual string toStr(int il) override {
        return identation(il) + value->toStr(0) + operation + ";\n";
    }
};

class BinaryOp : public Node {
protected:
    Node *value1;
    Node *value2;
    string operation;

public:
    BinaryOp(Node *v1, Node *v2, string op) {
       value1 = v1;
       value2 = v2;
       operation = op;
       children.push_back(v1);
       children.push_back(v2);
    }

    virtual string toStr(int il) override {
        string v1 = value1->toStr(0);
        string v2 = value2->toStr(0);
        if (operation == "and" || operation == "or") {
            if (value1->getChildren().size() == 0) {
                v1 = "(" + v1 + " != 0)";
            }
            if (value2->getChildren().size() == 0) {
                v2 = "(" + v2 + " != 0)";
            }
        }
        string result = v1;
        result += " ";
        result += operation;
        result += " ";
        result += v2;
        return result;
    }
};

class Qualifiers : public Node {
public:
    Qualifiers() {
    }
    virtual string toStr(int il) override {
        string sb = children[0]->toStr(0);
        for(int i = 1; i < children.size(); i++) {
            sb += " " + children[i]->toStr(0);
        }
        return sb;
    }
};

class Parenthesis : public Node {
private:
    Node *node;
public:
    Parenthesis(Node *n) : node(n) {
    }
    virtual string toStr(int il) override {
        return "(" + node->toStr(0) + ")";
    }
};
