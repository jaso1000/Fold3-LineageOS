public class FpActiveGroup {
    // Re-send setActiveGroup to Samsung's fingerprint HAL (it loses it after boot here).
    public static void main(String[] args) throws Exception {
        int gid = args.length > 0 ? Integer.parseInt(args[0]) : 0;
        String path = args.length > 1 ? args[1] : "/data/vendor_de/0/fpdata";
        Class<?> c = Class.forName("android.hardware.biometrics.fingerprint.V2_1.IBiometricsFingerprint");
        Object hal = c.getMethod("getService").invoke(null);
        Object ret = c.getMethod("setActiveGroup", int.class, String.class).invoke(hal, gid, path);
        System.out.println("setActiveGroup(" + gid + ", " + path + ") -> " + ret);
    }
}
