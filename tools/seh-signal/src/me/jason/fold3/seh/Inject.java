package me.jason.fold3.seh;

import android.os.IBinder;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;

/** Push a SignalStrength with the given LTE bar level (0-4) into TelephonyRegistry, as root. */
public class Inject {
    // Mid-points of AOSP's default LTE RSRP thresholds (-115, -105, -95, -85 dBm).
    static final int[] RSRP_FOR_LEVEL = {-120, -110, -100, -90, -80};

    static Object signalStrength(int lteLevel) throws Exception {
        ClassLoader cl = Inject.class.getClassLoader();
        Class<?> lteC = Class.forName("android.telephony.CellSignalStrengthLte");
        Object lte = lteC.getConstructor(int.class, int.class, int.class, int.class, int.class, int.class, int.class)
                .newInstance(Integer.MAX_VALUE, RSRP_FOR_LEVEL[Math.max(0, Math.min(4, lteLevel))], -10, 100,
                        Integer.MAX_VALUE, Integer.MAX_VALUE, Integer.MAX_VALUE);
        String[] others = {"Cdma", "Gsm", "Wcdma", "Tdscdma"};
        Object[] parts = new Object[6];
        Class<?>[] types = new Class<?>[6];
        for (int i = 0; i < 4; i++) {
            types[i] = Class.forName("android.telephony.CellSignalStrength" + others[i]);
            parts[i] = types[i].getConstructor().newInstance();
        }
        types[4] = lteC;
        parts[4] = lte;
        types[5] = Class.forName("android.telephony.CellSignalStrengthNr");
        parts[5] = types[5].getConstructor().newInstance();
        Constructor<?> ssC = Class.forName("android.telephony.SignalStrength").getConstructor(types);
        return ssC.newInstance(parts);
    }

    static void notify(int phoneId, int subId, Object ss) throws Exception {
        IBinder b = (IBinder) Class.forName("android.os.ServiceManager")
                .getMethod("getService", String.class).invoke(null, "telephony.registry");
        Object reg = Class.forName("com.android.internal.telephony.ITelephonyRegistry$Stub")
                .getMethod("asInterface", IBinder.class).invoke(null, b);
        Method m = reg.getClass().getMethod("notifySignalStrengthForPhoneId", int.class, int.class,
                Class.forName("android.telephony.SignalStrength"));
        m.invoke(reg, phoneId, subId, ss);
    }

    public static void main(String[] a) throws Exception {
        int level = Integer.parseInt(a[0]);
        int subId = a.length > 1 ? Integer.parseInt(a[1]) : 1;
        Object ss = signalStrength(level);
        notify(0, subId, ss);
        System.out.println("notified sub " + subId + ": " + ss);
    }
}
