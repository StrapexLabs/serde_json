use core::array::Array;
use core::byte_array::{ByteArray, ByteArrayTrait};
use serde_json::{JsonDeserialize, deserialize_from_byte_array, json_parser};

#[derive(Drop, Default, SerdeJson)]
struct Event {
    id: felt252,
    name: ByteArray,
    active: bool,
    timestamp: u256,
}

#[derive(Drop, Default, SerdeJson)]
struct User {
    name: ByteArray,
    age: u64,
    verified: bool,
}

#[derive(Drop, SerdeJson)]
struct Post {
    user: User,
    message: ByteArray,
    comments: Array<ByteArray>,
    timestamp: u64,
}

#[derive(Drop, SerdeJson, Default)]
struct TestBigNumber {
    test_value: u128,
    description: ByteArray,
}

#[derive(Drop, SerdeJson, Default)]
struct TestDecimalNumber {
    decimal_value: u256,
    description: ByteArray,
}

#[derive(Drop, SerdeJson, Default)]
struct TestAllNumericDecimals {
    u32_value: u32,
    u64_value: u64,
    u128_value: u128,
    u256_value: u256,
    felt252_value: felt252,
    description: ByteArray,
}

#[cfg(test)]
mod tests {
    use core::byte_array::ByteArray;
    use core::panic_with_felt252;
    use super::{
        Event, Post, TestAllNumericDecimals, TestBigNumber, TestDecimalNumber, User,
        deserialize_from_byte_array,
    };

    #[test]
    fn test_correct_deserialization() {
        let json: ByteArray =
            "{\"user\":{\"name\":\"john\",\"age\":42,\"verified\":false},\"message\":\"hello\",\"comments\":[],\"timestamp\":1704748800}";
        let result = deserialize_from_byte_array::<Post>(json);
        match result {
            Result::Ok(post) => {
                assert(post.user.name == "john", 'user name should be john');
                assert(post.user.age == 42, 'user age should be 42');
                assert(!post.user.verified, 'verified should be false');
                assert(post.message == "hello", 'message should be hello');
                assert(post.comments.len() == 0, 'comments should be empty');
                assert(post.timestamp == 1704748800, 'timestamp should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Deserialization failed');
            },
        }
    }

    #[test]
    fn test_invalid_json() {
        let json: ByteArray = "not_a_json";
        let result = deserialize_from_byte_array::<Post>(json);
        match result {
            Result::Ok(_) => panic(array!['Expected failure']),
            Result::Err(e) => assert(e == "Expected object", 'Wrong error'),
        }
    }

    #[test]
    fn test_missing_braces() {
        let json: ByteArray = "user:john";
        let result = deserialize_from_byte_array::<Post>(json);
        match result {
            Result::Ok(_) => panic(array!['Expected failure']),
            Result::Err(e) => assert(e == "Expected object", 'Wrong error'),
        }
    }

    #[test]
    fn test_invalid_timestamp() {
        let json: ByteArray =
            "{\"user\":{\"name\":\"john\",\"age\":42,\"verified\":false},\"message\":\"hello\",\"comments\":[],\"timestamp\":\"not_a_number\"}";
        let result = deserialize_from_byte_array::<Post>(json);
        match result {
            Result::Ok(_) => panic(array!['Expected failure']),
            Result::Err(e) => assert(e == "Failed to parse timestamp", 'Wrong error'),
        }
    }

    #[test]
    fn test_user_with_bool() {
        let json: ByteArray = "{\"name\":\"alice\",\"age\":25,\"verified\":true}";
        let result = deserialize_from_byte_array::<User>(json);
        match result {
            Result::Ok(user) => {
                assert(user.name == "alice", 'name should be alice');
                assert(user.age == 25, 'age should be 25');
                assert(user.verified, 'verified should be true');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Deserialization failed');
            },
        }
    }

    #[test]
    fn test_post_with_array() {
        let json: ByteArray =
            "{\"user\":{\"name\":\"john\",\"age\":42,\"verified\":false},\"message\":\"hello\",\"comments\":[\"nice\",\"cool\"],\"timestamp\":1704748800}";
        let result = deserialize_from_byte_array::<Post>(json);
        match result {
            Result::Ok(post) => {
                assert(post.user.name == "john", 'user name should be john');
                assert(post.user.age == 42, 'user age should be 42');
                assert(!post.user.verified, 'verified should be false');
                assert(post.message == "hello", 'message should be hello');
                assert(post.comments.len() == 2, 'should have 2 comments');
                assert(post.comments[0] == @"nice", 'first comment wrong');
                assert(post.comments[1] == @"cool", 'second comment wrong');
                assert(post.timestamp == 1704748800, 'timestamp should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Deserialization failed');
            },
        }
    }

