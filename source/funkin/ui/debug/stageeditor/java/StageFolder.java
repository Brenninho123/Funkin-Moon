package funkin.ui.debug.stageeditor;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Intent;
import android.net.Uri;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

import org.haxe.lime.HaxeObject;
import org.haxe.extension.Extension;

public class StageFolder extends Extension
{
	private static final int REQUEST_CODE_IMPORT = 47001;
	private static final int REQUEST_CODE_EXPORT = 47002;

	private static HaxeObject callback;
	private static byte[] pendingExportBytes;

	public static void setCallback(HaxeObject value)
	{
		callback = value;
	}

	public static void importStage()
	{
		Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
		intent.addCategory(Intent.CATEGORY_OPENABLE);
		intent.setType("application/octet-stream");
		Extension.mainActivity.startActivityForResult(intent, REQUEST_CODE_IMPORT);
	}

	public static void exportStage(String fileName, byte[] bytes)
	{
		pendingExportBytes = bytes;

		Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
		intent.addCategory(Intent.CATEGORY_OPENABLE);
		intent.setType("application/octet-stream");
		intent.putExtra(Intent.EXTRA_TITLE, fileName);
		Extension.mainActivity.startActivityForResult(intent, REQUEST_CODE_EXPORT);
	}

	@Override
	public boolean onActivityResult(int requestCode, int resultCode, Intent data)
	{
		if (requestCode == REQUEST_CODE_IMPORT)
		{
			if (resultCode == Activity.RESULT_OK && data != null && data.getData() != null)
			{
				handleImportResult(data.getData());
			}
			else if (callback != null)
			{
				callback.call("onImportCancelled", null);
			}
			return true;
		}

		if (requestCode == REQUEST_CODE_EXPORT)
		{
			if (resultCode == Activity.RESULT_OK && data != null && data.getData() != null)
			{
				handleExportResult(data.getData());
			}
			else if (callback != null)
			{
				callback.call("onExportCancelled", null);
			}
			pendingExportBytes = null;
			return true;
		}

		return false;
	}

	private static void handleImportResult(Uri uri)
	{
		try
		{
			ContentResolver resolver = Extension.mainActivity.getContentResolver();
			InputStream input = resolver.openInputStream(uri);
			ByteArrayOutputStream output = new ByteArrayOutputStream();
			byte[] buffer = new byte[8192];
			int read;
			while ((read = input.read(buffer)) != -1)
			{
				output.write(buffer, 0, read);
			}
			input.close();

			if (callback != null)
			{
				callback.call("onImportComplete", new Object[] { output.toByteArray() });
			}
		}
		catch (Exception e)
		{
			if (callback != null)
			{
				callback.call("onImportError", new Object[] { e.getMessage() });
			}
		}
	}

	private static void handleExportResult(Uri uri)
	{
		if (pendingExportBytes == null)
		{
			if (callback != null)
			{
				callback.call("onExportError", new Object[] { "No pending data to export" });
			}
			return;
		}

		try
		{
			ContentResolver resolver = Extension.mainActivity.getContentResolver();
			OutputStream output = resolver.openOutputStream(uri);
			output.write(pendingExportBytes);
			output.close();

			if (callback != null)
			{
				callback.call("onExportComplete", new Object[] { uri.toString() });
			}
		}
		catch (Exception e)
		{
			if (callback != null)
			{
				callback.call("onExportError", new Object[] { e.getMessage() });
			}
		}
	}
}
