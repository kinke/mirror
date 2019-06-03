module mirror.meta;


template Module(string moduleName) {
    import std.meta: Filter, staticMap, Alias, AliasSeq;
    import std.traits: isSomeFunction;

    mixin(`import `, moduleName, `;`);
    alias mod = Alias!(mixin(moduleName));

    alias memberNames = __traits(allMembers, mod);

    private template member(string name) {
        import std.meta: Alias, AliasSeq;
        static if(__traits(compiles, Alias!(__traits(getMember, mod, name))))
            alias member = Alias!(__traits(getMember, mod, name));
        else
            alias member = AliasSeq!();
    }
    alias members = staticMap!(member, memberNames);
    private enum notPrivate(alias T) = __traits(getProtection, T) != "private";
    alias publicMembers = Filter!(notPrivate, members);

    private template isType(A...) if(A.length == 1) {
        enum isType = is(A[0]);
    }

    alias Types = Filter!(isType, publicMembers);
    enum isVariable(alias member) = is(typeof(member));
    enum toVariable(alias member) = Variable!(typeof(member))(__traits(identifier, member));
    alias Variables = staticMap!(toVariable, Filter!(isVariable, publicMembers));

    alias Functions = Filter!(isSomeFunction, publicMembers);
}


struct Variable(T) {
    alias Type = T;
    string name;
}
