package com.vm.lite;

import android.app.Activity;
import android.os.Bundle;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.*;

public class MinimalLauncher extends Activity {
    TextView tv;

    protected void onCreate(Bundle b) {
        super.onCreate(b);
        ScrollView sv = new ScrollView(this);
        tv = new TextView(this);
        tv.setTextIsSelectable(true);
        sv.addView(tv);
        setContentView(sv);
        new Thread(new Runnable() { public void run() { start(); } }).start();
    }

    void log(final String s) {
        runOnUiThread(new Runnable() { public void run() { tv.append(s + "\n"); } });
    }

    void copyAsset(String a, File out) throws IOException {
        InputStream in = getAssets().open(a);
        FileOutputStream f = new FileOutputStream(out);
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) > 0) f.write(buf, 0, n);
        in.close(); f.close();
    }

    void start() {
        try {
            String libDir = getApplicationInfo().nativeLibraryDir;
            File lib = new File(getFilesDir(), "lib");
            lib.mkdirs();
            File elf = new File(getFilesDir(), "vm-lite.elf");
            copyAsset("vm-lite.elf", elf);

            String[] libs = getAssets().list("lib");
            for (String n : libs) copyAsset("lib/" + n, new File(lib, n));

            log("[ok] libDir=" + libDir + " libs=" + libs.length);
            log("[..] 启动 vm-lite ...\n");

            ProcessBuilder pb = new ProcessBuilder(
                libDir + "/libqemu.so",
                "-M", "virt", "-cpu", "cortex-a57",
                "-kernel", elf.getAbsolutePath(),
                "-nographic", "-m", "256M", "-serial", "stdio");
            pb.environment().put("LD_LIBRARY_PATH", libDir + ":" + lib.getAbsolutePath());
            pb.directory(getFilesDir());
            pb.redirectErrorStream(true);
            Process p = pb.start();

            BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
            String line;
            while ((line = r.readLine()) != null) log(line);
            log("\n[..] qemu 退出 code=" + p.waitFor());
        } catch (Exception e) {
            log("[ERR] " + e.toString());
        }
    }
}
