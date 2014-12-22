
module dart.query;

import std.array;
import std.conv;
import std.format;
import std.variant;

interface QueryBuilder {

    /**
     * Gets the list of query parameters.
     **/
    Variant[] getParameters();

    /**
     * Converts the current builder state into a query string.
     **/
    string build();

}

class GenericQuery : QueryBuilder {

    private {

        string query;
        Variant[] params;

    }

    /**
     * Constructs a generic query from a query string and parameters.
     **/
    this(string query, Variant[] params = null...)
    in {
        if(query is null) {
            throw new Exception("Query string cannot be null.");
        }
    } body {
        this.query = query;
        this.params = params;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        return query;
    }

}

class WhereBuilder : QueryBuilder {

    private {

        Appender!string query;

        Variant[] params;

    }

    this() {
        query = appender!string;
    }

    /**
     * Inserts an 'AND' operator.
     **/
    WhereBuilder and() {
        query.put(" AND ");
        return this;
    }

    /**
     * Inserts a 'XOR' (exclusive or) operator.
     **/
    WhereBuilder xor() {
        query.put(" XOR ");
        return this;
    }

    /**
     * Inserts an 'OR' operator.
     **/
    WhereBuilder or() {
        query.put(" OR ");
        return this;
    }

    /**
     * Opens a set of parentheses.
     **/
    WhereBuilder openParen() {
        query.put("(");
        return this;
    }

    /**
     * Closes a set of parentheses.
     **/
    WhereBuilder closeParen() {
        query.put(")");
        return this;
    }

    /**
     * Performs a comparison between the column and a value,
     * using the specified operator.
     **/
    WhereBuilder compare(VT)(string column, string operator, VT value)
    in {
        if(column is null || operator is null) {
            throw new Exception("Column name and operator cannot be null.");
        }
    } body {
        // Append the query segment.
        formattedWrite(query, "`%s` %s ?", column, operator);

        // Convert value to variant.
        static if(is(VT == Variant)) {
            params ~= value;
        } else {
            params ~= Variant(value);
        }

        return this;
    }

    /**
     * Performs an 'IS NULL' check on the specified column.
     **/
    WhereBuilder isNull(string column)
    in {
        if(column is null) {
            throw new Exception("Column name cannot be null.");
        }
    } body {
        // Append the query segment.
        formattedWrite(query, "`%s` IS NULL", column);

        return this;
    }

    /**
     * Performs an 'IS NOT NULL' check on the specified column.
     **/
    WhereBuilder isNotNull(string column)
    in {
        if(column is null) {
            throw new Exception("Column name cannot be null.");
        }
    } body {
        // Append the query segment.
        formattedWrite(query, "`%s` IS NOT NULL", column);

        return this;
    }

    /**
     * Tests if a column is equal to the value.
     **/
    WhereBuilder equals(VT)(string column, VT value) {
        return compare(column, "=", value);
    }
    /**
     * Tests if a column is not equal to the value.
     **/
    WhereBuilder notEquals(VT)(string column, VT value) {
        return compare(column, "!=", value);
    }

    /**
     * Tests if a column is 'LIKE' the value.
     **/
    WhereBuilder like(VT)(string column, VT value) {
        return compare(column, "LIKE", value);
    }

    /**
     * Tests if a column is 'NOT LIKE' the value.
     **/
    WhereBuilder notLike(VT)(string column, VT value) {
        return compare(column, "NOT LIKE", value);
    }

    /**
     * Tests if a column is less than the value.
     **/
    WhereBuilder lessThan(VT)(string column, VT value) {
        return compare(column, "<", value);
    }

    /**
     * Tests if a column is greater than the value.
     **/
    WhereBuilder greaterThan(VT)(string column, VT value) {
        return compare(column, ">", value);
    }

    /**
     * Tests if a column is less than or equal to the value.
     **/
    WhereBuilder lessOrEqual(VT)(string column, VT value) {
        return compare(column, "<=", value);
    }

    /**
     * Tests if a column is greater than or equal to the value.
     **/
    WhereBuilder greaterOrEqual(VT)(string column, VT value) {
        return compare(column, ">=", value);
    }

    /**
     * Tests if the column appears in a set of values.
     **/
    WhereBuilder whereIn(VT)(string column, VT[] values...)
    in {
        if(column is null || values is null) {
            throw new Exception("Column name and values cannot be null.");
        }
    } body {
        // Build the where-in clause.
        query.put("`" ~ column ~ "` IN (");
        foreach(int idx, value; values) {
            query.put("?");
            if(idx < values.length - 1) {
                query.put(", ");
            }

            // Convert value to variant.
            static if(is(VT == Variant)) {
                params ~= value;
            } else {
                params ~= Variant(value);
            }
        }
        query.put(")");

        return this;
    }

