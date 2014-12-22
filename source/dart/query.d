
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

class SelectBuilder : QueryBuilder {

    private {

        string[] columns;

        string table;
        string condition;

        int count = -1;

        Variant[] params;

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
     * Sets the 'FROM' clause in the query.
     **/
    SelectBuilder from(string table)
    in {
        // Check that the table isn't null.
        if(table is null) {
            throw new Exception("Table cannot be null.");
        }
    } body {
        this.table = table;
        return this;
    }

    /**
     * Sets the 'WHERE' clause in the query.
     **/
    SelectBuilder where(VT)(string where, VT[] params...)
    in {
        if(where is null) {
            throw new Exception("Where cannot be null.");
        }
    } body {
        // Assign query.
        condition = where;

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
        if(columns !is null) {
            // Select specific columns.
            formattedWrite(query, "%-(`%s`%|, %)", columns);
        } else {
            // Select everything.
            query.put("*");
        }

        // From.
        query.put(" FROM ");
        query.put(table);

        // Where.
        if(condition !is null) {
            query.put(" WHERE ");
            query.put(condition);
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
        string condition;

        int count = -1;

        Variant[] params;

    }

    /**
     * Sets the 'FROM' clause in the query.
     **/
    DeleteBuilder from(string table)
    in {
        if(table is null) {
            throw new Exception("Table cannot be null.");
        }
    } body {
        this.table = table;
        return this;
    }

    /**
     * Sets the 'WHERE' clause in the query.
     **/
    DeleteBuilder where(VT)(string where, VT[] params...)
    in {
        if(where is null) {
            throw new Exception("Where cannot be null.");
        }
    } body {
        // Assign query.
        condition = where;

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
        query.put(" FROM ");
        query.put(table);

        // Where.
        if(condition !is null) {
            query.put(" WHERE ");
            query.put(condition);
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
        string condition;

        int count = -1;

        Variant[] params;

    }

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
     * Sets the 'WHERE' clause in the query.
     **/
    UpdateBuilder where(VT)(string where, VT[] params...)
    in {
        if(where is null) {
            throw new Exception("Where cannot be null.");
        }
    } body {
        // Assign query.
        condition = where;

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
        if(condition !is null) {
            query.put(" WHERE ");
            query.put(condition);
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
