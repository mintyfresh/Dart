
module dart.helpers.helpers;

import std.variant;
import dart.record;

class ColumnBindings {

    string name;
    string field;

    bool isId = false;
    bool notNull = true;
    bool compound = false;
    bool autoIncrement = false;

    int maxLength = -1;

    /**
    * Gets the value of the field bound to this column.
    **/
    Variant delegate(Object) get;
    /**
    * Sets the value of the field bound to this column.
    **/
    void delegate(Object, Variant) set;

}

/**
 * Checks if a type is a table, and returns the table name.
 **/
static string getTableDefinition(Type)() {
    // Search for @Column annotation.
    foreach(annotation; __traits(getAttributes, Type)) {
        // Check if @Table is present.
        static if(is(annotation == Table)) {
            return Type.stringof;
        }
        // Check if @Table("name") is present.
        static if(is(typeof(annotation) == Table)) {
            return annotation.name;
        }
    }

    // Not found.
    return Type.stringof;
}

/**
 * Compile-time helper for finding columns.
 **/
static bool isColumn(Type, string member)() {
    // Search for @Column annotation.
    foreach(annotation; __traits(getAttributes,
            __traits(getMember, Type, member))) {
        // Check is @Id is present (implicit column).
        static if(is(annotation == Id)) {
            return true;
        }
        // Check if @Column is present.
        static if(is(annotation == Column)) {
            return true;
        }
        // Check if @Column("name") is present.
        static if(is(typeof(annotation) == Column)) {
            return true;
        }
    }

    // Not found.
    return false;
}

/**
 * Determines the name of a column field.
 **/
static string getColumnDefinition(Type, string member)() {
    // Search for @Column annotation.
    foreach(annotation; __traits(getAttributes,
            __traits(getMember, Type, member))) {
        // Check if @Column is present.
        static if(is(annotation == Column)) {
            return member;
        }
        // Check if @Column("name") is present.
        static if(is(typeof(annotation) == Column)) {
            return annotation.name;
        }
    }

    // Not found.
    return member;
}

/**
 * Helper function template for create getter delegates.
 **/
static Variant delegate(Object)
        createGetDelegate(T, string member)(ColumnBindings info) {
    // Alias to target member, for type information.
    alias Type = typeof(__traits(getMember, T, member));

    // Create the get delegate.
    return delegate(Object local) {
        // Check if null-assignable.
        static if(isAssignable!(Type, typeof(null))) {
            // Check that the value abides by null rules.
            if(info.notNull && !info.autoIncrement &&
                    __traits(getMember, cast(T)(local), member) is null) {
                throw new RecordException("Non-nullable value of " ~
                        member ~ " was null.");
            }
        }

        // Check for a length property.
        static if(__traits(hasMember, Type, "length") || isArray!Type) {
            // Check that length doesn't exceed max.
            if(info.maxLength != -1 && __traits(getMember,
                    cast(T)(local), member).length > info.maxLength) {
                throw new RecordException("Value of " ~
                        member ~ " exceeds max length.");
            }
        }

        // Convert value to variant.
        static if(is(Type == Variant)) {
            return __traits(getMember, cast(T)(local), member);
        } else {
            return Variant(__traits(getMember, cast(T)(local), member));
        }
    };
}

/**
* Helper function template for create setter delegates.
**/
static void delegate(Object, Variant)
        createSetDelegate(T, string member)(ColumnBindings local) {
    // Alias to target member, for type information.
    alias Type = typeof(__traits(getMember, T, member));

    // Create the set delegate.
    return delegate(Object local, Variant v) {
        // Convert value from variant.
        static if(is(Type == Variant)) {
            auto value = v;
        } else {
            auto value = v.coerce!Type;
        }

        __traits(getMember, cast(T)(local), member) = value;
    };
}
