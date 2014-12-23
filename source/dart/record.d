
module dart.record;

import std.array;
import std.format;

public import std.conv;
public import std.traits;
public import std.variant;

public import mysql.db;

public import dart.query;

/**
 * Table annotation type.
 * Optionally specifies the name of the table.
 **/
struct Table {
    string name;
}

/**
 * Column annotation type.
 * Optionally specifies the name of the column.
 **/
struct Column {
    string name;
}

/**
 * MaxLength annotation type.
 * Specifies the max length of a field.
 *
 * This annotation is only meaningful for types that declare
 * a length property, and for fields of an array type.
 **/
struct MaxLength {
    int maxLength;
}

/**
 * Id annotation type.
 * Indicates that this column is the primary Id.
 **/
enum Id;

/**
 * Nullable annotation type.
 * Indicates that this column may be null.
 **/
enum Nullable;

/**
 * AutoIncrement annotation type.
 * Indicates that this column is auto incremented.
 *
 * This annotation is only meaningful for Id columns.
 **/
enum AutoIncrement;

/**
 * Exception type produced by record operations.
 **/
class RecordException : Exception {

    /**
     * Constructs a record exception with an error message.
     **/
    this(string message) {
        super(message);
    }

}

/**
 * The record class type.
 **/
class Record {

    /**
     * Identifiers are prefixed with an underscore to prevent collisions.
     **/
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
         * Mysql database connection.
         **/
        Connection _dbConnection;

        // Mysql-native provides this.
        version(Have_vibe_d) {
            /**
             * Mysql database connection.
             **/
            MysqlDB _db;
        }

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
         * Gets the name of the table for this record.
         **/
        string _getTable() {
            return _table;
        }

        /**
         * Gets the column list for this record.
         **/
        string[] _getColumns() {
            return _columns.keys;
        }

        /**
         * Gets the database connection.
         **/
        Connection _getDBConnection() {
            // Mysql-native provides this.
            version(Have_vibe_d) {
                if(_db !is null) {
                    return _db.lockConnection();
                } else if(_dbConnection !is null) {
                    return _dbConnection;
                }
            } else {
                if(_dbConnection !is null) {
                    return _dbConnection;
                }
            }

            // No database connection set.
            throw new RecordException("Record has no database connection.");
        }

        /**
         * Sets the database connection.
         **/
        void _setDBConnection(Connection conn) {
            _dbConnection = conn;
        }

        // Mysql-native provides this.
        version(Have_vibe_d) {
            /**
             * Sets the database connection.
             **/
            void _setDBConnection(MysqlDB db) {
                _db = db;
            }
        }

        /**
         * Executes a query that produces a result set.
         **/
        ResultSet _executeQueryResult(QueryBuilder query) {
            // Get a database connection.
            auto conn = _getDBConnection();
            auto command = Command(conn);

            // Prepare the query.
            command.sql = query.build;
            command.prepare();

            // Bind parameters and execute.
            command.bindParameters(query.getParameters);
            return command.execPreparedResult;
        }

        /**
         * Executes a query that doesn't produce a result set.
         **/
        ulong _executeQuery(QueryBuilder query) {
            // Get a database connection.
            auto conn = _getDBConnection();
            auto command = Command(conn);
            ulong result;

            // Prepare the query.
            command.sql = query.build;
            command.prepare();

            // Bind parameters and execute.
            command.bindParameters(query.getParameters);
            command.execPrepared(result);

            return result;
        }

        /**
         * Gets the query for get() operations.
         *
         * Overriden by _getQueryForGet().
         **/
        QueryBuilder _getDefaultQueryForGet(KT)(KT key) {
            SelectBuilder builder = new SelectBuilder()
                    .select(_getColumns).from(_getTable).limit(1);
            return builder.where(new WhereBuilder().equals(_idColumn, key));
        }

        /**
         * Gets the query for find() operations.
         *
         * Overriden by _getQueryForFind().
         **/
        QueryBuilder _getDefaultQueryForFind(KT)(KT[string] conditions) {
            auto query = appender!string;
            SelectBuilder builder = new SelectBuilder()
                    .select(_getColumns).from(_getTable);
            formattedWrite(query, "%-(`%s`=?%| AND %)", conditions.keys);
            return builder.where(query.data, conditions.values);
        }

