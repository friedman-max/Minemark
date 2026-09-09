'use strict';

// Minimal, dependency-free reader for Java Edition's big-endian NBT saves.
// It is intentionally read-only: this module never writes Minecraft files.
const fs = require('node:fs');
const zlib = require('node:zlib');

const TAG = { End: 0, Byte: 1, Short: 2, Int: 3, Long: 4, Float: 5, Double: 6, ByteArray: 7, String: 8, List: 9, Compound: 10, IntArray: 11, LongArray: 12 };

function inflate(buffer) {
  return buffer[0] === 0x1f && buffer[1] === 0x8b ? zlib.gunzipSync(buffer) : buffer;
}

class Reader {
  constructor(buffer) { this.buffer = buffer; this.offset = 0; }
  ensure(length) { if (this.offset + length > this.buffer.length) throw new Error('Unexpected end of NBT data.'); }
  byte() { this.ensure(1); return this.buffer.readInt8(this.offset++); }
  ubyte() { this.ensure(1); return this.buffer.readUInt8(this.offset++); }
  short() { this.ensure(2); const value = this.buffer.readInt16BE(this.offset); this.offset += 2; return value; }
  ushort() { this.ensure(2); const value = this.buffer.readUInt16BE(this.offset); this.offset += 2; return value; }
  int() { this.ensure(4); const value = this.buffer.readInt32BE(this.offset); this.offset += 4; return value; }
  long() { this.ensure(8); const value = this.buffer.readBigInt64BE(this.offset); this.offset += 8; return value >= BigInt(Number.MIN_SAFE_INTEGER) && value <= BigInt(Number.MAX_SAFE_INTEGER) ? Number(value) : value.toString(); }
  float() { this.ensure(4); const value = this.buffer.readFloatBE(this.offset); this.offset += 4; return value; }
  double() { this.ensure(8); const value = this.buffer.readDoubleBE(this.offset); this.offset += 8; return value; }
  string() { const length = this.ushort(); this.ensure(length); const value = this.buffer.toString('utf8', this.offset, this.offset + length); this.offset += length; return value; }
  value(type) {
    switch (type) {
      case TAG.Byte: return this.byte();
      case TAG.Short: return this.short();
      case TAG.Int: return this.int();
      case TAG.Long: return this.long();
      case TAG.Float: return this.float();
      case TAG.Double: return this.double();
      case TAG.ByteArray: { const length = this.int(); if (length < 0) throw new Error('Invalid byte array length.'); this.ensure(length); const value = Array.from(this.buffer.subarray(this.offset, this.offset + length)); this.offset += length; return value; }
      case TAG.String: return this.string();
      case TAG.List: { const childType = this.ubyte(); const length = this.int(); if (length < 0) throw new Error('Invalid list length.'); return Array.from({ length }, () => this.value(childType)); }
      case TAG.Compound: { const value = {}; while (true) { const childType = this.ubyte(); if (childType === TAG.End) return value; const name = this.string(); value[name] = this.value(childType); } }
      case TAG.IntArray: { const length = this.int(); if (length < 0) throw new Error('Invalid int array length.'); return Array.from({ length }, () => this.int()); }
      case TAG.LongArray: { const length = this.int(); if (length < 0) throw new Error('Invalid long array length.'); return Array.from({ length }, () => this.long()); }
      default: throw new Error(`Unsupported NBT tag type: ${type}`);
    }
  }
}

function parse(buffer) {
  const reader = new Reader(inflate(buffer));
  const rootType = reader.ubyte();
  if (rootType !== TAG.Compound) throw new Error('NBT root must be a compound tag.');
  reader.string(); // Root name is conventionally empty and not needed by the evaluator.
  const value = reader.value(TAG.Compound);
  if (reader.offset !== reader.buffer.length) throw new Error('Unexpected trailing NBT data.');
  return value;
}

function readFile(filePath) { return parse(fs.readFileSync(filePath)); }

module.exports = { TAG, parse, readFile };
