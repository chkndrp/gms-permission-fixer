/*
  A flashable script that grants all runtime/appops permissions to 
  google apps to fix post-OTA GMS issues.
  
  Copyright (C) 2026 chkndrp
  
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.content.pm.SigningInfo;
import android.os.Build;

import java.io.ByteArrayInputStream;
import java.lang.reflect.Method;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

public final class PackageCheck {
    private static final String PLAY_STORE = "com.android.vending";
    private static final Pattern GOOGLE_SUBJECT = Pattern.compile(
        "(?i)(?:^|,)\\s*(?:CN|O)\\s*=\\s*Google(?:\\s|,|$)");

    public static void main(String[] args) {
        try
        {
            android.os.Looper.prepareMainLooper();

            Object activityThread = Class.forName("android.app.ActivityThread")
            .getMethod("systemMain").invoke(null);
            Context context = (Context) activityThread.getClass()
            .getMethod("getSystemContext").invoke(activityThread);
            
            PackageManager packageManager = context.getPackageManager();

            List<PackageInfo> packages = packageManager.getInstalledPackages(
            PackageManager.GET_SIGNING_CERTIFICATES);
    
            for (PackageInfo packageInfo : packages)
            {
                if (packageInfo.packageName == null
                    || !packageInfo.packageName.startsWith("com.google."))
                {
                    continue;
                }
                String rejection = checkPackage(packageManager, packageInfo);
                if (rejection == null)
                {
                    System.out.println(packageInfo.packageName);
                }
                else
                {
                    System.err.println("[SKIP] " + packageInfo.packageName + ": " + rejection);
                }
            }
        }
        catch (Exception exception)
        {
            System.err.println("Package check failed: " + exception);
            System.exit(1);
        }
    }

    private static String checkPackage(
    PackageManager packageManager, PackageInfo packageInfo) {
        String packageName = packageInfo.packageName;
        try
        {
            if (packageInfo.applicationInfo == null)
            {
                return "application info unavailable";
            }
            if ((packageInfo.applicationInfo.flags & ApplicationInfo.FLAG_INSTALLED) == 0)
            {
                return "not installed for this user";
            }
            if ((packageInfo.applicationInfo.flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0)
            {
                return "debuggable application";
            }
            if (packageManager.isPackageSuspended(packageName))
            {
                return "suspended application";
            }
            int enabledState = packageManager.getApplicationEnabledSetting(packageName);
            if (enabledState == PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                    || enabledState == PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER
                    || enabledState == PackageManager.COMPONENT_ENABLED_STATE_DISABLED_UNTIL_USED)
            {
                return "disabled application";
            }

            List<Signature> signatures = getSignatures(packageInfo);
            if (signatures.isEmpty())
            {
                return "signing certificates unavailable";
            }

            CertificateFactory certificateFactory = CertificateFactory.getInstance("X.509");
            for (Signature signature : signatures)
            {
                X509Certificate certificate = (X509Certificate) certificateFactory
                .generateCertificate(new ByteArrayInputStream(signature.toByteArray()));

                String subject = certificate.getSubjectX500Principal().getName();

                if (subject.toLowerCase(Locale.ROOT).contains("debug"))
                {
                    return "debug signing certificate";
                }
                if (!GOOGLE_SUBJECT.matcher(subject).find())
                {
                    /*
                    * I know this is not safe since anyone with malicious intent can create a
                    * certificate with this subject name, but it's better than nothing for phasing
                    * out non-google apps. Google does not provide a list of trustable certificates
                    * they sign their apps with
                    */
                    return "signer subject is not google";
                }
            }

            String sourceDir = packageInfo.applicationInfo.sourceDir;

            boolean systemApp = isSystemAppPath(sourceDir)
            || (packageInfo.applicationInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0;

            if (!systemApp && !hasPlayStoreInstallSource(packageManager, packageName))
            {
                return "no play store or system app signature";
            }
            return null;
        }
        catch (Exception exception)
        {
            return "metadata check failed: " + exception.getClass().getSimpleName();
        }
    }

    private static List<Signature> getSignatures(PackageInfo packageInfo) {
        List<Signature> signatures = new ArrayList<>();
        SigningInfo signingInfo = packageInfo.signingInfo;

        if (signingInfo != null)
        {
            Signature[] current = signingInfo.getApkContentsSigners();
            Signature[] history = signingInfo.getSigningCertificateHistory();

            if (current != null)
            {
                signatures.addAll(Arrays.asList(current));
            }
            if (history != null)
            {
                signatures.addAll(Arrays.asList(history));
            }
        }
        return signatures;
    }

    private static boolean isSystemAppPath(String path) {
        return path != null && (path.matches(
            "^/(system|system_ext|product|vendor|odm|oem)(/[^/]+)*/(priv-)?app/.*")
            || path.matches("^/apex/[^/]+/(priv-)?app/.*"));
    }

    private static boolean hasPlayStoreInstallSource(
    PackageManager packageManager, String packageName) throws ReflectiveOperationException {
        if (Build.VERSION.SDK_INT >= 30)
        {
            Object sourceInfo = PackageManager.class
                    .getMethod("getInstallSourceInfo", String.class)
                    .invoke(packageManager, packageName);

            for (String getter : new String[] {
                    "getInstallingPackageName",
                    "getInitiatingPackageName",
                    "getOriginatingPackageName"
            })
            {
                Method method = sourceInfo.getClass().getMethod(getter);
                if (PLAY_STORE.equals(method.invoke(sourceInfo)))
                {
                    return true;
                }
            }
            return false;
        }
        return PLAY_STORE.equals(packageManager.getInstallerPackageName(packageName));
    }
}