    #[test]
    fn test_invalid_bool() {
        let json: ByteArray = "{\"name\":\"alice\",\"age\":25,\"verified\":\"not_a_bool\"}";
        let result = deserialize_from_byte_array::<User>(json);
        match result {
            Result::Ok(_) => panic(array!['Expected failure']),
            Result::Err(e) => assert(e == "Failed to parse verified", 'Wrong error'),
        }
    }

    #[test]
    fn test_invalid_array() {
        let json: ByteArray =
            "{\"user\":{\"name\":\"john\",\"age\":42,\"verified\":false},\"message\":\"hello\",\"comments\":\"not_an_array\",\"timestamp\":1704748800}";
        let result = deserialize_from_byte_array::<Post>(json);
        match result {
            Result::Ok(_) => panic(array!['Expected failure']),
            Result::Err(e) => assert(e == "Failed to parse comments", 'Wrong error'),
        }
    }

    #[test]
    fn test_event_with_felt252() {
        let json: ByteArray =
            "{\"id\":123456,\"name\":\"launch\",\"active\":true,\"timestamp\":115792089237316195423570985008687907853269984665640564039457584007913129639935}";
        let result = deserialize_from_byte_array::<Event>(json);
        match result {
            Result::Ok(event) => {
                assert(event.id == 123456, 'id should be 123456');
                assert(event.name == "launch", 'name should be launch');
                assert(event.active, 'active should be true');
                assert(
                    event
                        .timestamp == 115792089237316195423570985008687907853269984665640564039457584007913129639935_u256,
                    'timestamp should be max u256',
                );
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Deserialization failed');
            },
        }
    }

    #[test]
    fn test_invalid_felt252() {
        let json: ByteArray = "{\"id\":\"not_a_number\",\"name\":\"launch\",\"active\":true}";
        let result = deserialize_from_byte_array::<Event>(json);
        match result {
            Result::Ok(_) => panic(array!['Expected failure']),
            Result::Err(e) => assert(e == "Failed to parse id", 'Wrong error'),
        }
    }

    #[test]
    fn test_missing_felt252() {
        let json: ByteArray = "{\"name\":\"launch\",\"active\":true}";
        let result = deserialize_from_byte_array::<Event>(json);
        match result {
            Result::Ok(_) => panic(array!['Expected failure']),
            Result::Err(e) => assert(e == "Missing required field", 'Wrong error'),
        }
    }

    #[test]
    fn test_quoted_numbers() {
        // Test with quoted u64
        let json: ByteArray = "{\"name\":\"alice\",\"age\":\"25\",\"verified\":true}";
        let result = deserialize_from_byte_array::<User>(json);
        match result {
            Result::Ok(user) => {
                assert(user.name == "alice", 'name should be alice');
                assert(user.age == 25, 'age should be 25');
                assert(user.verified, 'verified should be true');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Deserialization failed');
            },
        }

        // Test with quoted felt252 and u256
        let json: ByteArray =
            "{\"id\":\"123456\",\"name\":\"launch\",\"active\":true,\"timestamp\":\"115792089237316195423570985008687907853269984665640564039457584007913129639935\"}";
        let result = deserialize_from_byte_array::<Event>(json);
        match result {
            Result::Ok(event) => {
                assert(event.id == 123456, 'id should be 123456');
                assert(event.name == "launch", 'name should be launch');
                assert(event.active, 'active should be true');
                assert(
                    event
                        .timestamp == 115792089237316195423570985008687907853269984665640564039457584007913129639935_u256,
                    'timestamp should be max u256',
                );
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Deserialization failed');
            },
        }
    }