        /**
         * Gets the query for create() operations.
         *
         * Overriden by _getQueryForCreate().
         **/
        QueryBuilder _getDefaultQueryForCreate(T)(T instance) {
            InsertBuilder builder = new InsertBuilder()
                    .insert(_getColumns).into(_getTable);

            // Add column values to query.
            foreach(string name; _getColumns) {
                auto info = _getColumnInfo(name);
                builder.value(info.get(instance));
            }

            return builder;
        }

        /**
         * Gets the query for update() operations.
         *
         * Overriden by _getQueryForSave().
         **/
        QueryBuilder _getDefaultQueryForSave(T)(
                T instance, string[] columns = null...) {
            UpdateBuilder builder = new UpdateBuilder()
                    .update(_getTable).limit(1);

            // Check for a columns list.
            if(columns is null) {
                // Include all columns.
                columns = _getColumns;
            }

            // Set column values in query.
            foreach(string name; columns) {
                auto info = _getColumnInfo(name);
                builder.set(info.name, info.get(instance));
            }

            // Update the record using the primary id.
            Variant id = _getColumnInfo(_idColumn).get(instance);
            return builder.where(new WhereBuilder().equals(_idColumn, id));
        }

        /**
         * Gets the query for remove() operations.
         *
         * Overriden by _getQueryForRemove().
         **/
        QueryBuilder _getDefaultQueryForRemove(T)(T instance) {
            DeleteBuilder builder = new DeleteBuilder()
                    .from(_getTable).limit(1);

            // Delete the record using the primary id.
            Variant id = _getColumnInfo(_idColumn).get(instance);
            return builder.where(new WhereBuilder().equals(_idColumn, id));
        }

    }

}

/**
 * The ActiveRecord mixin.
 **/
