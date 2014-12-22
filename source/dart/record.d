
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
 * This annotation is only meaningful for types that have a length.
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

        /**
         * Mysql database connection.
         **/
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
            if(_db !is null) {
                return _db.lockConnection();
            } else if(_dbConnection !is null) {
                return _dbConnection;
            } else {
                throw new Exception("Record has no database connection.");
            }
        }

        /**
         * Sets the database connection.
         **/
        void _setDBConnection(Connection conn) {
            _dbConnection = conn;
        }

        /**
         * Sets the database connection.
         **/
        void _setMysqlDB(MysqlDB db) {
            _db = db;
        }

    }

    protected {

        /**
         * Gets the query for get() operations.
         **/
        QueryBuilder _getQueryForGet(KT)(KT key) {
            SelectBuilder builder = new SelectBuilder()
                    .select(_getColumns).from(_getTable).limit(1);
            return builder.where(new WhereBuilder().equals(_idColumn, key));
        }

        /**
         * Gets the query for find() operations.
         **/
        QueryBuilder _getQueryForFind(KT)(KT[string] conditions) {
            auto query = appender!string;
            SelectBuilder builder = new SelectBuilder()
                    .select(_getColumns).from(_getTable);
            formattedWrite(query, "%-(`%s`=?%| AND %)", conditions.keys);
            return builder.where(query.data, conditions.values);
        }

        /**
         * Gets the query for create() operations.
         **/
        QueryBuilder _getQueryForCreate() {
            InsertBuilder builder = new InsertBuilder()
                    .insert(_getColumns).into(_getTable);

            // Add column values to query.
            foreach(string name; _getColumns) {
                auto info = _getColumnInfo(name);
                builder.value(info.get(this));
            }

            return builder;
        }

        /**
         * Gets the query for update() operations.
         **/
        QueryBuilder _getQueryForUpdate(string column = null) {
            UpdateBuilder builder = new UpdateBuilder()
                    .update(_getTable).limit(1);

            if(column is null) {
                // Set column values in query.
                foreach(string name; _getColumns) {
                    auto info = _getColumnInfo(name);
                    builder.set(info.name, info.get(this));
                }
            } else {
                // Set a single column value.
                auto info = _getColumnInfo(column);
                builder.set(info.name, info.get(this));
            }

            // Update the record using the primary id.
            Variant id = _getColumnInfo(_idColumn).get(this);
            return builder.where(new WhereBuilder().equals(_idColumn, id));
        }

        /**
         * Gets the query for remove() operations.
         **/
        QueryBuilder _getQueryForDelete() {
            DeleteBuilder builder = new DeleteBuilder()
                    .from(_getTable).limit(1);

            // Delete the record using the primary id.
            Variant id = _getColumnInfo(_idColumn).get(this);
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

        int colCount = 0;
        // Search through class members.
        foreach(member; __traits(derivedMembers, T)) {
            static if(__traits(compiles, __traits(getMember, T, member))) {
                alias current = Target!(__traits(getMember, T, member));

                // Check if this is a column.
                static if(!((is(typeof(current) == function)) ||
                        member == "get" || member == "find")) {
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
        // Get a database connection.
        auto conn = _getDBConnection;
        auto command = Command(conn);

        // Prepare the get() query.
        auto instance = new T;
        auto query = instance._getQueryForGet(key);
        command.sql = query.build;
        command.prepare;

        // Bind parameters and execute.
        command.bindParameters(query.getParameters);
        auto result = command.execPreparedResult;

        // Check that we got a result.
        if(result.empty) {
            throw new Exception("No records for for " ~
                    _getTable ~ " at " ~ to!string(key));
        }

        // Bind column values to fields.
        auto row = result[0];
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
        // Get a database connection.
        auto conn = _getDBConnection();
        auto command = Command(conn);

        // Prepare the find() query.
        auto instance = new T;
        auto query = instance._getQueryForFind(conditions);
        command.sql = query.build();
        command.prepare();

        // Bind parameters and execute.
        command.bindParameters(query.getParameters);
        auto result = command.execPreparedResult();

        // Check that we got a result.
        if(result.empty) {
            throw new Exception("No records for for " ~
                    _getTable ~ " at " ~ to!string(conditions));
        }

        T[] array;
        // Create the initial array of elements.
        for(int i = 0; i < result.length; i++) {
            auto row = result[i];
            foreach(int idx, string name; result.colNames) {
                auto value = row[idx];
                _columns[name].set(instance, value);
            }

            // Append the object and create a new one.
            array ~= instance;
            instance = new T;
        }

        // Return the array.
        return array;
    }

    /**
     * Creates this object in the database, if it does not yet exist.
     **/
    void create() {
        // Get a database connection.
        auto conn = _getDBConnection;
        auto command = Command(conn);
        ulong result;

        // Prepare the create() query.
        auto query = _getQueryForCreate;
        command.sql = query.build;
        command.prepare;

        // Bind parameters and execute.
        command.bindParameters(query.getParameters);
        command.execPrepared(result);

        // Check that something was created.
        if(result < 1) {
            throw new Exception("No record was created for " ~
                    T.stringof ~ " by create().");
        }

        // Update auto increment columns.
        auto info = _getColumnInfo(_idColumn);
        if(info.autoIncrement) {
            // Fetch the last insert id.
            command.sql = SelectBuilder.lastInsertId.build;
            command.prepare;

            // Update the auto incremented column.
            auto id = command.execPreparedResult;
            info.set(this, id[0][0]);
        }
    }

    /**
     * Saves this object in the database, if it already exists.
     **/
    void save() {
        // Get a database connection.
        auto conn = _getDBConnection;
        auto command = Command(conn);
        ulong result;

        // Prepare the create() query.
        auto query = _getQueryForUpdate;
        command.sql = query.build;
        command.prepare;

        // Bind parameters and execute.
        command.bindParameters(query.getParameters);
        command.execPrepared(result);

        // Check that something was created.
        if(result < 1) {
            throw new Exception("No record was updated for " ~
                    T.stringof ~ " by save().");
        }
    }

    /**
     * Updates a single column in the database.
     **/
    void save(string name) {
        // Get a database connection.
        auto conn = _getDBConnection;
        auto command = Command(conn);
        ulong result;

        // Prepare the create() query.
        auto query = _getQueryForUpdate(name);
        command.sql = query.build;
        command.prepare;

        // Bind parameters and execute.
        command.bindParameters(query.getParameters);
        command.execPrepared(result);

        // Check that something was created.
        if(result < 1) {
            throw new Exception("No record was update for " ~
                    T.stringof ~ " by save().");
        }
    }

    /**
     * Removes this object from the database, if it already exists.
     **/
    void remove() {
        // Get a database connection.
        auto conn = _getDBConnection;
        auto command = Command(conn);
        ulong result;

        // Prepare the create() query.
        auto query = _getQueryForDelete;
        command.sql = query.build;
        command.prepare;

        // Bind parameters and execute.
        command.bindParameters(query.getParameters);
        command.execPrepared(result);

        // Check that something was created.
        if(result < 1) {
            throw new Exception("No record was removed for " ~
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
    return null;
}