    #[test]
    fn test_u128_parsing() {
        // Test with unquoted u128
        let json: ByteArray =
            "{\"test_value\":340282366920938463463374607431768211455,\"description\":\"max u128\"}";
        let result = deserialize_from_byte_array::<TestBigNumber>(json);
        match result {
            Result::Ok(big_num) => {
                assert(
                    big_num.test_value == 340282366920938463463374607431768211455_u128,
                    'value should be max u128',
                );
                assert(big_num.description == "max u128", 'description should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Deserialization failed');
            },
        }

        // Test with quoted u128
        let json: ByteArray = "{\"test_value\":\"9223372036854775808\",\"description\":\"2^63\"}";
        let result = deserialize_from_byte_array::<TestBigNumber>(json);
        match result {
            Result::Ok(big_num) => {
                assert(big_num.test_value == 9223372036854775808_u128, 'value should be 2^63');
                assert(big_num.description == "2^63", 'description should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Deserialization failed');
            },
        }
    }

    #[test]
    fn test_multiline_json() {
        // Test with a multiline formatted JSON with significant whitespace and newlines
        let json: ByteArray = "{\n  \"name\": \"alice\",\n  \"age\": 25,\n  \"verified\": true\n}";
        let result = deserialize_from_byte_array::<User>(json);
        match result {
            Result::Ok(user) => {
                assert(user.name == "alice", 'name should be alice');
                assert(user.age == 25, 'age should be 25');
                assert(user.verified, 'verified should be true');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Failed');
            },
        }
    }

    #[test]
    fn test_deeply_nested_multiline_json() {
        // Test with a deeply nested multiline JSON with various indentation levels
        let json: ByteArray =
            "{\n  \"user\": {\n    \"name\": \"john\",\n    \"age\": 42,\n    \"verified\": false\n  },\n  \"message\": \"hello\",\n  \"comments\": [\n    \"nice\",\n    \"cool\"\n  ],\n  \"timestamp\": 1704748800\n}";
        let result = deserialize_from_byte_array::<Post>(json);
        match result {
            Result::Ok(post) => {
                assert(post.user.name == "john", 'user name should be john');
                assert(post.user.age == 42, 'user age should be 42');
                assert(!post.user.verified, 'verified should be false');
                assert(post.message == "hello", 'message should be hello');
                assert(post.comments.len() == 2, 'should have 2 comments');
                assert(post.comments[0] == @"nice", 'first comment wrong');
                assert(post.comments[1] == @"cool", 'second comment wrong');
                assert(post.timestamp == 1704748800, 'timestamp should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Failed');
            },
        }
    }

    #[test]
    fn test_mixed_whitespace_styles() {
        // Test with a mix of tabs, spaces, and various whitespace characters
        let json: ByteArray =
            "{\r\n\t\"name\":\t\"bob\",\r\n  \"age\":   30,\r\n\t\t\"verified\":  true\r\n}";
        let result = deserialize_from_byte_array::<User>(json);
        match result {
            Result::Ok(user) => {
                assert(user.name == "bob", 'name should be bob');
                assert(user.age == 30, 'age should be 30');
                assert(user.verified, 'verified should be true');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Failed');
            },
        }
    }

    #[test]
    fn test_preserve_string_whitespace() {
        // Test that whitespace within strings is preserved correctly
        let json: ByteArray =
            "{\n  \"name\": \"john \t doe\",\n  \"age\": 25,\n  \"verified\": true\n}";
        let result = deserialize_from_byte_array::<User>(json);
        match result {
            Result::Ok(user) => {
                assert(user.name == "john \t doe", 'whitespace in string preserved');
                assert(user.age == 25, 'age should be 25');
                assert(user.verified, 'verified should be true');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Failed');
            },
        }
    }

    #[test]
    fn test_multiline_complex_proof() {
        // Test with a complex multiline JSON typical for proof objects
        // Using only fields that exist in the Event struct (id, name, active)
        let json: ByteArray =
            "{\n  \"id\": 123456,\n  \"name\": \"Proof Object\",\n  \"active\": true,\n  \"timestamp\": 0\n}";

        let result = deserialize_from_byte_array::<Event>(json);
        match result {
            Result::Ok(event) => {
                assert(event.id == 123456, 'id should be 123456');
                assert(event.name == "Proof Object", 'name should match');
                assert(event.active, 'active should be true');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Failed');
            },
        }
    }

