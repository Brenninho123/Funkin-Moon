package funkin.multiplayer;

typedef ModManifestEntry =
{
	id:String,
	name:String,
	version:String,
	hash:String,
	required:Bool
}

typedef VersionMismatch =
{
	modId:String,
	modName:String,
	hostVersion:String,
	clientVersion:String
}

typedef ModCompatibilityResult =
{
	compatible:Bool,
	missingOnClient:Array<ModManifestEntry>,
	missingOnHost:Array<ModManifestEntry>,
	versionMismatches:Array<VersionMismatch>,
	hashMismatches:Array<VersionMismatch>
}

class MultiplayerModding
{
	public static var localManifest:Array<ModManifestEntry> = [];

	public static function buildLocalManifest(modsFolder:String = 'mods'):Array<ModManifestEntry>
	{
		var result:Array<ModManifestEntry> = [];

		#if sys
		if (!sys.FileSystem.exists(modsFolder) || !sys.FileSystem.isDirectory(modsFolder))
		{
			localManifest = result;
			return result;
		}

		var entries:Array<String> = sys.FileSystem.readDirectory(modsFolder);

		for (entry in entries)
		{
			var modPath:String = haxe.io.Path.join([modsFolder, entry]);
			if (!sys.FileSystem.isDirectory(modPath)) continue;

			var metaPath:String = haxe.io.Path.join([modPath, 'pack.json']);
			if (!sys.FileSystem.exists(metaPath)) continue;

			var meta:Dynamic;
			try
			{
				meta = haxe.Json.parse(sys.io.File.getContent(metaPath));
			}
			catch (e:Dynamic)
			{
				continue;
			}

			var modId:String = (meta.id != null) ? meta.id : entry;
			var modName:String = (meta.name != null) ? meta.name : entry;
			var modVersion:String = (meta.version != null) ? meta.version : '1.0.0';
			var required:Bool = (meta.required != null) ? meta.required : true;

			result.push({
				id: modId,
				name: modName,
				version: modVersion,
				hash: hashModFolder(modPath),
				required: required
			});
		}
		#end

		localManifest = result;
		return result;
	}

	static function hashModFolder(modPath:String):String
	{
		#if sys
		var relevantFiles:Array<String> = [];
		collectHashableFiles(modPath, relevantFiles);
		relevantFiles.sort(Reflect.compare);

		var combined:StringBuf = new StringBuf();
		for (file in relevantFiles)
		{
			try
			{
				combined.add(sys.io.File.getContent(file));
			}
			catch (e:Dynamic) {}
		}

		return haxe.crypto.Md5.encode(combined.toString());
		#else
		return '';
		#end
	}

	#if sys
	static function collectHashableFiles(dir:String, output:Array<String>):Void
	{
		var entries:Array<String> = sys.FileSystem.readDirectory(dir);

		for (entry in entries)
		{
			var fullPath:String = haxe.io.Path.join([dir, entry]);

			if (sys.FileSystem.isDirectory(fullPath))
			{
				collectHashableFiles(fullPath, output);
			}
			else
			{
				var ext:String = haxe.io.Path.extension(fullPath).toLowerCase();
				if (ext == 'hscript' || ext == 'lua' || ext == 'json' || ext == 'hx' || ext == 'lx')
				{
					output.push(fullPath);
				}
			}
		}
	}
	#end

	public static function serializeManifest(manifest:Array<ModManifestEntry>):String
	{
		return haxe.Json.stringify(manifest);
	}

	public static function deserializeManifest(data:String):Array<ModManifestEntry>
	{
		try
		{
			var parsed:Array<ModManifestEntry> = haxe.Json.parse(data);
			return (parsed != null) ? parsed : [];
		}
		catch (e:Dynamic)
		{
			return [];
		}
	}

	public static function compareManifests(hostManifest:Array<ModManifestEntry>, clientManifest:Array<ModManifestEntry>):ModCompatibilityResult
	{
		var missingOnClient:Array<ModManifestEntry> = [];
		var missingOnHost:Array<ModManifestEntry> = [];
		var versionMismatches:Array<VersionMismatch> = [];
		var hashMismatches:Array<VersionMismatch> = [];

		var clientById:Map<String, ModManifestEntry> = new Map();
		for (entry in clientManifest) clientById.set(entry.id, entry);

		var hostById:Map<String, ModManifestEntry> = new Map();
		for (entry in hostManifest) hostById.set(entry.id, entry);

		for (hostEntry in hostManifest)
		{
			if (!hostEntry.required) continue;

			var clientEntry:Null<ModManifestEntry> = clientById.get(hostEntry.id);

			if (clientEntry == null)
			{
				missingOnClient.push(hostEntry);
				continue;
			}

			if (clientEntry.version != hostEntry.version)
			{
				versionMismatches.push({
					modId: hostEntry.id,
					modName: hostEntry.name,
					hostVersion: hostEntry.version,
					clientVersion: clientEntry.version
				});
			}
			else if (clientEntry.hash != hostEntry.hash)
			{
				hashMismatches.push({
					modId: hostEntry.id,
					modName: hostEntry.name,
					hostVersion: hostEntry.version,
					clientVersion: clientEntry.version
				});
			}
		}

		for (clientEntry in clientManifest)
		{
			if (!clientEntry.required) continue;
			if (!hostById.exists(clientEntry.id)) missingOnHost.push(clientEntry);
		}

		var compatible:Bool = missingOnClient.length == 0
			&& missingOnHost.length == 0
			&& versionMismatches.length == 0
			&& hashMismatches.length == 0;

		return {
			compatible: compatible,
			missingOnClient: missingOnClient,
			missingOnHost: missingOnHost,
			versionMismatches: versionMismatches,
			hashMismatches: hashMismatches
		};
	}

	public static function generateReportMessage(result:ModCompatibilityResult):String
	{
		if (result.compatible) return 'All mods are compatible.';

		var lines:Array<String> = [];

		for (entry in result.missingOnClient) lines.push('Missing on client: ${entry.name} (${entry.version})');
		for (entry in result.missingOnHost) lines.push('Missing on host: ${entry.name} (${entry.version})');
		for (mismatch in result.versionMismatches) lines.push('Version mismatch for ${mismatch.modName}: host=${mismatch.hostVersion}, client=${mismatch.clientVersion}');
		for (mismatch in result.hashMismatches) lines.push('Content mismatch for ${mismatch.modName} despite matching version ${mismatch.hostVersion}');

		return lines.join('\n');
	}
}
