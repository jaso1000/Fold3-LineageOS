package org.fold3.dolby;

import android.app.Application;
import android.content.SharedPreferences;
import android.media.AudioSystem;
import android.media.audiofx.AudioEffect;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.util.UUID;

/**
 * Holds Samsung's Dolby Atmos effect (DAX3 in vendor libswdap, behind the effect proxy) on the
 * global output mix while the setting is on. The app is persistent, so the effect lives as long
 * as the setting is on; it is re-created if audioserver restarts. Off by default, like One UI.
 */
public class DolbyApp extends Application {
    private static final String TAG = "Fold3Dolby";
    private static final UUID EFFECT_DAP = UUID.fromString("9d4921da-8225-4f29-aefa-39537a04bcaa");
    private static final int PRIORITY = 100;
    private static final String KEY_ON = "dolby_on";

    // Parameter layout of Dolby's DAP effect (as in the DolbyAudioEffect class LineageOS device
    // trees use): setParameter(CPDP_VALUES, {param, count = 1, value}).
    private static final int PARAM_ENABLE = 0;
    private static final int PARAM_CPDP_VALUES = 5;

    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private SharedPreferences mPrefs;
    private AudioEffect mEffect;

    @Override
    public void onCreate() {
        super.onCreate();
        mPrefs = getSharedPreferences("dolby", MODE_PRIVATE);
        AudioSystem.setErrorCallback(error -> mHandler.post(() -> onAudioServerStatus(error)));
        apply();
    }

    public boolean isOn() {
        return mPrefs.getBoolean(KEY_ON, false);
    }

    public void setOn(boolean on) {
        mPrefs.edit().putBoolean(KEY_ON, on).apply();
        apply();
    }

    private void onAudioServerStatus(int status) {
        if (status != AudioSystem.AUDIO_STATUS_SERVER_DIED) return;
        Log.i(TAG, "audioserver died, re-creating the effect when it is back");
        mEffect = null; // its native side is gone with audioserver
        waitForAudioServer(30);
    }

    private void waitForAudioServer(int tries) {
        if (AudioSystem.checkAudioFlinger() == AudioSystem.AUDIO_STATUS_OK) {
            apply();
        } else if (tries > 0) {
            mHandler.postDelayed(() -> waitForAudioServer(tries - 1), 1000);
        }
    }

    private void apply() {
        boolean on = isOn();
        if (on && mEffect == null) {
            try {
                mEffect = new AudioEffect(AudioEffect.EFFECT_TYPE_NULL, EFFECT_DAP, PRIORITY, 0);
            } catch (RuntimeException e) {
                Log.w(TAG, "Dolby effect unavailable", e);
                return;
            }
        }
        if (mEffect == null) return;
        try {
            byte[] buf = new byte[12];
            put(buf, 0, PARAM_ENABLE);
            put(buf, 4, 1);
            put(buf, 8, on ? 1 : 0);
            mEffect.setParameter(PARAM_CPDP_VALUES, buf);
            mEffect.setEnabled(on);
        } catch (RuntimeException e) {
            Log.w(TAG, "Dolby effect error", e);
        }
        if (!on) {
            mEffect.release();
            mEffect = null;
        }
        Log.i(TAG, "Dolby Atmos " + (on ? "on" : "off"));
    }

    private static void put(byte[] b, int off, int v) {
        for (int i = 0; i < 4; i++) b[off + i] = (byte) (v >> (8 * i));
    }
}