    #[test]
    fn test_u256_decimal_parsing() {
        // Test parsing decimal number "1430.1" as u256
        let json: ByteArray = "{\"decimal_value\":\"1430.1\",\"description\":\"decimal test\"}";
        let result = deserialize_from_byte_array::<TestDecimalNumber>(json);
        match result {
            Result::Ok(decimal_num) => {
                assert(decimal_num.decimal_value == 14301_u256, 'should be 14301 (1430.1 * 10)');
                assert(decimal_num.description == "decimal test", 'description should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Decimal parsing failed');
            },
        }

        // Test parsing decimal number "123.456" as u256
        let json2: ByteArray = "{\"decimal_value\":\"123.456\",\"description\":\"three decimals\"}";
        let result2 = deserialize_from_byte_array::<TestDecimalNumber>(json2);
        match result2 {
            Result::Ok(decimal_num) => {
                assert(decimal_num.decimal_value == 123456_u256, 'should be 123456');
                assert(decimal_num.description == "three decimals", 'description should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Decimal parsing failed');
            },
        }

        // Test parsing whole number without decimal point
        let json3: ByteArray = "{\"decimal_value\":\"42\",\"description\":\"whole number\"}";
        let result3 = deserialize_from_byte_array::<TestDecimalNumber>(json3);
        match result3 {
            Result::Ok(decimal_num) => {
                assert(decimal_num.decimal_value == 42_u256, 'should be 42');
                assert(decimal_num.description == "whole number", 'description should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Whole number parsing failed');
            },
        }

        // Test parsing decimal with leading zero "0.5"
        let json4: ByteArray = "{\"decimal_value\":\"0.5\",\"description\":\"leading zero\"}";
        let result4 = deserialize_from_byte_array::<TestDecimalNumber>(json4);
        match result4 {
            Result::Ok(decimal_num) => {
                assert(decimal_num.decimal_value == 5_u256, 'should be 5 (0.5 * 10)');
                assert(decimal_num.description == "leading zero", 'description should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Leading zero failed');
            },
        }
    }

