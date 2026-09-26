import android.app.ActivityThread;
import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Looper;
import java.util.Arrays;

/**
 * Print live values of every proximity-like sensor (and optionally others matching a filter), to
 * find near/far thresholds for Samsung's non-standard proximity sensors.
 * Run as root: CLASSPATH=/data/local/tmp/probe.dex app_process /system/bin SensorProbe [secs] [type regex]
 */
public class SensorProbe {
    public static void main(String[] args) throws Exception {
        int secs = args.length > 0 ? Integer.parseInt(args[0]) : 20;
        String filter = args.length > 1 ? args[1] : "proximity";
        Looper.prepareMainLooper();
        Context ctx = ActivityThread.systemMain().getSystemContext();
        SensorManager sm = (SensorManager) ctx.getSystemService(Context.SENSOR_SERVICE);
        final long t0 = System.currentTimeMillis();
        for (Sensor s : sm.getSensorList(Sensor.TYPE_ALL)) {
            if (!s.getStringType().matches(".*(" + filter + ").*")) continue;
            System.out.println("sensor " + s.getName() + " type=" + s.getStringType()
                    + " max=" + s.getMaximumRange() + " wakeup=" + s.isWakeUpSensor());
            sm.registerListener(new SensorEventListener() {
                public void onSensorChanged(SensorEvent e) {
                    System.out.println(String.format("%6.1fs %-40s %s",
                            (System.currentTimeMillis() - t0) / 1000.0, s.getName(),
                            Arrays.toString(e.values)));
                }
                public void onAccuracyChanged(Sensor x, int a) {}
            }, s, SensorManager.SENSOR_DELAY_NORMAL);
        }
        new Thread(() -> {
            try { Thread.sleep(secs * 1000L); } catch (InterruptedException ignored) {}
            System.exit(0);
        }).start();
        Looper.loop();
    }
}
