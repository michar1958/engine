// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "FlutterStandardCodec_Internal.h"

#pragma mark - Codec for basic message channel

@implementation FlutterStandardMessageCodec {
  FlutterStandardReaderWriter* _readerWriter;
}
+ (instancetype)sharedInstance {
  static id _sharedInstance = nil;
  if (!_sharedInstance) {
    FlutterStandardReaderWriter* readerWriter =
        [[[FlutterStandardReaderWriter alloc] init] autorelease];
    _sharedInstance = [[FlutterStandardMessageCodec alloc] initWithReaderWriter:readerWriter];
  }
  return _sharedInstance;
}

+ (instancetype)codecWithReaderWriter:(FlutterStandardReaderWriter*)readerWriter {
  return [[[FlutterStandardMessageCodec alloc] initWithReaderWriter:readerWriter] autorelease];
}

- (instancetype)initWithReaderWriter:(FlutterStandardReaderWriter*)readerWriter {
  self = [super init];
  NSAssert(self, @"Super init cannot be nil");
  _readerWriter = [readerWriter retain];
  return self;
}

- (void)dealloc {
  [_readerWriter release];
  [super dealloc];
}

- (NSData*)encode:(id)message {
  if (message == nil)
    return nil;
  NSMutableData* data = [NSMutableData dataWithCapacity:32];
  FlutterStandardWriter* writer = [_readerWriter writerWithData:data];
  [writer writeValue:message];
  return data;
}

- (id)decode:(NSData*)message {
  if (message == nil)
    return nil;
  FlutterStandardReader* reader = [_readerWriter readerWithData:message];
  id value = [reader readValue];
  NSAssert(![reader hasMore], @"Corrupted standard message");
  return value;
}
@end

#pragma mark - Codec for method channel

@implementation FlutterStandardMethodCodec {
  FlutterStandardReaderWriter* _readerWriter;
}
+ (instancetype)sharedInstance {
  static id _sharedInstance = nil;
  if (!_sharedInstance) {
    FlutterStandardReaderWriter* readerWriter =
        [[[FlutterStandardReaderWriter alloc] init] autorelease];
    _sharedInstance = [[FlutterStandardMethodCodec alloc] initWithReaderWriter:readerWriter];
  }
  return _sharedInstance;
}

+ (instancetype)codecWithReaderWriter:(FlutterStandardReaderWriter*)readerWriter {
  return [[[FlutterStandardMethodCodec alloc] initWithReaderWriter:readerWriter] autorelease];
}

- (instancetype)initWithReaderWriter:(FlutterStandardReaderWriter*)readerWriter {
  self = [super init];
  NSAssert(self, @"Super init cannot be nil");
  _readerWriter = [readerWriter retain];
  return self;
}

- (void)dealloc {
  [_readerWriter release];
  [super dealloc];
}

- (NSData*)encodeMethodCall:(FlutterMethodCall*)call {
  NSMutableData* data = [NSMutableData dataWithCapacity:32];
  FlutterStandardWriter* writer = [_readerWriter writerWithData:data];
  [writer writeValue:call.method];
  [writer writeValue:call.arguments];
  return data;
}

- (NSData*)encodeSuccessEnvelope:(id)result {
  NSMutableData* data = [NSMutableData dataWithCapacity:32];
  FlutterStandardWriter* writer = [_readerWriter writerWithData:data];
  [writer writeByte:0];
  [writer writeValue:result];
  return data;
}

- (NSData*)encodeErrorEnvelope:(FlutterError*)error {
  NSMutableData* data = [NSMutableData dataWithCapacity:32];
  FlutterStandardWriter* writer = [_readerWriter writerWithData:data];
  [writer writeByte:1];
  [writer writeValue:error.code];
  [writer writeValue:error.message];
  [writer writeValue:error.details];
  return data;
}

- (FlutterMethodCall*)decodeMethodCall:(NSData*)message {
  FlutterStandardReader* reader = [_readerWriter readerWithData:message];
  id value1 = [reader readValue];
  id value2 = [reader readValue];
  NSAssert(![reader hasMore], @"Corrupted standard method call");
  NSAssert([value1 isKindOfClass:[NSString class]], @"Corrupted standard method call");
  return [FlutterMethodCall methodCallWithMethodName:value1 arguments:value2];
}

