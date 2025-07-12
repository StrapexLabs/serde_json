use core::array::{Array, ArrayTrait};
use core::byte_array::{ByteArray, ByteArrayTrait};
use core::result::Result;
use super::JsonDeserialize;

pub mod json_parser {
    use super::{Array, ArrayTrait, ByteArray, ByteArrayTrait, Result};

    pub fn skip_whitespace(data: @ByteArray, ref pos: usize) {
        let space = 32_u8;
        let newline = 10_u8;
        let tab = 9_u8;
        let carriage_return = 13_u8; // '\r'

        while pos < data.len()
            && (data[pos] == space
                || data[pos] == newline
                || data[pos] == tab
                || data[pos] == carriage_return) {
            pos += 1;
        }
    }

    /// Parses the decimal part of a number after the decimal point.
    /// Returns a tuple of (decimal_places_count, decimal_value, has_decimal_digits).
    ///
    /// # Arguments
    /// * `data` - The byte array containing the JSON data
    /// * `pos` - Reference to the current position in the byte array (will be advanced)
    ///
    /// # Returns
    /// * `decimal_places` - Number of decimal places found
    /// * `decimal_part` - The numeric value of the decimal part as u256
    /// * `has_decimal_digits` - Whether any decimal digits were found
    fn parse_decimal_part(data: @ByteArray, ref pos: usize) -> (u32, u256, bool) {
        let mut decimal_places = 0_u32;
        let mut decimal_part: u256 = 0;
        let mut has_decimal_digits = false;

        // Parse decimal part
        while pos < data.len() && (data[pos] >= 48_u8 && data[pos] <= 57_u8) {
            decimal_part = decimal_part * 10 + (data[pos] - 48_u8).into();
            decimal_places += 1;
            pos += 1;
            has_decimal_digits = true;
        }

        (decimal_places, decimal_part, has_decimal_digits)
    }

    /// Calculates the multiplier for converting decimal to fixed-point representation.
    /// Returns 10^decimal_places as a u256.
    ///
    /// # Arguments
    /// * `decimal_places` - The number of decimal places
    ///
    /// # Returns
    /// * The multiplier value (10^decimal_places)
    ///
    /// # Example
    /// * calculate_multiplier(1) returns 10
    /// * calculate_multiplier(3) returns 1000
    fn calculate_multiplier(decimal_places: u32) -> u256 {
        let mut multiplier: u256 = 1;
        let mut i = 0_u32;
        while i < decimal_places {
            multiplier *= 10;
            i += 1;
        }
        multiplier
    }

    pub fn parse_string(data: @ByteArray, ref pos: usize) -> Result<ByteArray, ByteArray> {
        if pos >= data.len() || data[pos] != 34_u8 { // '"'
            let error: ByteArray = "Expected string quote at position "; // + pos.try_into();
            return Result::Err(error);
        }
        pos += 1;
        let mut result: ByteArray = "";
        let mut success: bool = true;
        let mut error: ByteArray = "";

        while pos < data.len() && data[pos] != 34_u8 && success {
            if data[pos] == 92_u8 { // '\'
                pos += 1;
                if pos >= data.len() {
                    error = "Unterminated string at position "; // + pos.try_into();
                    success = false;
                    break;
                }
                let escape_char = data[pos];
                if escape_char == 34_u8 { // '\"' -> '"'
                    result.append_byte(34_u8);
                } else if escape_char == 92_u8 { // '\\' -> '\'
                    result.append_byte(92_u8);
                } else if escape_char == 47_u8 { // '\/' -> '/'
                    result.append_byte(47_u8);
                } else if escape_char == 98_u8 { // '\b' -> backspace
                    result.append_byte(8_u8);
                } else if escape_char == 102_u8 { // '\f' -> form feed
                    result.append_byte(12_u8);
                } else if escape_char == 110_u8 { // '\n' -> newline
                    result.append_byte(10_u8);
                } else if escape_char == 114_u8 { // '\r' -> carriage return
                    result.append_byte(13_u8);
                } else if escape_char == 116_u8 { // '\t' -> tab
                    result.append_byte(9_u8);
                } else {
                    error = "Invalid escape sequence at position ";
                    break;
                }
                pos += 1;
            } else {
                result.append_byte(data[pos]);
                pos += 1;
            }
        }

        if !success {
            Result::Err(error)
        } else if pos >= data.len() || data[pos] != 34_u8 {
            let error: ByteArray = "Unterminated string at position "; // + pos.try_into();
            Result::Err(error)
        } else {
            pos += 1;
            Result::Ok(result)
        }
    }

