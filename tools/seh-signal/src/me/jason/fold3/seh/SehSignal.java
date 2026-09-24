package me.jason.fold3.seh;

import java.io.File;
import java.io.FileWriter;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;

import vendor.samsung.hardware.radio.V2_0.SehSignalBar;
import vendor.samsung.hardware.radio.V2_2.ISehRadio;
import vendor.samsung.hardware.radio.V2_2.SehVendorConfiguration;

/**
 * Signal bars for the Samsung RIL on the GSI.
 *
 * Samsung's RIL never fills the standard currentSignalStrength indication (all fields invalid), so
 * the status bar shows 0 bars. It reports bars only through its own
 * ISehRadioIndication.signalLevelInfoChanged(SehSignalBar), which the GSI's telephony registers for
 * but ignores. This daemon registers for that callback itself (the GSI's handler only logs, and we
 * answer needPacketUsage / needSettingValueIndication the same way it does), and pushes each level
 * into TelephonyRegistry as an LTE SignalStrength.
 *
 * Only one ISehRadio client is kept by the RIL, and the RIL restarts itself if that client dies, so
 * this must keep running once registered. If reports stop (the phone process re-registered after a
 * phone/rild restart), register again.
 *
 * Run as root: CLASSPATH=seh-signal.dex app_process /system/bin me.jason.fold3.seh.SehSignal
 */
public class SehSignal {
    static final String LOG = "/data/local/tmp/fold3-signal.log";
    static final long STALE_MS = 45_000;

    static volatile long lastReport = 0;
    static volatile int lastLevel = -1;
    static int subId = -1;

    static synchronized void log(String s) {
        String line = new SimpleDateFormat("MM-dd HH:mm:ss.SSS").format(new Date()) + " " + s;
        System.out.println(line);
        try {
            File f = new File(LOG);
            if (f.length() > 256 * 1024) f.renameTo(new File(LOG + ".old"));
            try (FileWriter w = new FileWriter(f, true)) { w.write(line + "\n"); }
        } catch (Exception ignored) {}
    }

    static SehVendorConfiguration conf(String name, String value) {
        SehVendorConfiguration c = new SehVendorConfiguration();
        c.name = name;
        c.value = value;
        return c;
    }

    static int currentSubId() {
        for (String m : new String[] {"getSubscriptionId", "getSubId"}) {
            try {
                Object r = Class.forName("android.telephony.SubscriptionManager").getMethod(m, int.class).invoke(null, 0);
                int id = r instanceof int[] ? (((int[]) r).length > 0 ? ((int[]) r)[0] : -1) : (Integer) r;
                if (id >= 0) return id;
            } catch (Throwable ignored) {}
        }
        return -1;
    }

    static void onBars(SehSignalBar b) {
        lastReport = System.currentTimeMillis();
        int level = Math.max(Math.max(b.lteLevel, b.nrLevel), Math.max(b.wcdmaLevel, b.gsmLevel));
        try {
            if (subId < 0 || level != lastLevel) subId = currentSubId();
            if (subId < 0) return;
            Inject.notify(0, subId, Inject.signalStrength(level));
            if (level != lastLevel) {
                log("level " + lastLevel + " -> " + level + " (lte=" + b.lteLevel + " nr=" + b.nrLevel
                        + " wcdma=" + b.wcdmaLevel + " gsm=" + b.gsmLevel + ") sub=" + subId);
                lastLevel = level;
            }
        } catch (Throwable t) {
            log("notify failed: " + t);
            subId = -1;
        }
    }

    static void register(String slot) throws Exception {
        ISehRadio svc = ISehRadio.getService(slot, true);
        svc.setResponseFunction(new SehResponseBase() {
            protected void on(String what) {}
        }, new SehIndicationBase() {
            protected void on(String what) {}
            protected void onSignalBar(SehSignalBar b) { onBars(b); }
        });
        ArrayList<SehVendorConfiguration> cfg = new ArrayList<>();
        cfg.add(conf("FW_READY", "1"));
        cfg.add(conf("CA_ENABLED", "1"));
        svc.setVendorSpecificConfiguration(0x3232, cfg);
        lastReport = System.currentTimeMillis();
        log("registered ISehRadio/" + slot);
    }

    public static void main(String[] args) throws Exception {
        String slot = args.length > 0 ? args[0] : "slot1";
        // Incoming HIDL calls from the RIL (indications, and two-way ones like
        // needSettingValueIndication) need hwbinder threads to serve them; without this the RIL
        // blocks forever on its first call to us.
        android.os.HwBinder.configureRpcThreadpool(4, true);
        Thread pool = new Thread(android.os.HwBinder::joinRpcThreadpool, "hwbinder-pool");
        pool.setDaemon(true);
        pool.start();
        log("start");
        while (true) {
            try {
                if (System.currentTimeMillis() - lastReport > STALE_MS) {
                    if (lastReport != 0) log("no reports for " + STALE_MS / 1000 + "s, re-registering");
                    register(slot);
                }
            } catch (Throwable t) {
                log("register failed: " + t);
            }
            Thread.sleep(5_000);
        }
    }
}
