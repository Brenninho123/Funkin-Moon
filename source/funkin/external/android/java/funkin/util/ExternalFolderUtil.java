package funkin.util;

import android.content.Intent;
import android.content.ContentResolver;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.DocumentsContract;
import android.content.pm.PackageInfo;

import java.io.File;
import java.util.List;

import org.haxe.extension.Extension;

public class ExternalFolderUtil
{
  private static final String EXTERNAL_STORAGE_PROVIDER_AUTHORITY = "com.android.externalstorage.documents";
  private static final String EXTERNAL_STORAGE_PRIMARY_ROOT = "primary";

  /**
   * A method that opens the Application's data folder for browsing through the Storage Access Framework.
   * It's highly based on some code borrowed from Material Files
   * https://github.com/zhanghai/MaterialFiles
   */
  public static void openDataFolder(int requestCode)
  {
    ::if (APP_PACKAGE != "")::
    if (Extension.mainActivity != null)
    {
        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(DocumentsContract.buildRootUri("::APP_PACKAGE::.docprovider", ""), "vnd.android.document/directory");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        Extension.mainActivity.startActivityForResult(intent, requestCode);
    }
    ::end::
  }

  /**
   * Best-effort attempt to open the device's external/shared storage root using the
   * system's built-in external storage document provider (present on essentially all
   * Android devices, no custom FileProvider setup required). This is NOT scoped to the
   * app's specific external folder the way openDataFolder() is scoped to the app's data
   * folder - it opens the general storage root, since safely deep-linking into an
   * app-specific external path would require a FileProvider this app does not define.
   * Silently does nothing if no app on the device can handle the intent.
   */
  public static void openExternalFolder(int requestCode)
  {
    if (Extension.mainActivity == null) return;

    try
    {
      Intent intent = new Intent(Intent.ACTION_VIEW);
      Uri uri = DocumentsContract.buildRootUri(EXTERNAL_STORAGE_PROVIDER_AUTHORITY, EXTERNAL_STORAGE_PRIMARY_ROOT);
      intent.setDataAndType(uri, "vnd.android.document/directory");
      intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

      if (intent.resolveActivity(Extension.mainActivity.getPackageManager()) != null)
      {
        Extension.mainActivity.startActivityForResult(intent, requestCode);
      }
    }
    catch (Exception e)
    {
      // Best-effort only; not all devices expose this provider identically.
    }
  }

  /**
   * Opens the data folder or the external folder depending on the given storage type
   * ("data" or "external"), matching the values used by Preferences.storageType.
   * Unrecognized values fall back to the data folder.
   */
  public static void openFolderForType(String storageType, int requestCode)
  {
    if ("external".equals(storageType))
    {
      openExternalFolder(requestCode);
    }
    else
    {
      openDataFolder(requestCode);
    }
  }

  /**
   * Whether the device's external storage is currently mounted and available for read/write.
   */
  public static boolean isExternalStorageAvailable()
  {
    String state = Environment.getExternalStorageState();
    return Environment.MEDIA_MOUNTED.equals(state);
  }

  /**
   * Whether the device's external storage is mounted but only available as read-only.
   */
  public static boolean isExternalStorageReadOnly()
  {
    String state = Environment.getExternalStorageState();
    return Environment.MEDIA_MOUNTED_READ_ONLY.equals(state);
  }

  /**
   * Whether the app has a usable external files directory right now.
   */
  public static boolean hasExternalFolder()
  {
    return !getExternalFolderPath().isEmpty();
  }

  /**
   * The absolute path to the app's external files directory (app-specific,
   * no storage permission required), or an empty string if unavailable.
   */
  public static String getExternalFolderPath()
  {
    if (Extension.mainActivity == null) return "";

    File externalDir = Extension.mainActivity.getExternalFilesDir(null);
    if (externalDir == null) return "";

    return externalDir.getAbsolutePath();
  }

  /**
   * Free space, in bytes, on the volume backing the external folder. 0 if unavailable.
   */
  public static long getExternalFolderFreeSpaceBytes()
  {
    String path = getExternalFolderPath();
    if (path.isEmpty()) return 0L;

    File externalDir = new File(path);
    return externalDir.getFreeSpace();
  }

  /**
   * Total space, in bytes, on the volume backing the external folder. 0 if unavailable.
   */
  public static long getExternalFolderTotalSpaceBytes()
  {
    String path = getExternalFolderPath();
    if (path.isEmpty()) return 0L;

    File externalDir = new File(path);
    return externalDir.getTotalSpace();
  }
}
