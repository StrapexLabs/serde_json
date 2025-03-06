use core::byte_array::ByteArray;
use super::parser::json_parser;

pub trait JsonDeserialize<T> {
    fn deserialize(data: @ByteArray, ref pos: usize) -> Result<T, ByteArray>;
}

// Implement JsonDeserialize for bool
impl BoolJsonDeserialize of JsonDeserialize<bool> {
    fn deserialize(data: @ByteArray, ref pos: usize) -> Result<bool, ByteArray> {
        json_parser::parse_bool(data, ref pos)
    }
}

// Implement JsonDeserialize for u64
impl U64JsonDeserialize of JsonDeserialize<u64> {
    fn deserialize(data: @ByteArray, ref pos: usize) -> Result<u64, ByteArray> {
        json_parser::parse_u64(data, ref pos)
    }
}

// Implement JsonDeserialize for ByteArray
impl ByteArrayJsonDeserialize of JsonDeserialize<ByteArray> {
    fn deserialize(data: @ByteArray, ref pos: usize) -> Result<ByteArray, ByteArray> {
        json_parser::parse_string(data, ref pos)
    }
}

impl ArrayJsonDeserialize<T, impl TDeserialize: JsonDeserialize<T>, impl TDrop: Drop<T>> of JsonDeserialize<Array<T>> {
    fn deserialize(data: @ByteArray, ref pos: usize) -> Result<Array<T>, ByteArray> {
        json_parser::parse_array::<T, TDeserialize, TDrop>(data, ref pos)
    }
}