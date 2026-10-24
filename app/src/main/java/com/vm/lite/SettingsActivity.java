package com.vm.lite;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.Toast;

public class SettingsActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        String[] items = {"显示", "网络", "应用管理", "关于本机"};

        ListView listView = new ListView(this);
        listView.setAdapter(new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, items));

        listView.setOnItemClickListener((parent, view, position, id) -> {
            switch (position) {
                case 0:
                    Toast.makeText(this, "显示设置待接入管理器", Toast.LENGTH_SHORT).show();
                    break;
                case 1:
                    Toast.makeText(this, "网络设置待接入管理器", Toast.LENGTH_SHORT).show();
                    break;
                case 2:
                    // 跳转安卓原生应用管理列表
                    startActivity(new Intent(Settings.ACTION_MANAGE_ALL_APPLICATIONS_SETTINGS));
                    break;
                case 3:
                    // 仅显示虚拟机自身信息, 不读取宿主机参数
                    new AlertDialog.Builder(this)
                        .setTitle("关于本机")
                        .setMessage("型号: " + Build.MODEL
                                + "\n系统: " + Build.VERSION.RELEASE
                                + "\nVM版本: v0.1")
                        .setPositiveButton("OK", null)
                        .show();
                    break;
            }
        });

        setContentView(listView);
    }
}