- (id)decodeEnvelope:(NSData*)envelope {
  FlutterStandardReader* reader = [_readerWriter readerWithData:envelope];
  UInt8 flag = [reader readByte];
  NSAssert(flag <= 1, @"Corrupted standard envelope");
  id result;
  switch (flag) {
    case 0: {
      result = [reader readValue];
      NSAssert(![reader hasMore], @"Corrupted standard envelope");
    } break;
    case 1: {
      id code = [reader readValue];
      id message = [reader readValue];
      id details = [reader readValue];
      NSAssert(![reader hasMore], @"Corrupted standard envelope");
      NSAssert([code isKindOfClass:[NSString class]], @"Invalid standard envelope");
      NSAssert(message == nil || [message isKindOfClass:[NSString class]],
               @"Invalid standard envelope");
      result = [FlutterError errorWithCode:code message:message details:details];
    } break;
  }
  return result;
}
@end

using namespace shell;

#pragma mark - Standard serializable types

@implementation FlutterStandardTypedData
+ (instancetype)typedDataWithBytes:(NSData*)data {
  return [FlutterStandardTypedData typedDataWithData:data type:FlutterStandardDataTypeUInt8];
}

+ (instancetype)typedDataWithInt32:(NSData*)data {
  return [FlutterStandardTypedData typedDataWithData:data type:FlutterStandardDataTypeInt32];
}

+ (instancetype)typedDataWithInt64:(NSData*)data {
  return [FlutterStandardTypedData typedDataWithData:data type:FlutterStandardDataTypeInt64];
}

+ (instancetype)typedDataWithFloat64:(NSData*)data {
  return [FlutterStandardTypedData typedDataWithData:data type:FlutterStandardDataTypeFloat64];
}

+ (instancetype)typedDataWithData:(NSData*)data type:(FlutterStandardDataType)type {
  return [[[FlutterStandardTypedData alloc] initWithData:data type:type] autorelease];
}

- (instancetype)initWithData:(NSData*)data type:(FlutterStandardDataType)type {
  UInt8 elementSize = elementSizeForFlutterStandardDataType(type);
  NSAssert(data, @"Data cannot be nil");
  NSAssert(data.length % elementSize == 0, @"Data must contain integral number of elements");
  self = [super init];
  NSAssert(self, @"Super init cannot be nil");
  _data = [data retain];
  _type = type;
  _elementSize = elementSize;
  _elementCount = data.length / elementSize;
  return self;
}

- (void)dealloc {
  [_data release];
  [super dealloc];
}

- (BOOL)isEqual:(id)object {
  if (self == object)
    return YES;
  if (![object isKindOfClass:[FlutterStandardTypedData class]])
    return NO;
  FlutterStandardTypedData* other = (FlutterStandardTypedData*)object;
  return self.type == other.type && self.elementCount == other.elementCount &&
         [self.data isEqual:other.data];
}

- (NSUInteger)hash {
  return [self.data hash] ^ self.type;
}
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation FlutterStandardBigInteger
+ (instancetype)bigIntegerWithHex:(NSString*)hex {
  return [[[FlutterStandardBigInteger alloc] initWithHex:hex] autorelease];
}

- (instancetype)initWithHex:(NSString*)hex {
  NSAssert(hex, @"Hex cannot be nil");
  self = [super init];
  NSAssert(self, @"Super init cannot be nil");
  _hex = [hex retain];
  return self;
}

- (void)dealloc {
  [_hex release];
  [super dealloc];
}

- (BOOL)isEqual:(id)object {
  if (self == object)
    return YES;
  if (![object isKindOfClass:[FlutterStandardBigInteger class]])
    return NO;
  FlutterStandardBigInteger* other = (FlutterStandardBigInteger*)object;
  return [self.hex isEqual:other.hex];
}

- (NSUInteger)hash {
  return [self.hex hash];
}
@end

#pragma mark - Writer and reader of standard codec

@implementation FlutterStandardWriter {
  NSMutableData* _data;
}

- (instancetype)initWithData:(NSMutableData*)data {
  self = [super init];
  NSAssert(self, @"Super init cannot be nil");
  _data = [data retain];
  return self;
}

- (void)dealloc {
  [_data release];
  [super dealloc];
}

- (void)writeByte:(UInt8)value {
  [_data appendBytes:&value length:1];
}

- (void)writeBytes:(const void*)bytes length:(NSUInteger)length {
  [_data appendBytes:bytes length:length];
}

- (void)writeData:(NSData*)data {
  [_data appendData:data];
}

