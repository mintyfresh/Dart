
module dart.tests.common;

import dart.record;

@Table("test_record")
class TestRecord : Record {

    mixin ActiveRecord!(TestRecord);

    @Id
    @AutoIncrement
    int id;

    @Column
    @MaxLength(5)
    string name;

    @Column
    int type;

    static this() {
        _setMysqlDB(new MysqlDB("127.0.0.1", "test", "test", "test"));
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

    // Test max-length.
    try {
        record.name = "Test123";
        record.save;

        // Should not be reached.
        assert(false);
    } catch(Exception e) {
        // Success.
    }

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

    // Test record remove.
    record = records[0];
    record.remove;

}
