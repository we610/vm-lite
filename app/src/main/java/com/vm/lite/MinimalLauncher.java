package com.vm.lite;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

/**
 * 极简 Launcher（替代 AOSP Launcher3）
 * 仅以网格列出「设置」「浏览器」「MT管理器」三个入口，点击直接启动。
 * 浏览器改为调用系统自带浏览器（com.android.browser），不再自研 WebView 版本。
 * 不提供：桌面小部件、文件夹、图标拖拽排序、桌面搜索、动态壁纸、图标动画与过渡特效。
 * 图标以纯色方块代替，避免图标包解析与资源加载开销。
 */
public class MinimalLauncher extends Activity {

    private static final String[] LABELS = {"设置", "浏览器", "MT管理器"};
    // 系统自带浏览器（AOSP Browser2）包名
    private static final String BROWSER_PKG = "com.android.browser";
    // MT 管理器常见包名，如预置版本包名不同请在此修改
    private static final String MT_PKG = "bin.mt.plus";
    private static final int[] ICON_COLORS = {0xFF4A90D9, 0xFF2E7D32, 0xFFF5A623};

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        GridView grid = new GridView(this);
        grid.setNumColumns(3);
        grid.setBackgroundColor(Color.BLACK);
        grid.setAdapter(new BaseAdapter() {
            @Override public int getCount() { return LABELS.length; }
            @Override public Object getItem(int position) { return LABELS[position]; }
            @Override public long getItemId(int position) { return position; }

            @Override
            public View getView(int position, View convertView, ViewGroup parent) {
                LinearLayout item = new LinearLayout(MinimalLauncher.this);
                item.setOrientation(LinearLayout.VERTICAL);
                item.setGravity(Gravity.CENTER_HORIZONTAL);
                item.setPadding(16, 24, 16, 24);

                ImageView icon = new ImageView(MinimalLauncher.this);
                icon.setBackgroundColor(ICON_COLORS[position]);
                icon.setLayoutParams(new LinearLayout.LayoutParams(96, 96));

                TextView label = new TextView(MinimalLauncher.this);
                label.setText(LABELS[position]);
                label.setTextColor(Color.WHITE);
                label.setTextSize(14);
                label.setPadding(0, 12, 0, 0);

                item.addView(icon);
                item.addView(label);
                return item;
            }
        });

        grid.setOnItemClickListener((parent, view, position, id) -> {
            switch (position) {
                case 0:
                    startActivity(new Intent(MinimalLauncher.this, SettingsActivity.class));
                    break;
                case 1:
                    launchBrowser();
                    break;
                case 2:
                    launchMtManager();
                    break;
            }
        });

        setContentView(grid);
    }

    private void launchBrowser() {
        Intent intent = getPackageManager().getLaunchIntentForPackage(BROWSER_PKG);
        if (intent != null) {
            startActivity(intent);
        } else {
            Toast.makeText(this, "未找到系统自带浏览器", Toast.LENGTH_SHORT).show();
        }
    }

    private void launchMtManager() {
        Intent intent = getPackageManager().getLaunchIntentForPackage(MT_PKG);
        if (intent != null) {
            startActivity(intent);
        } else {
            Toast.makeText(this, "MT管理器未安装", Toast.LENGTH_SHORT).show();
        }
    }
}
