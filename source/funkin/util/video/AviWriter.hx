package funkin.util.video;

#if sys
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileSeek;

class AviWriter
{
  public static inline var HEADER_SIZE:Int = 224;
  public static inline var MAX_FILE_BYTES:Int = 1900000000;

  static inline var RIFF_SIZE_AT:Int = 4;
  static inline var AVIH_BYTES_PER_SEC_AT:Int = 36;
  static inline var AVIH_FLAGS_AT:Int = 44;
  static inline var AVIH_TOTAL_FRAMES_AT:Int = 48;
  static inline var AVIH_SUGGESTED_BUFFER_AT:Int = 60;
  static inline var STRH_LENGTH_AT:Int = 140;
  static inline var STRH_SUGGESTED_BUFFER_AT:Int = 144;
  static inline var MOVI_SIZE_AT:Int = 216;

  public var width(default, null):Int;
  public var height(default, null):Int;
  public var fps(default, null):Int;
  public var frames(default, null):Int = 0;
  public var size(get, never):Int;
  public var closed(default, null):Bool = false;

  var output:FileOutput;
  var position:Int = HEADER_SIZE;
  var offsets:Array<Int> = [];
  var sizes:Array<Int> = [];
  var largestChunk:Int = 0;

  public function new(path:String, width:Int, height:Int, fps:Int)
  {
    this.width = width;
    this.height = height;
    this.fps = fps;

    output = File.write(path, true);
    output.write(buildHeader());
  }

  function get_size():Int
  {
    return position;
  }

  public function wouldFit(chunkBytes:Int):Bool
  {
    return position + chunkBytes + 16 * (frames + 2) + 8 < MAX_FILE_BYTES;
  }

  public function addFrame(jpeg:Bytes):Void
  {
    if (closed) return;

    var length:Int = jpeg.length;

    offsets.push(position - HEADER_SIZE + 4);
    sizes.push(length);

    output.writeString('00dc');
    output.writeInt32(length);
    output.write(jpeg);

    var padded:Int = length;

    if (length % 2 == 1)
    {
      output.writeByte(0);
      padded++;
    }

    position += 8 + padded;
    frames++;

    if (length > largestChunk) largestChunk = length;

    if (frames % fps == 0) checkpoint();
  }

  public function close():Void
  {
    if (closed) return;

    closed = true;

    var index:BytesOutput = new BytesOutput();

    index.writeString('idx1');
    index.writeInt32(frames * 16);

    for (i in 0...frames)
    {
      index.writeString('00dc');
      index.writeInt32(0x10);
      index.writeInt32(offsets[i]);
      index.writeInt32(sizes[i]);
    }

    output.write(index.getBytes());

    writeCounters(position + 8 + frames * 16 - 8);
    patch(AVIH_FLAGS_AT, 0x10);

    output.close();
  }

  function checkpoint():Void
  {
    writeCounters(position - 8);

    output.seek(position, FileSeek.SeekBegin);
    output.flush();
  }

  function writeCounters(riffSize:Int):Void
  {
    var moviSize:Int = position - HEADER_SIZE + 4;
    var seconds:Float = frames / fps;

    patch(RIFF_SIZE_AT, riffSize);
    patch(MOVI_SIZE_AT, moviSize);
    patch(AVIH_BYTES_PER_SEC_AT, seconds > 0 ? Std.int(moviSize / seconds) : 0);
    patch(AVIH_TOTAL_FRAMES_AT, frames);
    patch(AVIH_SUGGESTED_BUFFER_AT, largestChunk);
    patch(STRH_LENGTH_AT, frames);
    patch(STRH_SUGGESTED_BUFFER_AT, largestChunk);
  }

  function patch(at:Int, value:Int):Void
  {
    output.seek(at, FileSeek.SeekBegin);
    output.writeInt32(value);
  }

  function buildHeader():Bytes
  {
    var out:BytesOutput = new BytesOutput();

    out.writeString('RIFF');
    out.writeInt32(0);
    out.writeString('AVI ');

    out.writeString('LIST');
    out.writeInt32(192);
    out.writeString('hdrl');

    out.writeString('avih');
    out.writeInt32(56);
    out.writeInt32(Std.int(1000000 / fps));
    out.writeInt32(0);
    out.writeInt32(0);
    out.writeInt32(0);
    out.writeInt32(0);
    out.writeInt32(0);
    out.writeInt32(1);
    out.writeInt32(0);
    out.writeInt32(width);
    out.writeInt32(height);
    for (i in 0...4) out.writeInt32(0);

    out.writeString('LIST');
    out.writeInt32(116);
    out.writeString('strl');

    out.writeString('strh');
    out.writeInt32(56);
    out.writeString('vids');
    out.writeString('MJPG');
    out.writeInt32(0);
    out.writeUInt16(0);
    out.writeUInt16(0);
    out.writeInt32(0);
    out.writeInt32(1);
    out.writeInt32(fps);
    out.writeInt32(0);
    out.writeInt32(0);
    out.writeInt32(0);
    out.writeInt32(-1);
    out.writeInt32(0);
    out.writeUInt16(0);
    out.writeUInt16(0);
    out.writeUInt16(width);
    out.writeUInt16(height);

    out.writeString('strf');
    out.writeInt32(40);
    out.writeInt32(40);
    out.writeInt32(width);
    out.writeInt32(height);
    out.writeUInt16(1);
    out.writeUInt16(24);
    out.writeString('MJPG');
    out.writeInt32(width * height * 3);
    out.writeInt32(0);
    out.writeInt32(0);
    out.writeInt32(0);
    out.writeInt32(0);

    out.writeString('LIST');
    out.writeInt32(4);
    out.writeString('movi');

    return out.getBytes();
  }
}
#end
