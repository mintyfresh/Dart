
module dart.record;

import std.array;
import std.format;

public import std.conv;
public import std.traits;
public import std.variant;

public import mysql.db;

public import dart.query;
public import dart.helpers.attributes;
public import dart.helpers.helpers;

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
 * A container type for Record information.
 **/
struct RecordData(T) {

    /**
     * The name of the corresponding table.
     **/
    string table;

    /**
     * The name of the primary id column.
     **/
    string idColumn;

    /**
     * The column info table, for this record type.
     **/
    ColumnBindings[string] columns;

    /**
     * Mysql database connection.
     **/
    Connection dbConnection;

    // Mysql-native provides this.
    version(Have_vibe_d) {
        /**
         * Mysql database connection.
         **/
        MysqlDB mysqlConnection;
    }

}

/**
 * The record class type.
 *
 * Template argument ensures that static fields stay local
 * to the template instance (and thus, to the Record itself).
 **/
class Record(Type) {

    private static {

        /**
         * A container for static Record information.
         **/
        RecordData!Type _recordData;

    }

    protected static {

        /**
         * Gets a column definition, by name.
         **/
        ColumnBindings getColumnBindings(string name) {
            return _recordData.columns[name];
        }

        /**
         * Adds a column definition to this record.
         **/
        void addColumnBindings(ColumnBindings ci) {
            _recordData.columns[ci.name] = ci;
        }

        /**
         * Gets the name of the Id column.
         **/
        string getIdColumn() {
            return _recordData.idColumn;
        }

        /**
         * Sets the name of the Id column.
         **/
        void setIdColumn(string column) {
            _recordData.idColumn = column;
        }

        /**
         * Gets the name of the table for this record.
         **/
        string getTableName() {
            return _recordData.table;
        }

        /**
         * Sets the name of the table for this record.
         **/
        void setTableName(string table) {
            _recordData.table = table;
        }

        /**
         * Gets the column list for this record.
         **/
        string[] getColumnNames() {
            return _recordData.columns.keys;
        }

        /**
         * Gets a list of column values, for this instance.
         **/
        Variant[] getColumnValues(T)(T instance) {
            Variant[] values;
            foreach(name, info; _recordData.columns)
                values ~= info.get(instance);
            return values;
        }

        /**
         * Gets the database connection.
         **/
        Connection getDBConnection() {
            // Mysql-native provides this.
            version(Have_vibe_d) {
                if(_recordData.mysqlConnection !is null) {
                    return _recordData.mysqlConnection.lockConnection();
                } else if(_recordData.dbConnection !is null) {
                    return _recordData.dbConnection;
                }
            } else {
                if(_recordData.dbConnection !is null) {
                    return _recordData.dbConnection;
                }
            }

            // No database connection set.
            throw new RecordException("Record has no database connection.");
        }

        /**
         * Sets the database connection.
         **/
        void setDBConnection(Connection conn) {
            _recordData.dbConnection = conn;
        }

        // Mysql-native provides this.
        version(Have_vibe_d) {
            /**
             * Sets the database connection.
             **/
            void setDBConnection(MysqlDB db) {
                _recordData.mysqlConnection = db;
            }
        }

        /**
         * Executes a query that produces a result set.
         **/
        ResultSet executeQueryResult(QueryBuilder query) {
            // Get a database connection.
            auto conn = getDBConnection;
            auto command = Command(conn);

            // Prepare the query.
            command.sql = query.build;
            command.prepare;

            // Bind parameters and execute.
            command.bindParameters(query.getParameters);
            return command.execPreparedResult;
        }

        /**
         * Executes a query that doesn't produce a result set.
         **/
        ulong executeQuery(QueryBuilder query) {
            // Get a database connection.
            auto conn = getDBConnection;
            auto command = Command(conn);
            ulong result;

            // Prepare the query.
            command.sql = query.build;
            command.prepare;

            // Bind parameters and execute.
            command.bindParameters(query.getParameters);
            command.execPrepared(result);

            return result;
        }

        /**
         * Gets the query for get() operations.
         **/
        QueryBuilder getQueryForGet(KT)(KT key) {
            SelectBuilder builder = new SelectBuilder()
                    .select(getColumnNames).from(getTableName).limit(1);
            return builder.where(new WhereBuilder().equals(getIdColumn, key));
        }

        /**
         * Gets the query for find() operations.
         **/
        QueryBuilder getQueryForFind(KT)(KT[string] conditions, int limit) {
            auto query = appender!string;
            SelectBuilder builder = new SelectBuilder()
                    .select(getColumnNames).from(getTableName).limit(limit);
            formattedWrite(query, "%-(`%s`=?%| AND %)", conditions.keys);
            return builder.where(query.data, conditions.values);
        }

        /**
         * Gets the query for create() operations.
         **/
        QueryBuilder getQueryForCreate(T)(T instance) {
            InsertBuilder builder = new InsertBuilder()
                    .insert(getColumnNames).into(getTableName);

            // Add column values to query.
            foreach(string name; getColumnNames) {
                auto info = getColumnBindings(name);
                builder.value(info.get(instance));
            }

            return builder;
        }

        /**
         * Gets the query for update() operations.
         **/
        QueryBuilder getQueryForSave(T)(
                T instance, string[] columns = null...) {
            UpdateBuilder builder = new UpdateBuilder()
                    .update(getTableName).limit(1);

            // Check for a columns list.
            if(columns is null) {
                // Include all columns.
                columns = getColumnNames;
            }

            // Set column values in query.
            foreach(string name; columns) {
                auto info = getColumnBindings(name);
                builder.set(info.name, info.get(instance));
            }

            // Update the record using the primary id.
            Variant id = getColumnBindings(getIdColumn).get(instance);
            return builder.where(new WhereBuilder().equals(getIdColumn, id));
        }

        /**
         * Gets the query for remove() operations.
         **/
        QueryBuilder getQueryForRemove(T)(T instance) {
            DeleteBuilder builder = new DeleteBuilder()
                    .from(getTableName).limit(1);

            // Delete the record using the primary id.
            Variant id = getColumnBindings(getIdColumn).get(instance);
            return builder.where(new WhereBuilder().equals(getIdColumn, id));
        }

    }

}