    /**
     * Tests if the column appears in a set of values produced by a query.
     **/
    WhereBuilder whereIn(string column, SelectBuilder select)
    in {
        if(column is null || select is null) {
            throw new Exception("Column name and values cannot be null.");
        }
    } body {
        // Build the where-in clause.
        query.put("`" ~ column ~ "` IN (");
        query.put(select.build ~ ")");

        params = join([params, select.getParameters]);
        return this;
    }

    /**
     * Tests if the column does not appear in a set of values.
     **/
    WhereBuilder whereNotIn(VT)(string column, VT[] values...)
    in {
        if(column is null || values is null) {
            throw new Exception("Column name and values cannot be null.");
        }
    } body {
        // Build the where-in clause.
        query.put("`" ~ column ~ "` NOT IN (");
        foreach(int idx, value; values) {
            query.put("?");
            if(idx < values.length - 1) {
                query.put(", ");
            }

            // Convert value to variant.
            static if(is(VT == Variant)) {
                params ~= value;
            } else {
                params ~= Variant(value);
            }
        }
        query.put(")");

        return this;
    }

    /**
     * Tests if the column does not appear in a set of values produced by a query.
     **/
    WhereBuilder whereNotIn(string column, SelectBuilder select)
    in {
        if(column is null || select is null) {
            throw new Exception("Column name and values cannot be null.");
        }
    } body {
        // Build the where-in clause.
        query.put("`" ~ column ~ "` NOT IN (");
        query.put(select.build ~ ")");

        params = join([params, select.getParameters]);
        return this;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        return query.data;
    }

}

mixin template FromFunctions(T : QueryBuilder) {

    private {

        string fromTable;

        SelectBuilder fromQuery;
        string fromAsName;

    }

    T from(string table)
    in {
        if(table is null) {
            throw new Exception("Table cannot be null.");
        }
    } body {
        fromTable = table;
        return this;
    }

    T from(SelectBuilder query, string asName)
    in {
        if(query is null || asName is null) {
            throw new Exception("Query and name cannot be null.");
        }
    } body {
        fromQuery = query;
        fromAsName = asName;
        return this;
    }

    protected {

        /**
         * Checks if from information has been specified.
         **/
        bool hasFrom() {
            return fromQuery !is null ||
                    fromTable !is null;
        }

        /**
         * Converts the from state into a query segment.
         **/
        string getFromSegment() {
            auto query = appender!string;

            // Check if we're using a query.
            if(fromQuery !is null) {
                formattedWrite(query, "%s AS %s",
                        fromQuery.build, fromAsName);
            } else {
                formattedWrite(query, "`%s`", fromTable);
            }

            return query.data;
        }

    }

}

mixin template WhereFunctions(T : QueryBuilder) {

    private {

        string whereCondition;

    }

    /**
     * Sets the select condition from a string.
     **/
    T where(VT)(string where, VT[] params...)
    in {
        if(where is null) {
            throw new Exception("Condition cannot be null.");
        }
    } body {
        // Assign query.
        whereCondition = where;

        // Query parameters.
        if(params !is null && params.length > 0) {
            static if(is(VT == Variant)) {
                this.params = join([this.params, params]);
            } else {
                // Convert params to variant array.
                foreach(param; params) {
                    this.params ~= Variant(param);
                }
            }
        }

        return this;
    }

    /**
     * Sets the select condition from a where condition builder.
     **/
    T where(WhereBuilder where)
    in {
        if(where is null) {
            throw new Exception("Condition cannot be null.");
        }
    } body {
        // Store query information.
        whereCondition = where.build();
        params = join([params, where.getParameters]);

        return this;
    }

    protected {

        /**
         * Checks if a where condition has been specified.
         **/
        bool hasWhere() {
            return whereCondition !is null;
        }

        /**
         * Converts the where state into a query segment.
         **/
        string getWhereSegment() {
            return whereCondition;
        }

    }

}

