import android.app.ActivityThread;
import android.content.Context;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Looper;

/**
 * Mic level on the VoIP capture path (VOICE_COMMUNICATION in MODE_IN_COMMUNICATION), outside a
 * call, to compare with Floss's in-call uplink levels. Prints rms (of 32767) once a second.
 * Run as root: CLASSPATH=/data/local/tmp/mic.dex app_process /system/bin MicProbe [secs] [rate]
 */
public class MicProbe {
    public static void main(String[] args) throws Exception {
        int secs = args.length > 0 ? Integer.parseInt(args[0]) : 10;
        int rate = args.length > 1 ? Integer.parseInt(args[1]) : 8000;
        Looper.prepareMainLooper();
        Context ctx = ActivityThread.systemMain().getSystemContext();
        AudioManager am = (AudioManager) ctx.getSystemService(Context.AUDIO_SERVICE);
        am.setMode(AudioManager.MODE_IN_COMMUNICATION);
        int min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
        AudioRecord r = new AudioRecord(MediaRecorder.AudioSource.VOICE_COMMUNICATION, rate,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, min * 2);
        r.startRecording();
        short[] buf = new short[rate / 10];
        for (int s = 0; s < secs; s++) {
            double sum = 0; int n = 0, peak = 0;
            for (int k = 0; k < 10; k++) {
                int got = r.read(buf, 0, buf.length);
                for (int i = 0; i < got; i++) { sum += buf[i] * (double) buf[i]; peak = Math.max(peak, Math.abs(buf[i])); }
                n += Math.max(got, 0);
            }
            System.out.println(String.format("%2ds rms=%d peak=%d", s + 1, (int) Math.sqrt(sum / Math.max(n, 1)), peak));
        }
        r.stop(); r.release();
        am.setMode(AudioManager.MODE_NORMAL);
    }
}