    pub fn parse_felt252(data: @ByteArray, ref pos: usize) -> Result<felt252, ByteArray> {
        skip_whitespace(data, ref pos);

        // Check if we have a quoted number
        let is_quoted = pos < data.len() && data[pos] == 34_u8; // '"'
        if is_quoted {
            pos += 1; // Skip the opening quote
        }

        let mut num: felt252 = 0;
        let mut has_digits = false;

        // Parse integer part
        while pos < data.len() && (data[pos] >= 48_u8 && data[pos] <= 57_u8) { // '0' to '9'
            num = num * 10 + (data[pos] - 48_u8).into();
            pos += 1;
            has_digits = true;
        }

        // Check for decimal point
        if pos < data.len() && data[pos] == 46_u8 { // '.'
            pos += 1; // Skip the decimal point
            let (decimal_places, decimal_part_u256, has_decimal_digits) = parse_decimal_part(
                data, ref pos,
            );
            if has_decimal_digits {
                has_digits = true;
            }

            let multiplier_u256 = calculate_multiplier(decimal_places);
            let multiplier: felt252 = multiplier_u256.try_into().unwrap();
            let decimal_part: felt252 = decimal_part_u256.try_into().unwrap();
            num = num * multiplier + decimal_part;
        }

        if is_quoted {
            // If it's quoted, we should end with a closing quote
            if pos >= data.len() || data[pos] != 34_u8 {
                return Result::Err("Unterminated number string");
            }
            pos += 1; // Skip the closing quote
        }

        if !has_digits {
            let error: ByteArray = "Expected number";
            return Result::Err(error);
        }
        Result::Ok(num)
    }

    pub fn parse_object<T, impl TDeserialize: super::JsonDeserialize<T>, impl TDrop: Drop<T>>(
        data: @ByteArray, ref pos: usize,
    ) -> Result<T, ByteArray> {
        skip_whitespace(data, ref pos);
        if pos >= data.len() || data[pos] != 123_u8 { // '{'
            return Result::Err("Expected object");
        }
        pos += 1;
        skip_whitespace(data, ref pos);

        let result = TDeserialize::deserialize(data, ref pos);

        let obj = result?; // This propagates error immediately

        skip_whitespace(data, ref pos);
        if pos >= data.len() || data[pos] != 125_u8 { // '}'
            return Result::Err("Expected closing brace");
        }
        pos += 1;

        Result::Ok(obj)
    }

    pub fn parse_array<T, impl TDeserialize: super::JsonDeserialize<T>, impl TDrop: Drop<T>>(
        data: @ByteArray, ref pos: usize,
    ) -> Result<Array<T>, ByteArray> {
        skip_whitespace(data, ref pos);
        if pos >= data.len() || data[pos] != 91_u8 { // '['
            return Result::Err("Expected array opening bracket");
        }
        pos += 1;

        let mut result = array![];
        skip_whitespace(data, ref pos);

        if pos < data.len() && data[pos] == 93_u8 { // ']'
            pos += 1;
            return Result::Ok(result);
        }

        let mut success = true;
        let mut error: ByteArray = "";

        loop {
            skip_whitespace(data, ref pos);
            match TDeserialize::deserialize(data, ref pos) {
                Result::Ok(value) => { result.append(value); },
                Result::Err(err) => {
                    error = err;
                    success = false;
                    break;
                },
            }

            skip_whitespace(data, ref pos);
            if pos >= data.len() {
                error = "Unterminated array";
                success = false;
                break;
            }
            let next_char = data[pos];
            if next_char == 93_u8 { // ']'
                pos += 1;
                break;
            } else if next_char != 44_u8 { // ','
                error = "Expected comma in array";
                success = false;
                break;
            }
            pos += 1; // Skip the comma
            skip_whitespace(data, ref pos);
        }

        if success {
            Result::Ok(result)
        } else {
            Result::Err(error)
        }
    }