mixin template OrderByFunctions(T : QueryBuilder) {

    /**
     * A type spcifying an order-by column and direction.
     **/
    struct OrderByInfo {

        string column;
        string direction;

        string toString() {
            auto query = appender!string;
            query.put(column);
            if(direction !is null) {
                query.put(" " ~ direction);
            }

            return query.data;
        }

    }

    private {

        OrderByInfo[] orderByColumns;

    }

    /**
     * Adds an order-by clause from a column name or expression
     * and optionally a direction (ASC, DESC, etc.)
     **/
    T orderBy(string column, string direction = null)
    in {
        if(column is null) {
            throw new Exception("Column name cannot be null.");
        }
    } body {
        // Save the Order-By specifier.
        orderByColumns ~= OrderByInfo(column, direction);

        return this;
    }

    /**
     * Adds a number of order-by clause from a list of
     * column names or expressions.
     **/
    T orderBy(string[] columns...)
    in {
        if(columns is null) {
            throw new Exception("Columns list cannot be null.");
        }
    } body {
        // Add the columns to the list.
        foreach(column; columns) {
            orderByColumns ~= OrderByInfo(column);
        }

        return this;
    }

    /**
     * Adds a number of order-by clause from a list of
     * Order-By info structs.
     **/
    T orderBy(OrderByInfo[] columns...)
    in {
        if(columns is null) {
            throw new Exception("Columns list cannot be null.");
        }
    } body {
        // Append the list of specifiers.
        orderByColumns = join([orderByColumns, columns]);

        return this;
    }

    protected {

        /**
         * Checks if Order-By information has been specified.
         **/
        bool hasOrderBy() {
            return orderByColumns !is null &&
                    !orderByColumns.empty;
        }

        /**
         * Converts the order-by state into a query segment.
         **/
        string getOrderBySegment() {
            auto query = appender!string;
            formattedWrite(query, "%-(%s%|, %)",
                    orderByColumns);
            return query.data;
        }

    }

}

class SelectBuilder : QueryBuilder {

    private {

        string command;
        string[] columns;

        int count = -1;

        Variant[] params;

    }

    /**
     * From component.
     **/
    mixin FromFunctions!(SelectBuilder);
    /**
     * Where component.
     **/
    mixin WhereFunctions!(SelectBuilder);
    /**
     * Order-By component.
     **/
    mixin OrderByFunctions!(SelectBuilder);

    /**
     * Creates a select query for the last insert id.
     **/
    static
    SelectBuilder lastInsertId() {
        return new SelectBuilder().selectFunc("LAST_INSERT_ID");
    }

    /**
     * Prepares a select query with a function and parameters.
     **/
    SelectBuilder selectFunc(string command, string[] params = null...)
    in {
        if(command is null) {
            throw new Exception("Command and column name cannot be null.");
        }
    } body {
        this.command = command;
        this.columns = params;
        return this;
    }

    /**
     * Prepares a select query for the average of a column.
     **/
    SelectBuilder selectAvg(string column)
    in {
        if(column is null) {
            throw new Exception("Column name cannot be null.");
        }
    } body {
        return selectFunc("AVG", column);
    }

    /**
     * Prepares a select query for the max value of a column.
     **/
    SelectBuilder selectMax(string column)
    in {
        if(column is null) {
            throw new Exception("Column name cannot be null.");
        }
    } body {
        return selectFunc("MAX", column);
    }

    /**
     * Prepares a select query for the min value of a column.
     **/
    SelectBuilder selectMin(string column)
    in {
        if(column is null) {
            throw new Exception("Column name cannot be null.");
        }
    } body {
        return selectFunc("MIN", column);
    }

    /**
     * Prepares a select query for the sum of a column.
     **/
    SelectBuilder selectSum(string column)
    in {
        if(column is null) {
            throw new Exception("Column name cannot be null.");
        }
    } body {
        return selectFunc("SUM", column);
    }

    /**
     * Sets the list of column to select.
     **/
    SelectBuilder select(string[] columns...)
    in {
        // Check that the columns list isn't null.
        if(columns is null) {
            throw new Exception("Columns list cannot be null.");
        }
    } body {
        this.columns = columns;
        return this;
    }

    /**
     * Sets the result limit for this query.
     **/
    SelectBuilder limit(int count)
    in {
        if(count < 0) {
            throw new Exception("Limit cannot be negative.");
        }
    } body {
        this.count = count;
        return this;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        auto query = appender!string;

        // Select.
        query.put("SELECT ");
        if(command !is null) {
            // Select function.
            query.put(command);
            formattedWrite(query, "(%-(%s%|, %))", columns);
        } else if(columns !is null) {
            // Select specific columns.
            formattedWrite(query, "%-(`%s`%|, %)", columns);
        } else {
            // Select everything.
            query.put("*");
        }

        // From.
        if(hasFrom) {
            query.put(" FROM ");
            query.put(getFromSegment);
        }

        // Where.
        if(hasWhere) {
            query.put(" WHERE ");
            query.put(getWhereSegment);
        }

        // Order-By.
        if(hasOrderBy) {
            query.put(" ORDER BY ");
            query.put(getOrderBySegment);
        }

        // Limit.
        if(count > -1) {
            query.put(" LIMIT ");
            query.put(to!string(count));
        }

        return query.data;
    }

}

class InsertBuilder : QueryBuilder {

    private {

        string table;
        string[] columns;

        Variant[] params;

    }

    /**
     * Sets the column list for this insert query.
     **/
    InsertBuilder insert(string[] columns...) {
        this.columns = columns;
        return this;
    }

    /**
     * Sets the 'INTO' clause in the query.
     **/
    InsertBuilder into(string table)
    in {
        if(table is null) {
            throw new Exception("Table cannot be null.");
        }
    } body {
        this.table = table;
        return this;
    }