    #[test]
    fn test_all_numeric_types_decimal_parsing() {
        // Test parsing decimals for all numeric types in one struct
        let json: ByteArray =
            "{\"u32_value\":\"12.34\",\"u64_value\":\"567.89\",\"u128_value\":\"999.123\",\"u256_value\":\"1000.5\",\"felt252_value\":\"42.7\",\"description\":\"all types\"}";
        let result = deserialize_from_byte_array::<TestAllNumericDecimals>(json);
        match result {
            Result::Ok(all_nums) => {
                assert(all_nums.u32_value == 1234_u32, 'u32: 12.34 -> 1234');
                assert(all_nums.u64_value == 56789_u64, 'u64: 567.89 -> 56789');
                assert(all_nums.u128_value == 999123_u128, 'u128: 999.123 -> 999123');
                assert(all_nums.u256_value == 10005_u256, 'u256: 1000.5 -> 10005');
                assert(all_nums.felt252_value == 427, 'felt252: 42.7 -> 427');
                assert(all_nums.description == "all types", 'description should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('All numeric types test failed');
            },
        }

        // Test edge case: single decimal place for all types
        let json2: ByteArray =
            "{\"u32_value\":\"1.0\",\"u64_value\":\"2.0\",\"u128_value\":\"3.0\",\"u256_value\":\"4.0\",\"felt252_value\":\"5.0\",\"description\":\"single decimal\"}";
        let result2 = deserialize_from_byte_array::<TestAllNumericDecimals>(json2);
        match result2 {
            Result::Ok(all_nums) => {
                assert(all_nums.u32_value == 10_u32, 'u32: 1.0 -> 10');
                assert(all_nums.u64_value == 20_u64, 'u64: 2.0 -> 20');
                assert(all_nums.u128_value == 30_u128, 'u128: 3.0 -> 30');
                assert(all_nums.u256_value == 40_u256, 'u256: 4.0 -> 40');
                assert(all_nums.felt252_value == 50, 'felt252: 5.0 -> 50');
                assert(all_nums.description == "single decimal", 'description should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Single decimal test failed');
            },
        }

        // Test unquoted decimal parsing
        let json3: ByteArray =
            "{\"u32_value\":12.5,\"u64_value\":34.6,\"u128_value\":78.9,\"u256_value\":100.1,\"felt252_value\":200.2,\"description\":\"unquoted decimals\"}";
        let result3 = deserialize_from_byte_array::<TestAllNumericDecimals>(json3);
        match result3 {
            Result::Ok(all_nums) => {
                assert(all_nums.u32_value == 125_u32, 'u32: 12.5 -> 125');
                assert(all_nums.u64_value == 346_u64, 'u64: 34.6 -> 346');
                assert(all_nums.u128_value == 789_u128, 'u128: 78.9 -> 789');
                assert(all_nums.u256_value == 1001_u256, 'u256: 100.1 -> 1001');
                assert(all_nums.felt252_value == 2002, 'felt252: 200.2 -> 2002');
                assert(all_nums.description == "unquoted decimals", 'description should match');
            },
            Result::Err(e) => {
                println!("error: {}", e);
                panic_with_felt252('Unquoted decimal test failed');
            },
        }
    }

    #[test]
    fn test_decimal_overflow_handling() {
        // Test u32 overflow - use value that will cause multiplier overflow for u32
        let json_u32_overflow: ByteArray =
            "{\"u32_value\":\"1.1234567890123456789\",\"u64_value\":\"1\",\"u128_value\":\"1\",\"u256_value\":\"1\",\"felt252_value\":\"1\",\"description\":\"u32 overflow\"}";
        let result_u32 = deserialize_from_byte_array::<TestAllNumericDecimals>(json_u32_overflow);
        match result_u32 {
            Result::Ok(_) => panic(array!['Expected u32 overflow error']),
            Result::Err(e) => {
                // Should get an error about decimal value being too large
                assert(e == "Failed to parse u32_value", 'Should fail u32 parsing');
            },
        }

        // Test u64 overflow - use value that will cause multiplier overflow for u64
        let json_u64_overflow: ByteArray =
            "{\"u32_value\":\"1\",\"u64_value\":\"1.12345678901234567890123\",\"u128_value\":\"1\",\"u256_value\":\"1\",\"felt252_value\":\"1\",\"description\":\"u64 overflow\"}";
        let result_u64 = deserialize_from_byte_array::<TestAllNumericDecimals>(json_u64_overflow);
        match result_u64 {
            Result::Ok(_) => panic(array!['Expected u64 overflow error']),
            Result::Err(e) => {
                // Should get an error about decimal value being too large
                assert(e == "Failed to parse u64_value", 'Should fail u64 parsing');
            },
        }

        // Test u128 overflow - use value that will cause multiplier overflow for u128
        let json_u128_overflow: ByteArray =
            "{\"u32_value\":\"1\",\"u64_value\":\"1\",\"u128_value\":\"1.1234567890123456789012345678901234567890123456789\",\"u256_value\":\"1\",\"felt252_value\":\"1\",\"description\":\"u128 overflow\"}";
        let result_u128 = deserialize_from_byte_array::<TestAllNumericDecimals>(json_u128_overflow);
        match result_u128 {
            Result::Ok(_) => panic(array!['Expected u128 overflow error']),
            Result::Err(e) => {
                // Should get an error about decimal value being too large
                assert(e == "Failed to parse u128_value", 'Should fail u128 parsing');
            },
        }
    }

    #[test]
    fn test_specific_overflow_protection() {
        // Test that we can handle a simple case that should work
        let json_good: ByteArray =
            "{\"u32_value\":\"1.23\",\"u64_value\":\"1\",\"u128_value\":\"1\",\"u256_value\":\"1\",\"felt252_value\":\"1\",\"description\":\"good case\"}";
        let result_good = deserialize_from_byte_array::<TestAllNumericDecimals>(json_good);
        match result_good {
            Result::Ok(nums) => { assert(nums.u32_value == 123_u32, 'Should parse 1.23 as 123'); },
            Result::Err(_) => panic(array!['Good case should work']),
        }

        // Test that extremely large multiplier causes overflow protection
        // Using 50 decimal places which will definitely overflow u32 multiplier
        let json_overflow: ByteArray =
            "{\"u32_value\":\"1.12345678901234567890123456789012345678901234567890\",\"u64_value\":\"1\",\"u128_value\":\"1\",\"u256_value\":\"1\",\"felt252_value\":\"1\",\"description\":\"overflow case\"}";
        let result_overflow = deserialize_from_byte_array::<TestAllNumericDecimals>(json_overflow);
        match result_overflow {
            Result::Ok(_) => panic(array!['Should fail overflow']),
            Result::Err(e) => {
                // The error should be about failing to parse the u32_value field
                assert(e == "Failed to parse u32_value", 'Should fail u32 overflow');
            },
        }
    }
}
