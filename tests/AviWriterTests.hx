import funkin.util.video.AviWriter;
import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;

class AviWriterTests
{
  static var checks:Int = 0;
  static var failures:Int = 0;

  static function check(name:String, condition:Bool, ?detail:String):Void
  {
    checks++;

    if (condition) return;

    failures++;
    Sys.println('FAIL: ' + name + (detail != null ? '  (' + detail + ')' : ''));
  }

  static function fourcc(bytes:Bytes, at:Int):String
  {
    return bytes.getString(at, 4);
  }

  static function fill(length:Int, value:Int):Bytes
  {
    var bytes:Bytes = Bytes.alloc(length);

    bytes.fill(0, length, value);

    return bytes;
  }

  static function main():Void
  {
    var path:String = Sys.getEnv('TEMP') != null ? Sys.getEnv('TEMP') + '/aviwriter-test.avi' : 'aviwriter-test.avi';

    Sys.println('writing');

    var writer:AviWriter = new AviWriter(path, 640, 360, 30);

    check('a new file only has the header', writer.size == AviWriter.HEADER_SIZE && writer.frames == 0);

    writer.addFrame(fill(100, 1));
    writer.addFrame(fill(51, 2));
    writer.addFrame(fill(100, 3));

    check('frames are counted', writer.frames == 3);
    check('odd chunks are padded to even sizes', writer.size == AviWriter.HEADER_SIZE + 108 + 60 + 108, Std.string(writer.size));
    check('the limit lets small files through', writer.wouldFit(1000000));
    check('the limit refuses a file that would pass 2 GB', !writer.wouldFit(1950000000));

    writer.close();
    writer.addFrame(fill(10, 4));
    check('a closed writer ignores frames', writer.frames == 3);

    Sys.println('reading back');

    var bytes:Bytes = File.getBytes(path);

    check('the file is a RIFF AVI', fourcc(bytes, 0) == 'RIFF' && fourcc(bytes, 8) == 'AVI ');
    check('the RIFF size covers the whole file', bytes.getInt32(4) == bytes.length - 8, bytes.getInt32(4) + ' vs ' + (bytes.length - 8));
    check('the header lists are in place', fourcc(bytes, 12) == 'LIST' && fourcc(bytes, 20) == 'hdrl' && fourcc(bytes, 24) == 'avih' && fourcc(bytes, 88) == 'LIST' && fourcc(bytes, 96) == 'strl');
    check('the stream is MJPEG video', fourcc(bytes, 100) == 'strh' && fourcc(bytes, 108) == 'vids' && fourcc(bytes, 112) == 'MJPG' && fourcc(bytes, 164) == 'strf' && fourcc(bytes, 188) == 'MJPG');
    check('the frame time follows the frame rate', bytes.getInt32(32) == 33333);
    check('the frame rate is stored as a rate and a scale', bytes.getInt32(128) == 1 && bytes.getInt32(132) == 30);
    check('the frame count is patched in both headers', bytes.getInt32(48) == 3 && bytes.getInt32(140) == 3);
    check('the size is patched in both headers', bytes.getInt32(56 + 4) == 100 && bytes.getInt32(36 + 12) == 3 && bytes.getInt32(64) == 640 && bytes.getInt32(68) == 360);
    check('the picture size is stored in the stream format', bytes.getInt32(176) == 640 && bytes.getInt32(180) == 360 && bytes.getUInt16(184) == 1 && bytes.getUInt16(186) == 24);
    check('the index flag is set', (bytes.getInt32(44) & 0x10) != 0);
    check('the movie list starts after the header', fourcc(bytes, 212) == 'LIST' && fourcc(bytes, 220) == 'movi');

    var moviSize:Int = bytes.getInt32(216);

    check('the movie list covers its chunks', moviSize == 4 + 108 + 60 + 108, Std.string(moviSize));

    var at:Int = 224;
    var found:Array<Int> = [];

    while (at < 224 + moviSize - 4)
    {
      var length:Int = bytes.getInt32(at + 4);

      check('chunk ' + found.length + ' is a compressed video frame', fourcc(bytes, at) == '00dc');
      found.push(length);
      at += 8 + length + (length % 2);
    }

    check('the chunks have the right sizes', found.length == 3 && found[0] == 100 && found[1] == 51 && found[2] == 100, found.join(','));
    check('the chunk data is intact', bytes.get(232) == 1 && bytes.get(224 + 108 + 8) == 2 && bytes.get(224 + 108 + 60 + 8) == 3);
    check('the index follows the chunks', fourcc(bytes, at) == 'idx1' && bytes.getInt32(at + 4) == 48, fourcc(bytes, at));

    var entry:Int = at + 8;

    check('index offsets point at the chunks', bytes.getInt32(entry + 8) == 4 && bytes.getInt32(entry + 16 + 8) == 4 + 108 && bytes.getInt32(entry + 32 + 8) == 4 + 108 + 60);
    check('index sizes match the chunks', bytes.getInt32(entry + 12) == 100 && bytes.getInt32(entry + 16 + 12) == 51 && bytes.getInt32(entry + 32 + 12) == 100);
    check('every frame is a key frame', bytes.getInt32(entry + 4) == 0x10 && bytes.getInt32(entry + 16 + 4) == 0x10);
    check('nothing follows the index', at + 8 + 48 == bytes.length);

    FileSystem.deleteFile(path);

    Sys.println('a recording that was never closed');

    var open:AviWriter = new AviWriter(path, 320, 180, 30);

    for (i in 0...75) open.addFrame(fill(40, i % 250));

    var partial:Bytes = File.getBytes(path);

    check('a checkpoint keeps the sizes right while recording', partial.getInt32(4) == AviWriter.HEADER_SIZE + 60 * 48 - 8, Std.string(partial.getInt32(4)));
    check('the frame count is the one of the last checkpoint', partial.getInt32(48) == 60 && partial.getInt32(140) == 60, Std.string(partial.getInt32(48)));
    check('the movie list matches the checkpoint', partial.getInt32(216) == 4 + 60 * 48, Std.string(partial.getInt32(216)));
    check('an unfinished file does not claim to have an index', (partial.getInt32(44) & 0x10) == 0);

    open.close();

    var closed:Bytes = File.getBytes(path);

    check('closing finishes the file with an index', closed.getInt32(48) == 75 && (closed.getInt32(44) & 0x10) != 0 && closed.getInt32(4) == closed.length - 8);

    FileSystem.deleteFile(path);

    Sys.println(failures == 0 ? '\nall ' + checks + ' checks passed' : '\n' + failures + ' of ' + checks + ' checks failed');
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