    /**
     * Appends a singe value to the query.
     *
     * Parameters are passed through a prepared statement,
     * and never appear in the query string itself.
     **/
    InsertBuilder value(VT)(VT value) {
        static if(is(VT == Variant)) {
            params ~= value;
        } else {
            // Convert value to variant array.
            params ~= Variant(value);
        }

        return this;
    }

    /**
     * Appends a number of values to the query.
     *
     * Parameters are passed through a prepared statement,
     * and never appear in the query string itself.
     **/
    InsertBuilder values(VT)(VT[] values...)
    in {
        if(values is null) {
            throw new Exception("Values cannot be null.");
        }
    } body {
        // Query parameters.
        static if(is(VT == Variant)) {
            params = join([params, values]);
        } else {
            // Convert values to variant array.
            foreach(param; params) {
                params ~= Variant(values);
            }
        }

        return this;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        auto query = appender!string;

        // Insert into.
        query.put("INSERT INTO ");
        query.put(table);

        // (Columns).
        if(columns !is null) {
            // Insert into specific columns.
            formattedWrite(query, "(%-(`%s`%|, %))", columns);
        }

        // Values.
        query.put(" VALUES (");
        foreach(index, param; params) {
            query.put("?");
            if(index < params.length - 1) {
                query.put(", ");
            }
        }

        query.put(");");
        return query.data;
    }

}

class DeleteBuilder : QueryBuilder {

    private {

        string table;

        int count = -1;

        Variant[] params;

    }

    /**
     * From component.
     **/
    mixin FromFunctions!(DeleteBuilder);
    /**
     * Where component.
     **/
    mixin WhereFunctions!(DeleteBuilder);
    /**
     * Order-By component.
     **/
    mixin OrderByFunctions!(DeleteBuilder);

    /**
     * Sets the result limit for this query.
     **/
    DeleteBuilder limit(int count)
    in {
        if(count < 0) {
            throw new Exception("Limit cannot be negative.");
        }
    } body {
        this.count = count;
        return this;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        auto query = appender!string;

        // Delete.
        query.put("DELETE ");

        // From.
        if(hasFrom) {
            query.put(" FROM ");
            query.put(getFromSegment);
        }

        // Where.
        if(hasWhere) {
            query.put(" WHERE ");
            query.put(getWhereSegment);
        }

        // Order-By.
        if(hasOrderBy) {
            query.put(" ORDER BY ");
            query.put(getOrderBySegment);
        }

        // Limit.
        if(count > -1) {
            query.put(" LIMIT ");
            query.put(to!string(count));
        }

        query.put(";");
        return query.data;
    }

}

class UpdateBuilder : QueryBuilder {

    private {

        string table;
        string[] columns;

        int count = -1;

        Variant[] params;

    }

    /**
     * Where component.
     **/
    mixin WhereFunctions!(UpdateBuilder);
    /**
     * Order-By component.
     **/
    mixin OrderByFunctions!(UpdateBuilder);

    /**
     * Sets the table the update query targets.
     **/
    UpdateBuilder update(string table)
    in {
        if(table is null) {
            throw new Exception("Table cannot be null.");
        }
    } body {
        this.table = table;
        return this;
    }

    /**
     * Adds a column value to the update query.
     **/
    UpdateBuilder set(VT)(string name, VT value)
    in {
        if(name is null) {
            throw new Exception("Column name cannot be null.");
        }
    } body {
        columns ~= name;
        params ~= value;
        return this;
    }

    /**
     * Adds multiple column values to the update query.
     **/
    UpdateBuilder set(VT)(VT[string] values...)
    in {
        if(name is null) {
            throw new Exception("Values cannot be null.");
        }
    } body {
        // Add the values.
        foreach(name, value; values) {
            columns ~= name;
            // Convert value to variant.
            static if(is(VT == Variant)) {
                params ~= value;
            } else {
                params ~= Variant(value);
            }
        }

        return this;
    }

    /**
     * Sets the result limit for this query.
     **/
    UpdateBuilder limit(int count)
    in {
        if(count < 0) {
            throw new Exception("Limit cannot be negative.");
        }
    } body {
        this.count = count;
        return this;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        auto query = appender!string;

        // Update.
        query.put("UPDATE ");
        query.put(table);

        query.put(" SET ");
        formattedWrite(query, "%-(`%s`=?%|, %)", columns);

        // Where.
        if(hasWhere) {
            query.put(" WHERE ");
            query.put(getWhereSegment);
        }

        // Order-By.
        if(hasOrderBy) {
            query.put(" ORDER BY ");
            query.put(getOrderBySegment);
        }

        // Limit.
        if(count > -1) {
            query.put(" LIMIT ");
            query.put(to!string(count));
        }

        query.put(";");
        return query.data;
    }

}
