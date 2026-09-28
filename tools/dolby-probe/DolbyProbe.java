import android.media.audiofx.AudioEffect;
import java.lang.reflect.Constructor;
import java.util.UUID;

/**
 * Switch Samsung's Dolby Atmos (DAP, libswdap via the effect proxy) on the global output mix and
 * hold it for a while, to test by ear before building a Quick Settings tile.
 * Run as root: CLASSPATH=/data/local/tmp/dolby.dex app_process /system/bin DolbyProbe [secs] [profile]
 * Parameter layout follows the DolbyAudioEffect class used by LineageOS device trees.
 */
public class DolbyProbe {
    static final UUID DAP = UUID.fromString("9d4921da-8225-4f29-aefa-39537a04bcaa");
    static final int PARAM_ENABLE = 0;
    static final int PARAM_CPDP_VALUES = 5;
    static final int PARAM_PROFILE = 0xA000000;

    static void setInt(AudioEffect e, int param, int value) {
        byte[] buf = new byte[12];
        put(buf, 0, param);
        put(buf, 4, 1);
        put(buf, 8, value);
        System.out.println("set " + Integer.toHexString(param) + "=" + value + " -> "
                + e.setParameter(PARAM_CPDP_VALUES, buf));
    }

    static int getInt(AudioEffect e, int param) {
        byte[] buf = new byte[12];
        int st = e.getParameter(PARAM_CPDP_VALUES + param, buf);
        int v = (buf[0] & 0xff) | (buf[1] & 0xff) << 8 | (buf[2] & 0xff) << 16 | buf[3] << 24;
        System.out.println("get " + Integer.toHexString(param) + " -> status " + st + " value " + v);
        return v;
    }

    static void put(byte[] b, int off, int v) {
        for (int i = 0; i < 4; i++) b[off + i] = (byte) (v >> (8 * i));
    }

    public static void main(String[] args) throws Exception {
        int secs = args.length > 0 ? Integer.parseInt(args[0]) : 60;
        Constructor<AudioEffect> c = AudioEffect.class.getDeclaredConstructor(
                UUID.class, UUID.class, int.class, int.class);
        c.setAccessible(true);
        AudioEffect e = c.newInstance(AudioEffect.EFFECT_TYPE_NULL, DAP, 100, 0);
        AudioEffect.Descriptor d = e.getDescriptor();
        System.out.println("created: " + d.name + " / " + d.implementor + " mode=" + d.connectMode
                + " control=" + e.hasControl());
        getInt(e, PARAM_ENABLE);
        getInt(e, PARAM_PROFILE);
        if (args.length > 1) setInt(e, PARAM_PROFILE, Integer.parseInt(args[1]));
        setInt(e, PARAM_ENABLE, 1);
        System.out.println("setEnabled(true) -> " + e.setEnabled(true) + " enabled=" + e.getEnabled());
        getInt(e, PARAM_ENABLE);
        if (secs < 0) {
            // A/B test: alternate on/off every -secs seconds, 6 times each.
            for (int i = 0; i < 12; i++) {
                boolean on = i % 2 == 0;
                setInt(e, PARAM_ENABLE, on ? 1 : 0);
                e.setEnabled(on);
                System.out.println(String.format("%3ds DOLBY %s", i * -secs, on ? "ON" : "off"));
                Thread.sleep(-secs * 1000L);
            }
        } else {
            Thread.sleep(secs * 1000L);
        }
        setInt(e, PARAM_ENABLE, 0);
        e.setEnabled(false);
        e.release();
        System.out.println("released");
    }
}
