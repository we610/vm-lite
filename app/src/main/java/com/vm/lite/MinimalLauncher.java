package com.vm.lite;

import android.app.Activity;
import android.content.res.AssetFileDescriptor;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.*;

public class MinimalLauncher extends Activity {
    TextView tv; ProgressBar pb; Handler h = new Handler();

    protected void onCreate(Bundle b) {
        super.onCreate(b);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.BLACK);
        pb = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        pb.setMax(100); pb.setPadding(16, 8, 16, 8);
        root.addView(pb);
        ScrollView sv = new ScrollView(this);
        tv = new TextView(this); tv.setTextColor(Color.GREEN);
        tv.setTextSize(12); tv.setTextIsSelectable(true); tv.setPadding(16,8,16,16);
        sv.addView(tv); root.addView(sv);
        setContentView(root);
        log("[..] vm-lite 已启动，自检中...");
        new Thread(new Runnable(){ public void run(){ start(); } }).start();
    }

    void log(final String s){ h.post(new Runnable(){ public void run(){ tv.append(s+"\n"); } }); }
    void stat(final String s, final int p){
        h.post(new Runnable(){ public void run(){ tv.append(s+"\n"); pb.setProgress(p); } });
    }

    long assetLen(String n){
        try { AssetFileDescriptor afd = getAssets().openFd(n);
              long l = afd.getLength(); afd.close(); return l; }
        catch(Exception e){ return -1; }
    }

    void start(){
        String libDir = getApplicationInfo().nativeLibraryDir;
        File lib = new File(getFilesDir(), "lib"); lib.mkdirs();
        File qemu = new File(libDir, "libqemu.so");
        File elf  = new File(getFilesDir(), "vm-lite.elf");

        stat("[..] qemu: " + qemu.getAbsolutePath(), 2);
        stat("[..] qemu 存在: " + qemu.exists(), 4);
        stat("[..] 内核: " + elf.getAbsolutePath(), 6);
        stat("[..] 内核存在: " + elf.exists() +
             (elf.exists() ? " ("+elf.length()/1024+"KB)" : ""), 8);
        if(!elf.exists()){ stat("[!!] 内核缺失，无法启动", 0); return; }

        try {
            String[] libs = getAssets().list("lib");
            if(libs != null && libs.length > 0){
                long total = 0;
                for(String n : libs){ long l = assetLen("lib/"+n); total += (l>0?l:0); }
                stat("[..] 解压 " + libs.length + " 个库，共 " +
                     (total/1048576) + "MB，请稍候...", 10);
                long done = 0;
                for(int i=0;i<libs.length;i++){
                    InputStream in = getAssets().open("lib/"+libs[i]);
                    File dst = new File(lib, libs[i]);
                    if(dst.exists() && dst.length()>0){ in.close(); done += dst.length(); continue; }
                    FileOutputStream f = new FileOutputStream(dst);
                    byte[] buf = new byte[65536]; int n;
                    while((n=in.read(buf))>0){ f.write(buf,0,n); done += n; }
                    in.close(); f.close();
                    dst.setExecutable(true, false);   // 关键：补可执行位
                    if(total>0) stat("    解压中… " + (done/1048576) + "/" +
                                     (total/1048576) + "MB", 10 + (int)(80L*done/total));
                }
            }
            stat("[ok] 环境就绪，启动 qemu ...", 92);

            ProcessBuilder pbd = new ProcessBuilder(
                qemu.getAbsolutePath(), "-M","virt","-cpu","cortex-a57",
                "-kernel", elf.getAbsolutePath(),
                "-nographic","-m","256M","-serial","stdio");
            pbd.environment().put("LD_LIBRARY_PATH", libDir + ":" + lib.getAbsolutePath());
            pbd.directory(getFilesDir()); pbd.redirectErrorStream(true);
            Process p = pbd.start();

            BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
            String line; while((line=r.readLine())!=null) log(line);
            log("[..] qemu 退出 code=" + p.waitFor());
        } catch(Exception e){ log("[ERR] " + e.toString()); }
    }
}
