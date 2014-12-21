
module dart.record;

public import std.conv;
public import std.traits;
public import std.variant;

public import mysql.db;

class ColumnInfo {

    string name;
    string field;

    bool isId = false;
    bool notNull = true;
    bool autoIncrement = false;

    int maxLength = -1;

    /**
     * Gets the value of the field bound to this column.
     **/
    Variant delegate(Record) get;
    /**
    * Sets the value of the field bound to this column.
    **/
    void delegate(Record, Variant) set;

}

class Record {

    protected static {

        /**
         * The name of the corresponding table.
         **/
        string _table;

        /**
         * The name of the primary id column.
         **/
        string _idColumn;

        /**
         * The column info table, for this record type.
         **/
        ColumnInfo[string] _columns;

        /**
         * The query table, for active record operations.
         **/
        string[string] _queries;

        MysqlDB _db;

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

        /**
         * Sets the database connection.
         **/
        void _setMysqlDB(MysqlDB db) {
            _db = db;
        }

    }

}

alias Target(alias T) = T;

struct Table {
    string name;
}

struct Column {
    string name;
}

struct MaxLength {
    int maxLength;
}

enum Id;
enum Nullable;
enum AutoIncrement;

static string getTableDefinition(T)() {
    // Search for @Column annotation.
    foreach(annotation; __traits(getAttributes, T)) {
        // Check if @Table is present.
        static if(is(annotation == Table)) {
            return T.stringof;
        }
        // Check if @Table("name") is present.
        static if(is(typeof(annotation) == Table)) {
            return annotation.name;
        }
    }

    // Not found.
    return T.stringof;
}

static string getColumnDefinition(T, string member)() {
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
        // Check if the class defined an override name.
        _table = getTableDefinition!(T);

        int colCount = 0;
        // Search through class members.
        foreach(member; __traits(derivedMembers, T)) {
            static if(__traits(compiles, __traits(getMember, T, member))) {
                alias current = Target!(__traits(getMember, T, member));

                // Check if this is a column.
                static if(!(is(typeof(current) == function)) &&
                        !(is(typeof(current!int) == function))) {
                    // Find a column name.
                    string name = getColumnDefinition!(T, member);

                    // Check if the definition exists.
                    if(name !is null) {
                        // Create a column info record.
                        auto info = new ColumnInfo();
                        info.field = member;
                        info.name = name;

                        // Create delegate get and set.
                        info.get = delegate(Record local) {
                                return Variant(__traits(getMember, cast(T)(local), member));
                        };
                        info.set = delegate(Record local, Variant v) {
                                __traits(getMember, cast(T)(local), member) = v.coerce!(typeof(current));
                        };

                        // Populate other fields.
                        foreach(annotation; __traits(getAttributes, current)) {
                            // Check is @Id is present.
                            static if(is(annotation == Id)) {
                                if(_idColumn !is null) {
                                    throw new Exception(T.stringof ~
                                            " already defined an Id column.");
                                }

                                // Save the Id column.
                                _idColumn = info.name;
                                info.isId = true;
                            }
                            // Check if @Nullable is present.
                            static if(is(annotation == Nullable)) {
                                info.notNull = false;
                            }
                            // Check if @AutoIncrement is present.
                            static if(is(annotation == AutoIncrement)) {
                                info.autoIncrement = true;
                            }
                            // Check if @MaxLength(int) is present.
                            static if(is(typeof(annotation) == MaxLength)) {
                                info.maxLength = annotation.maxLength;
                            }
                        }

                        // Store the column definition.
                        _addColumnInfo(info);
                        colCount++;
                    }
                }
            }
        }

        // Check is we have an Id.
        if(_idColumn is null) {
            throw new Exception(T.stringof ~
                    " doesn't defined an Id column.");
        }

        // Check if we have any columns.
        if(colCount == 0) {
            throw new Exception(T.stringof ~
                    " defines no valid columns.");
        }

    }

    /**
     * Gets an object by its primary key.
     **/
    static T get(KT)(KT key) {
        auto conn = _db.lockConnection();
        auto command = Command(conn);

        string query = "SELECT * FROM " ~ _table ~
                " WHERE " ~ _idColumn ~ "=?";
        command.sql = query;
        command.prepare();

        command.bindParameter(key, 0);
        auto result = command.execPreparedResult();

        if(result.empty) {
            throw new Exception("No records for for " ~
                    T.stringof ~ " at " ~ to!string(key));
        }

        T instance = new T;
        auto row = result[0];
        foreach(int idx, string name; result.colNames) {
            auto value = row[idx];
            _columns[name].set(instance, value);
        }

        return instance;
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