mixin template ActiveRecord(T : Record) {

    static this() {
        // Check if the class defined an override name.
        _table = getTableDefinition!(T);

        if(_table is null) {
            throw new RecordException(T.stringof ~ " isn't bound to a table.");
        }

        int colCount = 0;
        // Search through class members.
        foreach(member; __traits(derivedMembers, T)) {
            static if(__traits(compiles, __traits(getMember, T, member))) {
                alias current = Target!(__traits(getMember, T, member));

                // Check if this is a column.
                static if(isColumn!(T, member)) {
                    // Ensure that this isn't a function.
                    static if(is(typeof(current) == function)) {
                        throw new RecordException("Functions as columns is unsupported.");
                    } else {
                        // Find the column name.
                        string name = getColumnDefinition!(T, member);

                        // Create a column info record.
                        auto info = new ColumnInfo();
                        info.field = member;
                        info.name = name;

                        // Create delegate get and set.
                        info.get = delegate(Record local) {
                                // Check if null-assignable.
                                static if(isAssignable!(typeof(current), typeof(null))) {
                                    // Check that the value abides by null rules.
                                    if(info.notNull && !info.autoIncrement &&
                                            __traits(getMember, cast(T)(local), member) is null) {
                                        throw new RecordException("Non-nullable value of " ~
                                                member ~ " was null.");
                                    }
                                }

                                // Check for a length property.
                                static if(__traits(hasMember, typeof(current), "length") ||
                                        isSomeString!(typeof(current)) ||
                                        isArray!(typeof(current))) {
                                    // Check that length doesn't exceed max.
                                    if(info.maxLength != -1 && __traits(getMember,
                                            cast(T)(local), member).length > info.maxLength) {
                                        throw new RecordException("Value of " ~
                                                member ~ " exceeds max length.");
                                    }
                                }

                                // Convert value to variant.
                                static if(is(typeof(current) == Variant)) {
                                    return __traits(getMember, cast(T)(local), member);
                                } else {
                                    return Variant(__traits(getMember, cast(T)(local), member));
                                }
                        };
                        info.set = delegate(Record local, Variant v) {
                                // Convert value from variant.
                                static if(is(typeof(current) == Variant)) {
                                    auto value = v;
                                } else {
                                    auto value = v.coerce!(typeof(current));
                                }

                                __traits(getMember, cast(T)(local), member) = value;
                        };

                        // Populate other fields.
                        foreach(annotation; __traits(getAttributes, current)) {
                            // Check is @Id is present.
                            static if(is(annotation == Id)) {
                                if(_idColumn !is null) {
                                    throw new RecordException(T.stringof ~
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
            throw new RecordException(T.stringof ~
                    " doesn't defined an Id column.");
        }

        // Check if we have any columns.
        if(colCount == 0) {
            throw new RecordException(T.stringof ~
                    " defines no valid columns.");
        }
    }

    /**
     * Gets an object by its primary key.
     **/
    static T get(KT)(KT key) {
        // Check for a query-producer override.
        static if(__traits(hasMember, T, "_getQueryForGet")) {
            auto query = _getQueryForGet(key);
        } else {
            auto query = _getDefaultQueryForGet(key);
        }

        // Execute the get() query.
        ResultSet result = _executeQueryResult(query);

        // Check that we got a result.
        if(result.empty) {
            throw new RecordException("No records found for " ~
                    _getTable ~ " at " ~ to!string(key));
        }

        T instance = new T;
        auto row = result[0];
        // Bind column values to fields.
        foreach(int idx, string name; result.colNames) {
            auto value = row[idx];
            _columns[name].set(instance, value);
        }

        // Return the instance.
        return instance;
    }

    /**
     * Finds matching objects, by column values.
     **/
    static T[] find(KT)(KT[string] conditions...) {
        // Check for a query-producer override.
        static if(__traits(hasMember, T, "_getQueryForFind")) {
            auto query = _getQueryForFind(conditions);
        } else {
            auto query = _getDefaultQueryForFind(conditions);
        }

        // Execute the find() query.
        ResultSet result = _executeQueryResult(query);

        // Check that we got a result.
        if(result.empty) {
            throw new RecordException("No records found for " ~
                    _getTable ~ " at " ~ to!string(conditions));
        }

        T[] array;
        // Create the initial array of elements.
        for(int i = 0; i < result.length; i++) {
            T instance = new T;
            auto row = result[i];

            foreach(int idx, string name; result.colNames) {
                auto value = row[idx];
                _columns[name].set(instance, value);
            }

            // Append the object.
            array ~= instance;
        }

        // Return the array.
        return array;
    }

    /**
     * Creates this object in the database, if it does not yet exist.
     **/
    void create() {
        // Check for a query-producer override.
        static if(__traits(hasMember, T, "_getQueryForCreate")) {
            QueryBuilder query = _getQueryForCreate(this);
        } else {
            QueryBuilder query = _getDefaultQueryForCreate(this);
        }

        // Execute the create() query.
        ulong result = _executeQuery(query);

        // Check that something was created.
        if(result < 1) {
            throw new RecordException("No records were created for " ~
                    T.stringof ~ " by create().");
        }

        // Update auto increment columns.
        auto info = _getColumnInfo(_idColumn);
        if(info.autoIncrement) {
            // Fetch the last insert id.
            query = SelectBuilder.lastInsertId;
            ResultSet id = _executeQueryResult(query);

            // Update the auto incremented column.
            info.set(this, id[0][0]);
        }
    }

    /**
     * Saves this object to the database, if it already exists.
     * Optionally specifies a list of columns to be updated.
     **/
    void save(string[] names = null...) {
        // Check for a query-producer override.
        static if(__traits(hasMember, T, "_getQueryForSave")) {
            auto query = _getQueryForSave(this, names);
        } else {
            auto query = _getDefaultQueryForSave(this, names);
        }

        // Execute the save() query.
        ulong result = _executeQuery(query);

        // Check that something was created.
        if(result < 1) {
            throw new RecordException("No records were updated for " ~
                    T.stringof ~ " by save().");
        }
    }

    /**
     * Removes this object from the database, if it already exists.
     **/
    void remove() {
        // Check for a query-producer override.
        static if(__traits(hasMember, T, "_getQueryForRemove")) {
            auto query = _getQueryForRemove(this);
        } else {
            auto query = _getDefaultQueryForRemove(this);
        }

        // Execute the remove() query.
        ulong result = _executeQuery(query);

        // Check that something was created.
        if(result < 1) {
            throw new RecordException("No records were removed for " ~
                    T.stringof ~ " by remove().");
        }
    }

}

alias Target(alias T) = T;

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

/**
 * Checks if a type is a table, and returns the table name.
 **/
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
    return null;
}

/**
 * Compile-time helper for finding columns.
 **/
static bool isColumn(T, string member)() {
    // Search for @Column annotation.
    foreach(annotation; __traits(getAttributes,
    __traits(getMember, T, member))) {
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
static string getColumnDefinition(T, string member)() {
    // Search for @Column annotation.
    foreach(annotation; __traits(getAttributes,
            __traits(getMember, T, member))) {
        // Check is @Id is present (implicit column).
        static if(is(annotation == Id)) {
            return member;
        }
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
