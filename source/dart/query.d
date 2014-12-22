
module dart.query;

import std.array;
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
                this.params ~= params;
            } else {
                // Append values as variants.
                foreach(VT value; params) {
                    this.params ~= Variant(value);
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
        query.put(" WHERE ");
        query.put(condition);

        query.put(";");
        return query.data;
    }

}
