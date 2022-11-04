# JSONB
Binary JSON Library with support for structuring

This library was made for Roblox, which means it's coded in Luau. A specification file is left within this README. This does not explain how the encoder or decoder works, as it should work regardless of implementation details

## Usage
To use the included library, simply drag the built `RBXM` file into your game or clone the source code and sync using Rojo.

This library has two simple functions:
* `encode(data: {[any]: any}, structs: {[string]: {string}}?, asBase64: boolean?) -> string`
	
	Returns an encoded JSONB file from a given table, can output as base64 based on the `asBase64` flag, and can take a map of structs that are matched against objects.

* `decode(data: {[any]: any}, structs: {[string]: {string}}?) -> {[any]: any}`

	Returns a table from the decoded JSONB file, if any structs are declared in the file, they MUST be present in the function for the decoder to work

## Data Analysis
This data was generated on a list of 340 hat items:
![sizecomparisonchart](/res/data.png)

Raw CSV file is provided under [data/sizecomparison.csv](/data/sizecomparison.csv)

## Specification

Conventions:
* `varint` refers to LEB128
* numbers are stored in Rust convention
	* `u32` - refers to an unsigned 32 bit int
	* `i64` - refers to a signed 64 bit int
	* All numbers are little endian unless stated otherwise

A JSONB file has a basic structure:

* `6-8 bytes` - Magic Header `JSONB\0`/`SlNPTkIA`
* `varint` - Version
* `varint` - Struct Count
	* `4 bytes` - Struct Identifiers
* `varint` - String Count
	* `string` - Length Prefixed strings
* Raw Data

### Magic Header
At the beginning of every file is the magic header. This is either 6 or 8 bits depending on how the data is encoded, if it's raw binary, this header will be `JSONB\0`, otherwise it will be `SlNPTkIA`

### Version
Version is a simple `varint` denoting the version of the spec, this is used if we have to make any breaking changes to the spec. Right now, this is just `00`

### Struct Count/Struct Identifiers
Following a `varint` denoting the number of struct identifiers in the file, read the identifiers as `4 byte` strings. Structs start at index 1

### String Count/Strings
Following a `varint` denoting the number of strings, read that many `varint` length prefixed strings and map it to a table. Strings start at index 1

### Raw Data
Raw Data denotes a data chunk, some data chunks are nested, the struct of a raw data chunk will be

|Name|Type|Description|
|-|-|-|
|Type Byte|`byte`|Identifier for the type|
|Raw Data||Data decoded based on type byte|

### Type Bytes
The following is how to decode the type bytes

### Primitive Types
The first 6 types are primitive types and are easy to decode

|Byte|Name|Decode Instructions|
|-|-|-|
|`00`|`null`|Do nothing, push `null`|
|`01`|`boolean`|Push `true` if following byte is `01`, else `false`|
|`02`|`int32`|Read a `i32` and push value|
|`03`|`int64`|Read a `i64` and push value|
|`04`|`double`|Read a `double` and push value|
|`05`|`string`|Read a `varint` then push the value held in the string table at that index|

The other 3 types, which are `LIST`, `OBJECT` and `STRUCT` contain nested data and are more complex

### `06` - `LIST`
Lists have the following structs:
|Name|Type|Description|
|-|-|-|
|Sizeof|`varint`|Size of the list|
|Raw Data||sizeof list `RawData` chunks|

### `07` - `OBJECT`
Object is similar to List, however, RawData is held as a key-value pair. All keys are strings and do not have the String identifier byte.

Objects follow this struct:
|Name|Type|Description|
|-|-|-|
|Sizeof|`varint`|Size of the object|
|Raw Data||sizeof list key-value pairs of strings and `RawData` chunks|

### `08` - `STRUCT`
Struct refers to a predefined struct key map defined in `encode`/`decode`

They are similar to lists, except they have an identifier byte instead of length
|Name|Type|Description|
|-|-|-|
|Identifier|`varint`|Identifier in the struct table|
|Raw Data||`RawData`s that are read based on the shape of the struct table|

## Attributions
* Thanks to sleitnick for the Base64 library! Go support them!
