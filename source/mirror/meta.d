/**
   This module provides the template metaprogramming variant of compile-time
   reflection, allowing client code to do type-level computations on the
   contents of a D module.
 */
module mirror.meta;


import mirror.traits: moduleOf;


/**
   Compile-time information on a D module.
 */
template Module(string moduleName) {
    import mirror.traits: isPrivate;
    import std.meta: Filter, staticMap, Alias, AliasSeq;

    mixin(`import `, moduleName, `;`);
    private alias mod = Alias!(mixin(moduleName));

    private template member(string name) {

        enum identifier = name;

        static if(__traits(compiles, Alias!(__traits(getMember, mod, name))))
            alias symbol = Alias!(__traits(getMember, mod, name));
        else
            alias symbol = AliasSeq!();
    }

    private alias members = staticMap!(member, __traits(allMembers, mod));
    enum notPrivate(alias member) = !isPrivate!(member.symbol);
    private alias publicMembers = Filter!(notPrivate, members);

    alias Aggregates = aggregates!publicMembers;
    alias Variables = variables!publicMembers;
    alias FunctionsBySymbol = functionsBySymbol!(mod, publicMembers);
    alias FunctionsByOverload = functionsByOverload!(mod, publicMembers);
}


// User-defined types
private template aggregates(publicMembers...) {

    import std.meta: staticMap, Filter;

    private template memberIsType(alias member) {
        import std.traits: isType;
        enum memberIsType = isType!(member.symbol);
    }

    private alias symbolOf(alias member) = member.symbol;

    alias aggregates = staticMap!(symbolOf, Filter!(memberIsType, publicMembers));
}

// Global variables
private template variables(publicMembers...) {
    import std.meta: staticMap, Filter;

    private enum isVariable(alias member) = is(typeof(member.symbol));
    private alias toVariable(alias member) = Variable!(typeof(member.symbol), __traits(identifier, member.symbol));
    alias variables = staticMap!(toVariable, Filter!(isVariable, publicMembers));
}

/**
   A global variable.
 */
template Variable(T, string N) {
    alias Type = T;
    enum name = N;
}


private template functionsBySymbol(alias mod, publicMembers...) {

    import std.meta: Filter, staticMap;

    private template memberIsSomeFunction(alias member) {
        import std.traits: isSomeFunction;
        enum memberIsSomeFunction = isSomeFunction!(member.symbol);
    }

    private alias functionMembers = Filter!(memberIsSomeFunction, publicMembers);

    private alias toFunction(alias member) = FunctionSymbol!(
        member.symbol,
        __traits(getProtection, member.symbol).toProtection,
        __traits(getLinkage, member.symbol).toLinkage,
        member.identifier,
        mod,
        );

    alias functionsBySymbol = staticMap!(toFunction, functionMembers);
}

/**
   A function symbol with nested overloads.
 */
template FunctionSymbol(
    alias F,
    Protection P = __traits(getProtection, F).toProtection,
    Linkage L = __traits(getLinkage, F).toLinkage,
    string I = __traits(identifier, F),
    alias M = moduleOf!F
)
{
    import std.meta: staticMap;

    alias symbol = F;
    enum identifier = I;
    alias module_ = M;

    private alias toOverload(alias symbol) = FunctionOverload!(
        symbol,
        __traits(getProtection, symbol).toProtection,
        __traits(getLinkage, symbol).toLinkage,
        identifier,
        module_,
    );

    alias overloads = staticMap!(toOverload, __traits(getOverloads, module_, identifier));

    string toString() @safe pure {
        import std.conv: text;
        return text(`Function(`, overloads.stringof, ")");
    }
}


private template functionsByOverload(alias mod, publicMembers...) {

    import std.meta: Filter, staticMap;

    private template memberIsSomeFunction(alias member) {
        import std.traits: isSomeFunction;
        enum memberIsSomeFunction = isSomeFunction!(member.symbol);
    }

    private alias functionMembers = Filter!(memberIsSomeFunction, publicMembers);

    private template overload(alias S, string I) {
        alias symbol = S;
        enum identifier = I;
    }

    private template memberToOverloads(alias member) {
        private alias overloadSymbols = __traits(getOverloads, mod, member.identifier);
        private alias toOverload(alias symbol) = overload!(symbol, member.identifier);
        alias memberToOverloads = staticMap!(toOverload, overloadSymbols);
    }

    private alias toFunction(alias overload) = FunctionOverload!(
        overload.symbol,
        __traits(getProtection, overload.symbol).toProtection,
        __traits(getLinkage, overload.symbol).toLinkage,
        overload.identifier,
        mod,
    );

    alias functionsByOverload = staticMap!(toFunction, staticMap!(memberToOverloads, functionMembers));
}


/**
   A specific overload of a function.  In most cases it will be
   synonymous with the function symbol since most functions aren't
   overloaded.
 */
template FunctionOverload(
    alias F,
    Protection P = __traits(getProtection, F).toProtection,
    Linkage L = __traits(getLinkage, F).toLinkage,
    string I = __traits(identifier, F),
    alias M = moduleOf!F
)
{
    import std.traits: RT = ReturnType;

    alias symbol = F;
    alias protection = P;
    alias linkage = L;
    enum identifier = I;
    alias module_ = M;

    alias ReturnType = RT!symbol;

    private template parametersImpl() {
        import std.traits: Parameters, ParameterIdentifierTuple, ParameterDefaults;
        import std.meta: staticMap, aliasSeqOf;
        import std.range: iota;

        alias parameter(size_t i) =
            Parameter!(Parameters!symbol[i], ParameterDefaults!symbol[i], ParameterIdentifierTuple!symbol[i]);
        alias parametersImpl = staticMap!(parameter, aliasSeqOf!(Parameters!F.length.iota));
    }

    alias parameters = parametersImpl!();

    string toString() @safe pure {
        import std.conv: text;
        import std.traits: fullyQualifiedName;
        return text(`Function(`, fullyQualifiedName!symbol, ", ", protection, ", ", linkage, ")");
    }
}


template Parameter(T, alias D, string I) {
    alias Type = T;
    alias Default = D;
    enum identifier = I;
}


/// Visibilty/protection
enum Protection {
    private_,
    protected_,
    public_,
    export_,
    package_,
}


Protection toProtection(in string str) @safe pure {
    import std.conv: to;
    return (str ~ "_").to!Protection;
}


///
enum Linkage {
    D,
    C,
    Cpp,
    Windows,
    ObjectiveC,
    System,
}


Linkage toLinkage(in string str) @safe pure {
    import std.conv: to;
    if(str == "C++") return Linkage.Cpp;
    return str.to!Linkage;
}
