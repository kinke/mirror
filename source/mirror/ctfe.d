/**
   This module provides the CTFE variant of compile-time reflection,
   allowing client code to use regular D functions (as opposed to
   template metaprogramming) to operate on the contents of a D module
   using string mixins.
 */

module mirror.ctfe;


/**
   Returns compile-time reflection information about a D module.
 */
Module module_(string moduleName)() {
    import mirror.meta: ModuleTemplate = Module;
    import std.meta: staticMap;

    Module ret;
    ret.name = moduleName;

    alias module_ = ModuleTemplate!moduleName;

    enum toType(T) = UserDefinedType(__traits(identifier, T));
    ret.userDefinedTypes = [ staticMap!(toType, module_.UserDefinedTypes) ];

    enum toVariable(alias V) = Variable(V.Type.stringof, V.name);
    ret.variables = [ staticMap!(toVariable, module_.Variables) ];

    template toFunction(alias F) {

        import std.range: iota;
        import std.meta: aliasSeqOf;
        import std.traits: ReturnType, Parameters, ParameterDefaults, ParameterIdentifierTuple;

        template toDefault(size_t i) {
            static if(is(ParameterDefaults!F[i] == void))
                enum toDefault = "";
            else
                enum toDefault = ParameterDefaults!F[i].stringof;
        }

        template toParameter(size_t i) {
            import std.traits: ParameterStorageClassTuple;

            enum toParameter = Parameter(
                Parameters!F[i].stringof,
                ParameterIdentifierTuple!F[i],
                toDefault!i,
                ParameterStorageClassTuple!F[i],
            );
        }

        enum toFunction = Function(
            __traits(identifier, F),
            UserDefinedType(ReturnType!F.stringof),
            [staticMap!(toParameter, aliasSeqOf!(Parameters!F.length.iota))],
        );
    }
    ret.functions = [ staticMap!(toFunction, module_.Functions) ];

    return ret;
}


/**
   A D module.
 */
struct Module {
    string name;
    UserDefinedType[] userDefinedTypes;
    Variable[] variables;
    Function[] functions;
}


/**
   A user-defined type (struct, class, or enum).
 */
struct UserDefinedType {
    string name;
    // members?
    // member functions?
    // enums / variables?
    // attributes?
}


/// A global variable
struct Variable {
    string type;
    string name;
}


/// A free function
struct Function {
    string name;
    UserDefinedType returnType;
    Parameter[] parameters;
    // attributes?
    // ref/scope/return scope?
}


/// A function parameter
struct Parameter {
    import std.traits: ParameterStorageClass;

    string type;
    string name;
    string default_;  /// default value, if any
    ParameterStorageClass storageClass;
}


// TODO (maybe?):
// * Aliases
// * Module {c,d}tors
// * Unit tests
// * Class hierachies
