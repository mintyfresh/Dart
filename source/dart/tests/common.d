
module dart.tests.common;

import dart.record;

@Table("test_record")
class TestRecord : Record!TestRecord {

    mixin ActiveRecord!();

    @Id
    @AutoIncrement
    int id;

    @Column
    @MaxLength(5)
    string name;

    @Column
    int type;

    static this() {
        setDBConnection(new MysqlDB("127.0.0.1", "test", "test", "test"));
    }

}

unittest {

    // Test record create.
    auto record = new TestRecord;
    record.name = "Test";
    record.type = 1;
    record.create;

    assert(record.id != 0);

    // Fetch the created record.
    record = TestRecord.get(record.id);
    assert(record !is null);
    assert(record.name == "Test");
    assert(record.type == 1);

    // Test record save.
    record.name = "Test2";
    record.type = 2;
    record.save;

    // Fetch the updated record.
    record = TestRecord.get(record.id);
    assert(record !is null);
    assert(record.name == "Test2");
    assert(record.type == 2);

    // Test record selective save.
    record.name = "Test3";
    record.type = 3;
    record.save("type");

    // Fetch the upated record.
    record = TestRecord.get(record.id);
    assert(record !is null);
    assert(record.name == "Test2");
    assert(record.type == 3);

    // Test record find.
    auto records = TestRecord.find(["name": "Test2"]);
    assert(records.length >= 1);
    assert(records[0].name == "Test2");
    assert(records[0].type == 3);

    // Test max-length.
    try {
        record.name = "Test123";
        record.save("name");

        // Should not be reached.
        assert(false);
    } catch(RecordException e) {
        // Success.
    }

    // Test not-null.
    try {
        record.name = null;
        record.save("name");

        // Should not be reached.
        assert(false);
    } catch(RecordException e) {
        // Success.
    }

    // Test record remove.
    record = records[0];
    record.remove;

    // Check that the record doens't exist.
    try {
        record = TestRecord.get(record.id);

        // Should not be reached.
        assert(false);
    } catch(RecordException e) {
        // Success.
    }

}

/* - Compound Fields - */
/* - - - - - - - - - - */

@Compound
struct TestCompound {

    @Column
    @MaxLength(32)
    string name;

    @Column
    @Nullable
    @MaxLength(128)
    string address;

}

@Table("test_record2")
class TestRecord2 : Record!TestRecord2 {

    mixin ActiveRecord!();

    @Id
    @AutoIncrement
    int id;

    @Embedded
    TestCompound info;

}

unittest {

    // TODO

}