    pub fn parse_bool(data: @ByteArray, ref pos: usize) -> Result<bool, ByteArray> {
        skip_whitespace(data, ref pos);
        if pos
            + 4 <= data.len() && data[pos] == 116_u8 && data[pos
            + 1] == 114_u8 && data[pos
            + 2] == 117_u8 && data[pos
            + 3] == 101_u8 {
            // "true"
            pos += 4;
            Result::Ok(true)
        } else if pos
            + 5 <= data.len() && data[pos] == 102_u8 && data[pos
            + 1] == 97_u8 && data[pos
            + 2] == 108_u8 && data[pos
            + 3] == 115_u8 && data[pos
            + 4] == 101_u8 {
            // "false"
            pos += 5;
            Result::Ok(false)
        } else {
            Result::Err("Expected boolean value")
        }
    }

    pub fn parse_u128(data: @ByteArray, ref pos: usize) -> Result<u128, ByteArray> {
        skip_whitespace(data, ref pos);

        // Check if we have a quoted number
        let is_quoted = pos < data.len() && data[pos] == 34_u8; // '"'
        if is_quoted {
            pos += 1; // Skip the opening quote
        }

        let mut num: u128 = 0;
        let mut has_digits = false;

        // Parse integer part
        while pos < data.len() && (data[pos] >= 48_u8 && data[pos] <= 57_u8) {
            num = num * 10 + (data[pos] - 48_u8).into();
            pos += 1;
            has_digits = true;
        }

        // Check for decimal point
        if pos < data.len() && data[pos] == 46_u8 { // '.'
            pos += 1; // Skip the decimal point
            let (decimal_places, decimal_part_u256, has_decimal_digits) = parse_decimal_part(
                data, ref pos,
            );
            if has_decimal_digits {
                has_digits = true;
            }

            let multiplier_u256 = calculate_multiplier(decimal_places);
            let multiplier: u128 = multiplier_u256.try_into().unwrap();
            let decimal_part: u128 = decimal_part_u256.try_into().unwrap();
            num = num * multiplier + decimal_part;
        }

        if is_quoted {
            // If it's quoted, we should end with a closing quote
            if pos >= data.len() || data[pos] != 34_u8 {
                return Result::Err("Unterminated number string");
            }
            pos += 1; // Skip the closing quote
        }

        if !has_digits {
            let error: ByteArray = "Expected number";
            return Result::Err(error);
        }
        Result::Ok(num)
    }

    pub fn parse_u64(data: @ByteArray, ref pos: usize) -> Result<u64, ByteArray> {
        skip_whitespace(data, ref pos);

        // Check if we have a quoted number
        let is_quoted = pos < data.len() && data[pos] == 34_u8; // '"'
        if is_quoted {
            pos += 1; // Skip the opening quote
        }

        let mut num: u64 = 0;
        let mut has_digits = false;

        // Parse integer part
        while pos < data.len() && (data[pos] >= 48_u8 && data[pos] <= 57_u8) {
            num = num * 10 + (data[pos] - 48_u8).into();
            pos += 1;
            has_digits = true;
        }

        // Check for decimal point
        if pos < data.len() && data[pos] == 46_u8 { // '.'
            pos += 1; // Skip the decimal point
            let (decimal_places, decimal_part_u256, has_decimal_digits) = parse_decimal_part(
                data, ref pos,
            );
            if has_decimal_digits {
                has_digits = true;
            }

            let multiplier_u256 = calculate_multiplier(decimal_places);
            let multiplier: u64 = multiplier_u256.try_into().unwrap();
            let decimal_part: u64 = decimal_part_u256.try_into().unwrap();
            num = num * multiplier + decimal_part;
        }

        if is_quoted {
            // If it's quoted, we should end with a closing quote
            if pos >= data.len() || data[pos] != 34_u8 {
                return Result::Err("Unterminated number string");
            }
            pos += 1; // Skip the closing quote
        }

        if !has_digits {
            let error: ByteArray = "Expected number";
            return Result::Err(error);
        }
        Result::Ok(num)
    }