- (void)writeSize:(UInt32)size {
  if (size < 254) {
    [self writeByte:(UInt8)size];
  } else if (size <= 0xffff) {
    [self writeByte:254];
    UInt16 value = (UInt16)size;
    [self writeBytes:&value length:2];
  } else {
    [self writeByte:255];
    [self writeBytes:&size length:4];
  }
}

- (void)writeAlignment:(UInt8)alignment {
  UInt8 mod = _data.length % alignment;
  if (mod) {
    for (int i = 0; i < (alignment - mod); i++) {
      [self writeByte:0];
    }
  }
}

- (void)writeUTF8:(NSString*)value {
  UInt32 length = [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
  [self writeSize:length];
  [self writeBytes:value.UTF8String length:length];
}

- (void)writeValue:(id)value {
  if (value == nil || value == [NSNull null]) {
    [self writeByte:FlutterStandardFieldNil];
  } else if ([value isKindOfClass:[NSNumber class]]) {
    NSNumber* number = value;
    const char* type = [number objCType];
    if ([self isBool:number type:type]) {
      BOOL b = number.boolValue;
      [self writeByte:(b ? FlutterStandardFieldTrue : FlutterStandardFieldFalse)];
    } else if (strcmp(type, @encode(signed int)) == 0 || strcmp(type, @encode(signed short)) == 0 ||
               strcmp(type, @encode(unsigned short)) == 0 ||
               strcmp(type, @encode(signed char)) == 0 ||
               strcmp(type, @encode(unsigned char)) == 0) {
      SInt32 n = number.intValue;
      [self writeByte:FlutterStandardFieldInt32];
      [self writeBytes:(UInt8*)&n length:4];
    } else if (strcmp(type, @encode(signed long)) == 0 ||
               strcmp(type, @encode(unsigned int)) == 0) {
      SInt64 n = number.longValue;
      [self writeByte:FlutterStandardFieldInt64];
      [self writeBytes:(UInt8*)&n length:8];
    } else if (strcmp(type, @encode(double)) == 0 || strcmp(type, @encode(float)) == 0) {
      Float64 f = number.doubleValue;
      [self writeByte:FlutterStandardFieldFloat64];
      [self writeAlignment:8];
      [self writeBytes:(UInt8*)&f length:8];
    } else if (strcmp(type, @encode(unsigned long)) == 0 ||
               strcmp(type, @encode(signed long long)) == 0 ||
               strcmp(type, @encode(unsigned long long)) == 0) {
      NSString* hex = [NSString stringWithFormat:@"%llx", number.unsignedLongLongValue];
      [self writeByte:FlutterStandardFieldIntHex];
      [self writeUTF8:hex];
    } else {
      NSLog(@"Unsupported value: %@ of type %s", value, type);
      NSAssert(NO, @"Unsupported value for standard codec");
    }
  } else if ([value isKindOfClass:[NSString class]]) {
    NSString* string = value;
    [self writeByte:FlutterStandardFieldString];
    [self writeUTF8:string];
  } else if ([value isKindOfClass:[FlutterStandardBigInteger class]]) {
    FlutterStandardBigInteger* bigInt = value;
    [self writeByte:FlutterStandardFieldIntHex];
    [self writeUTF8:bigInt.hex];
  } else if ([value isKindOfClass:[FlutterStandardTypedData class]]) {
    FlutterStandardTypedData* typedData = value;
    [self writeByte:FlutterStandardFieldForDataType(typedData.type)];
    [self writeSize:typedData.elementCount];
    [self writeAlignment:typedData.elementSize];
    [self writeData:typedData.data];
  } else if ([value isKindOfClass:[NSArray class]]) {
    NSArray* array = value;
    [self writeByte:FlutterStandardFieldList];
    [self writeSize:array.count];
    for (id object in array) {
      [self writeValue:object];
    }
  } else if ([value isKindOfClass:[NSDictionary class]]) {
    NSDictionary* dict = value;
    [self writeByte:FlutterStandardFieldMap];
    [self writeSize:dict.count];
    for (id key in dict) {
      [self writeValue:key];
      [self writeValue:[dict objectForKey:key]];
    }
  } else {
    NSLog(@"Unsupported value: %@ of type %@", value, [value class]);
    NSAssert(NO, @"Unsupported value for standard codec");
  }
}

- (BOOL)isBool:(NSNumber*)number type:(const char*)type {
  return strcmp(type, @encode(signed char)) == 0 &&
         [NSStringFromClass([number class]) isEqual:@"__NSCFBoolean"];
}
@end

@implementation FlutterStandardReader {
  NSData* _data;
  NSRange _range;
}

- (instancetype)initWithData:(NSData*)data {
  self = [super init];
  NSAssert(self, @"Super init cannot be nil");
  _data = [data retain];
  _range = NSMakeRange(0, 0);
  return self;
}

- (void)dealloc {
  [_data release];
  [super dealloc];
}

- (BOOL)hasMore {
  return _range.location < _data.length;
}

- (void)readBytes:(void*)destination length:(NSUInteger)length {
  _range.length = length;
  [_data getBytes:destination range:_range];
  _range.location += _range.length;
}

- (UInt8)readByte {
  UInt8 value;
  [self readBytes:&value length:1];
  return value;
}

- (UInt32)readSize {
  UInt8 byte = [self readByte];
  if (byte < 254) {
    return (UInt32)byte;
  } else if (byte == 254) {
    UInt16 value;
    [self readBytes:&value length:2];
    return value;
  } else {
    UInt32 value;
    [self readBytes:&value length:4];
    return value;
  }
}

- (NSData*)readData:(NSUInteger)length {
  _range.length = length;
  NSData* data = [_data subdataWithRange:_range];
  _range.location += _range.length;
  return data;
}

- (NSString*)readUTF8 {
  NSData* bytes = [self readData:[self readSize]];
  return [[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] autorelease];
}

- (void)readAlignment:(UInt8)alignment {
  UInt8 mod = _range.location % alignment;
  if (mod) {
    _range.location += (alignment - mod);
  }
}

- (FlutterStandardTypedData*)readTypedDataOfType:(FlutterStandardDataType)type {
  UInt32 elementCount = [self readSize];
  UInt8 elementSize = elementSizeForFlutterStandardDataType(type);
  [self readAlignment:elementSize];
  NSData* data = [self readData:elementCount * elementSize];
  return [FlutterStandardTypedData typedDataWithData:data type:type];
}

- (id)readValue {
  return [self readValueOfType:[self readByte]];
}

- (id)readValueOfType:(UInt8)type {
  FlutterStandardField field = (FlutterStandardField)type;
  switch (field) {
    case FlutterStandardFieldNil:
      return nil;
    case FlutterStandardFieldTrue:
      return @YES;
    case FlutterStandardFieldFalse:
      return @NO;
    case FlutterStandardFieldInt32: {
      SInt32 value;
      [self readBytes:&value length:4];
      return [NSNumber numberWithInt:value];
    }
    case FlutterStandardFieldInt64: {
      SInt64 value;
      [self readBytes:&value length:8];
      return [NSNumber numberWithLong:value];
    }
    case FlutterStandardFieldFloat64: {
      Float64 value;
      [self readAlignment:8];
      [self readBytes:&value length:8];
      return [NSNumber numberWithDouble:value];
    }
    case FlutterStandardFieldIntHex:
      return [FlutterStandardBigInteger bigIntegerWithHex:[self readUTF8]];
    case FlutterStandardFieldString:
      return [self readUTF8];
    case FlutterStandardFieldUInt8Data:
    case FlutterStandardFieldInt32Data:
    case FlutterStandardFieldInt64Data:
    case FlutterStandardFieldFloat64Data:
      return [self readTypedDataOfType:FlutterStandardDataTypeForField(field)];
    case FlutterStandardFieldList: {
      UInt32 length = [self readSize];
      NSMutableArray* array = [NSMutableArray arrayWithCapacity:length];
      for (UInt32 i = 0; i < length; i++) {
        id value = [self readValue];
        [array addObject:(value == nil ? [NSNull null] : value)];
      }
      return array;
    }
    case FlutterStandardFieldMap: {
      UInt32 size = [self readSize];
      NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:size];
      for (UInt32 i = 0; i < size; i++) {
        id key = [self readValue];
        id val = [self readValue];
        [dict setObject:(val == nil ? [NSNull null] : val)
                 forKey:(key == nil ? [NSNull null] : key)];
      }
      return dict;
    }
    default:
      NSAssert(NO, @"Corrupted standard message");
  }
}
@end

@implementation FlutterStandardReaderWriter
- (FlutterStandardWriter*)writerWithData:(NSMutableData*)data {
  return [[[FlutterStandardWriter alloc] initWithData:data] autorelease];
}

- (FlutterStandardReader*)readerWithData:(NSData*)data {
  return [[[FlutterStandardReader alloc] initWithData:data] autorelease];
}
@end
#pragma clang diagnostic pop