/**
 * The ActiveRecord mixin.
 **/
mixin template ActiveRecord() {

    /**
     * Alias to the local type.
     **/
    alias Type = Target!(__traits(parent, get));

    /**
     * Static initializer for column info.
     **/
    static this() {
        // Check if the class defined an override name.
        setTableName(getTableDefinition!(Type));

        // Search through class members.
        foreach(member; __traits(derivedMembers, Type)) {
            static if(__traits(compiles, __traits(getMember, Type, member))) {
                alias Current = Target!(__traits(getMember, Type, member));

                // Check if this is a column.
                static if(isColumn!(Type, member)) {
                    // Ensure that this isn't a function.
                    static assert(!is(typeof(Current) == function));

                    // Find the column name.
                    string name = getColumnDefinition!(Type, member);

                    // Create a column info record.
                    auto info = new ColumnBindings();
                    info.field = member;
                    info.name = name;

                    // Create delegate get and set.
                    info.get = createGetDelegate!(Type, member)(info);
                    info.set = createSetDelegate!(Type, member)(info);

                    // Populate other fields.
                    foreach(annotation; __traits(getAttributes, Current)) {
                        // Check is @Id is present.
                        static if(is(annotation == Id)) {
                            // Check for duplicate Id.
                            if(getIdColumn !is null) {
                                throw new RecordException(Type.stringof ~
                                        " already defined an Id column.");
                            }

                            // Save the Id column.
                            setIdColumn(info.name);
                            info.isId = true;
                        }
                        // Check if @Nullable is present.
                        static if(is(annotation == Nullable)) {
                            info.notNull = false;
                        }
                        // Check if @AutoIncrement is present.
                        static if(is(annotation == AutoIncrement)) {
                            // Check that this can be auto incremented.
                            static assert(isNumeric!(typeof(Current)));

                            info.autoIncrement = true;
                        }
                        // Check if @MaxLength(int) is present.
                        static if(is(typeof(annotation) == MaxLength)) {
                            info.maxLength = annotation.maxLength;
                        }
                    }

                    // Store the column definition.
                    addColumnBindings(info);
                }
            }
        }

        // Check is we have an Id.
        if(getIdColumn is null) {
            throw new RecordException(Type.stringof ~
                    " doesn't define an Id column.");
        }

        // Check if we have any columns.
        if(getColumnNames.length < 1) {
            throw new RecordException(Type.stringof ~
                    " defines no valid columns.");
        }
    }

    /**
     * Gets an object by its primary key.
     **/
    static Type get(KT)(KT key) {
        // Get the query for the operation.
        auto query = getQueryForGet(key);

        // Execute the get() query.
        ResultSet result = executeQueryResult(query);

        // Check that we got a result.
        if(result.empty) {
            throw new RecordException("No records found for " ~
                    getTableName ~ " at " ~ to!string(key));
        }

        auto row = result[0];
        auto instance = new Type;

        // Bind column values to fields.
        foreach(int idx, string name; result.colNames) {
            auto value = row[idx];
            getColumnBindings(name).set(instance, value);
        }

        // Return the instance.
        return instance;
    }

    /**
     * Finds matching objects, by column values.
     **/
    static Type[] find(KT)(KT[string] conditions, int limit = -1) {
        // Get the query for the operation.
        auto query = getQueryForFind(conditions, limit);

        // Execute the find() query.
        ResultSet result = executeQueryResult(query);

        // Check that we got a result.
        if(result.empty) return [];

        Type[] array;
        // Create the initial array of elements.
        for(int i = 0; i < result.length; i++) {
            auto row = result[i];
            auto instance = new Type;

            foreach(int idx, string name; result.colNames) {
                auto value = row[idx];
                getColumnBindings(name).set(instance, value);
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
        // Get the query for the operation.
        QueryBuilder query = getQueryForCreate(this);

        // Execute the create() query.
        ulong result = executeQuery(query);

        // Check that something was created.
        if(result < 1) {
            throw new RecordException("No records were created for " ~
                    Type.stringof ~ " by create().");
        }

        // Update auto increment columns.
        auto info = getColumnBindings(getIdColumn);
        if(info.autoIncrement) {
            // Fetch the last insert id.
            query = SelectBuilder.lastInsertId;
            ResultSet id = executeQueryResult(query);

            // Update the auto incremented column.
            info.set(this, id[0][0]);
        }
    }

    /**
     * Saves this object to the database, if it already exists.
     * Optionally specifies a list of columns to be updated.
     **/
    void save(string[] names = null...) {
        // Get the query for the operation.
        auto query = getQueryForSave(this, names);

        // Execute the save() query.
        ulong result = executeQuery(query);

        // Check that something was created.
        if(result < 1) {
            throw new RecordException("No records were updated for " ~
                    Type.stringof ~ " by save().");
        }
    }

    /**
     * Removes this object from the database, if it already exists.
     **/
    void remove() {
        // Get the query for the operation.
        auto query = getQueryForRemove(this);

        // Execute the remove() query.
        ulong result = executeQuery(query);

        // Check that something was created.
        if(result < 1) {
            throw new RecordException("No records were removed for " ~
                    Type.stringof ~ " by remove().");
        }
    }

}

alias Target(alias T) = T;
