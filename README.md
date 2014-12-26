Dart
====

An Active Record implementation for DLang and MySQL. Supports vibe.d.

How-To
------

Here's a quick little demo on how to setup and use a Dart record.

```d

@Table("users")
class UserRecord : Record!UserRecord
{

    mixin ActiveRecord!();

    static this()
    {
        // Connect to a database.
        setDBConnection( . . . );
    }

    @Id
    @AutoIncrement
    uint id;

    @Column
    @MaxLength(32)
    string username;

    @Column("pass_hash")
    @MaxLength(64)
    string passwordHash;

    @Column
    @Nullable
    string status;

    @Column("last_online")
    ulong lastOnline;

}

```

In the example above, we've created a record for a user type that corresponds to
a table named `users` which defines an id, as well as a couple of other fields.

Now that we have our record, let's quickly go over how we can use it.

```d

void deleteUserById(uint id)
{
    UserRecord user = UserRecord.get(id);

    user.remove;
}

void updateUserStatus(uint id, string status)
{
    UserRecord user = UserRecord.get(id);

    user.status = status;
    user.save;
}

UserRecord[] findUsersWithStatus(string status)
{
    return UserRecord.find(["status": status]);
}

```

Now we've got a couple of functions that use our user record type. And having
just included the `ActiveRecord` mixin, we've got all these methods without
having to write a single line of code!

Of course, this example does make a bunch of assumptions, but if anything goes
awry, a `RecordException` is thrown.

### Record Functions

Including the `ActiveRecord` mixin in your class gives you 5 methods to work
with, right out of the box. Here's a look at them, in detail.

|Name  |Static|Parameters                |Description                          |
|:-----|:-----|:-------------------------|:------------------------------------|
|get   |Yes   |Value of the Id column    |Fetches a Record, by its Id.         |
|find  |Yes   |Map column names to values|Fetches all matching Records.        |
|create|No    |None                      |Inserts the Record into the database.|
|save  |No    |(Optional) List of columns|Updates the Record in the database. Optionally, a list of specific columns to update.|
|remove|No    |None                      |Deletes the Record from the database.|

Inner Mechanics
---------------

Here's a look at the inner working of Dart, and how you can use and modify them
to fit your needs, and extend existing functionality.

### Query Producers

The record functions that come pre-baked into Dart should be sufficient for most
uses. However, if one or more such functions are not sufficient, Dart provides
a system for customizing their behaviors.

|Record Function|Query Producer Signature                               |
|:--------------|:------------------------------------------------------|
|get            |`getQueryForGet(KT)(KT key)`                           |
|find           |`getQueryForFind(KT)(KT[string] conditions)`           |
|create         |`getQueryForCreate(T)(T record)`                       |
|save           |`getQueryForSave(T)(T record, string[] columns = null)`|
|remove         |`getQueryForRemove(T)(T record)`                       |

Record functions in Dart each have a corresponding static function which
generates queries for their operations (aka. `query producers`). Defining a
matching function in your Record class will override the existing behavior.

Query producers are always static, and all return a `QueryBuilder`.

### Query Builders

A `QueryBuilder` serves as a contract, intended to produce a query string and
optionally a set of query parameters (as an array of `Variant` values).
Query builders follow the `builder` design pattern, using chained calls to build
a query string, without the need for a string literal. Here's a quick look:

```d

static QueryBuilder getQueryForCreate(UserRecord record)
{
    return new InsertBuilder()
            .insert(join([getColumnNames(), "registered"])).into("users")
            .values(join([getColumnValues(record), Clock.currStdTime()]));
}

```

In this little example, we've extended the query for `create` to also store
the date and time the user was created on.

Dart provides 4 specialized query builder types, (`SelectBuilder`,
`InsertBuilder`, `UpdateBuilder`, and `DeleteBuilder`) which serve to build
a specific type SQL statement. Also available are `WhereBuilder`, for creating
complex WHERE conditions, and `GenericBuilder`, which serves as a light wrapper
around a query string and a set of parameters.

For example, if we wanted to write our own function that finds all users that
have set a user status, and have a status that's `like` 'offline' or haven't
been online in at least a year, we could do something like:

```d

static QueryBuilder getQueryForFindInactive()
{
    auto whereCondition = new WhereBuilder()
            .isNotNull("status").and()
            .openParen()    // (
                .like("status", "offline").or()
                .lessThan("last_online", getTimeLastYear)
            .closeParen();  // )

    return new SelectBuilder().from("users")
            .where(whereCondition)
            .orderBy("username")
            .limit(50);
}

```

And the query produced will be along the lines of:

```sql

SELECT * FROM `users`
WHERE `status` IS NOT NULL AND (`status` LIKE ? OR `last_online` < ?)
ORDER BY `username`
LIMIT 50;

```

And now we've got a function that produces a query to look up inactive users!
The `WhereBuilder` will store the parameters passed to it internally, and
they'll be passed safely through a prepared statement once the query gets
executed.

License
-------

MIT
