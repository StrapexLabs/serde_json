# Serde JSON for Cairo StarkNet Contracts

Serde JSON is a library for deserializing JSON data into Cairo structs, designed specifically for use in StarkNet contracts. It enables developers to easily parse and process JSON data from external sources, such as APIs or user inputs, within their Cairo smart contracts.

## Features

- **Deserialization of Basic Types:** Supports `bool`, `u32`, `u64`, `u128`, `u256`, `felt252`, and `ByteArray`.
- **Decimal Number Parsing:** All numeric types support parsing decimal values (e.g., "1430.1") which are automatically converted to fixed-point representation.
- **Custom Structs:** Use the `#[derive(SerdeJson)]` attribute to automatically generate deserialization code for your structs.
- **Arrays:** Deserialize arrays of supported types, including nested arrays.
- **Whitespace Handling:** Correctly handles whitespace, including multiline JSON with newlines, tabs, and spaces.
- **Quoted Numbers:** Parses numbers whether they are quoted or not in the JSON string.
- **Error Handling:** Provides detailed error messages for invalid JSON or missing fields.

## Installation

To use Serde JSON in your Cairo project, add the following dependencies to your `Scarb.toml`:

```toml
[dependencies]

serde_json = { git = "https://github.com/StrapexLabs/serde_json", tag = "v0.1.1" }
serde_json_macro = { git = "https://github.com/StrapexLabs/serde_json", tag = "v0.1.1" }

```

Replace `v0.1.0` with the appropriate tag or branch for the version you wish to use.

## Usage

1. **Derive SerdeJson for Your Structs:**
   - Add `#[derive(SerdeJson)]` to your struct definitions to enable JSON deserialization.

2. **Deserialize JSON Data:**
   - Use the `deserialize_from_byte_array` function to convert a JSON `ByteArray` into your struct.

### Example

```cairo
use serde_json::{deserialize_from_byte_array, JsonDeserialize};

#[derive(Drop, SerdeJson)]
struct User {
    name: ByteArray,
    age: u64,
    verified: bool,
}

fn main() {
    let json: ByteArray = "{\"name\":\"alice\",\"age\":25,\"verified\":true}";
    let result = deserialize_from_byte_array::<User>(json);
    match result {
        Result::Ok(user) => {
            assert(user.name == "alice", 'name should be alice');
            assert(user.age == 25, 'age should be 25');
            assert(user.verified, 'verified should be true');
        },
        Result::Err(e) => {
            println!("Deserialization error: {}", e);
        },
    }
}
```

### Nested Structs and Arrays

The library also supports deserializing nested structs and arrays. For example:

```cairo
#[derive(Drop, SerdeJson)]
struct Post {
    user: User,
    message: ByteArray,
    comments: Array<ByteArray>,
    timestamp: u64,
}

let json: ByteArray = "{\"user\":{\"name\":\"john\",\"age\":42,\"verified\":false},\"message\":\"hello\",\"comments\":[\"nice\",\"cool\"],\"timestamp\":1704748800}";
let result = deserialize_from_byte_array::<Post>(json);
// Handle the result...
```

### Whitespace Handling

The library correctly handles whitespace in JSON, including spaces, tabs, newlines, and carriage returns. This allows it to parse multiline JSON strings without issues. Whitespace inside strings is preserved, ensuring accurate deserialization of string values.

### Quoted Numbers

Numbers in JSON can be quoted (e.g., `"42"` instead of `42`). The library supports parsing both quoted and unquoted numbers for numeric fields.

## Limitations

- **Required Fields:** All fields in the struct must be present in the JSON data. Missing fields will result in a "Missing required field" error.
- **Serialization:** Currently, only deserialization is supported. Serialization of Cairo structs to JSON is not yet implemented.
- **Optional Fields:** The library does not support optional fields out of the box. All fields are treated as required.

## Contributing

Contributions are welcome! If you encounter any issues or have suggestions for improvements, please open an issue or submit a pull request on the [GitHub repository](https://github.com/StrapexLabs/serde_json).