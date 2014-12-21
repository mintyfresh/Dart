
module dart.record;

class ColumnInfo {

    string name;
    string field;

    bool notNull;
    bool autoIncrement;

    uint maxLength;

}

class Record {

    protected static {

        /**
         * The column info table, for this record type.
         **/
        ColumnInfo[string] _columns;

        /**
         * Gets a column definition, by name.
         **/
        ColumnInfo _getColumnInfo(string name) {
            return _columns[name];
        }

        /**
         * Adds a column definition to this record.
         **/
        void _addColumnInfo(ColumnInfo ci) {
            _columns[ci.name] = ci;
        }

    }

}

alias Target(alias T) = T;

struct Column {
    string name;
}

enum Nullable;
enum AutoIncrement;

struct ColumnLength {
    int maxLength;
}


string getColumnDefinition(T, string member)() {
    // Search for @Column annotation.
    foreach(annotation; __traits(getAttributes,
            __traits(getMember, T, member))) {
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
    return null;
}

mixin template ActiveRecord(T : Record) {

    static this() {
        // Search through class members.
        foreach(member; __traits(derivedMembers, T)) {
            static if(__traits(compiles, __traits(getMember, T, member))) {
                alias current = Target!(__traits(getMember, T, member));

                // Check if this is a column.
                static if(!(is(typeof(current) == function))) {
                    // Find a column name.
                    string name = getColumnDefinition!(T, member);

                    // Check if the definition exists.
                    if(name !is null) {
                        auto info = new ColumnInfo();
                        info.field = member;
                        info.name = name;

                        // Store the column definition.
                        _addColumnInfo(info);
                    }
                }
            }
        }
    }

    /**
     * Gets an object by its primary key.
     **/
    static T get(KT)(KT key) {
        return null;
    }

    /**
     * Finds matching objects, by column values.
     **/
    static T[] find(KT)(KT[string] key...) {
        return null;
    }

    /**
     * Creates this object in the database,
     * if it does not yet exist.
     **/
    void create() {

    }

    /**
     * Saves this object in the database,
     * if it already exists.
     **/
    void save() {

    }

    /**
     * Updates a single column in the database.
     **/
    void update(string name) {

    }

    /**
     * Removes this object from the database,
     * if it already exists.
     **/
    void remove() {

    }

}