    pub fn parse_u32(data: @ByteArray, ref pos: usize) -> Result<u32, ByteArray> {
        skip_whitespace(data, ref pos);

        // Check if we have a quoted number
        let is_quoted = pos < data.len() && data[pos] == 34_u8; // '"'
        if is_quoted {
            pos += 1; // Skip the opening quote
        }

        let mut num: u32 = 0;
        let mut has_digits = false;

        // Parse integer part
        while pos < data.len() && (data[pos] >= 48_u8 && data[pos] <= 57_u8) {
            num = num * 10 + (data[pos] - 48_u8).into();
            pos += 1;
            has_digits = true;
        }

        // Check for decimal point
        if pos < data.len() && data[pos] == 46_u8 { // '.'
            pos += 1; // Skip the decimal point
            let (decimal_places, decimal_part_u256, has_decimal_digits) = parse_decimal_part(
                data, ref pos,
            );
            if has_decimal_digits {
                has_digits = true;
            }

            let multiplier_u256 = calculate_multiplier(decimal_places);
            let multiplier: u32 = multiplier_u256.try_into().unwrap();
            let decimal_part: u32 = decimal_part_u256.try_into().unwrap();
            num = num * multiplier + decimal_part;
        }

        if is_quoted {
            // If it's quoted, we should end with a closing quote
            if pos >= data.len() || data[pos] != 34_u8 {
                return Result::Err("Unterminated number string");
            }
            pos += 1; // Skip the closing quote
        }

        if !has_digits {
            let error: ByteArray = "Expected number";
            return Result::Err(error);
        }
        Result::Ok(num)
    }

    pub fn parse_u256(data: @ByteArray, ref pos: usize) -> Result<u256, ByteArray> {
        skip_whitespace(data, ref pos);

        // Check if we have a quoted number
        let is_quoted = pos < data.len() && data[pos] == 34_u8; // '"'
        if is_quoted {
            pos += 1; // Skip the opening quote
        }

        let mut num: u256 = 0;
        let mut has_digits = false;

        // Parse integer part
        while pos < data.len() && (data[pos] >= 48_u8 && data[pos] <= 57_u8) {
            num = num * 10 + (data[pos] - 48_u8).into();
            pos += 1;
            has_digits = true;
        }

        // Check for decimal point
        if pos < data.len() && data[pos] == 46_u8 { // '.'
            pos += 1; // Skip the decimal point
            let (decimal_places, decimal_part, has_decimal_digits) = parse_decimal_part(
                data, ref pos,
            );
            if has_decimal_digits {
                has_digits = true;
            }

            // Convert decimal to fixed point by multiplying by 10^decimal_places
            // For example: 1430.1 becomes 14301 (multiply by 10^1)
            let multiplier = calculate_multiplier(decimal_places);
            num = num * multiplier + decimal_part;
        }

        if is_quoted {
            // If it's quoted, we should end with a closing quote
            if pos >= data.len() || data[pos] != 34_u8 {
                return Result::Err("Unterminated number string");
            }
            pos += 1; // Skip the closing quote
        }

        if !has_digits {
            let error: ByteArray = "Expected number";
            return Result::Err(error);
        }
        Result::Ok(num)
    }
}
