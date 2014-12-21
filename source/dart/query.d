
module dart.query;

import std.array;
import std.format;

interface QueryBuilder {

    /**
     * Converts the current builder state into a query string.
     **/
    string build();

}

class SelectBuilder : QueryBuilder {

    private {

        string[] columns;

        string table;
        string where;

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
    SelectQuery where(string where)
    in {
        if(where is null) {
            throw new Exception("Where cannot be null.");
        }
    } body {
        this.where = where;
        return this;
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
        query.put(where);

        query.put(";");
        return query.data;
    }

}
