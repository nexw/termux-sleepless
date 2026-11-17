import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Looper;
import java.lang.reflect.Method;
import java.time.Instant;

public class ScreenProbe {
    static void log(String s) { System.out.println(Instant.now() + " " + s); System.out.flush(); }
    public static void main(String[] args) throws Exception {
        Looper.prepareMainLooper();
        Class<?> at = Class.forName("android.app.ActivityThread");
        Object thread = at.getDeclaredMethod("systemMain").invoke(null);
        Context system = (Context) at.getDeclaredMethod("getSystemContext").invoke(thread);
        Context ctx = system.createPackageContext("com.termux", 2);
        BroadcastReceiver receiver = new BroadcastReceiver() {
            @Override public void onReceive(Context c, Intent i) { log("EVENT " + i.getAction()); }
        };
        IntentFilter filter = new IntentFilter();
        filter.addAction("android.intent.action.SCREEN_OFF");
        filter.addAction("android.intent.action.SCREEN_ON");
        ctx.registerReceiver(receiver, filter);
        try {
            Object registered = Context.class.getMethod("getRegisteredIntentFilters", BroadcastReceiver.class).invoke(ctx, receiver);
            log("BROADCAST registered filters according to system: " + registered);
        } catch (Throwable e) { log("BROADCAST inspect failed: " + e); }
        Object dm = Context.class.getMethod("getSystemService", String.class).invoke(ctx, "display");
        Class<?> dmClass = Class.forName("android.hardware.display.DisplayManager");
        Class<?> displayClass = Class.forName("android.view.Display");
        Class<?> listenerClass = Class.forName("android.hardware.display.DisplayManager$DisplayListener");
        Method getDisplay = dmClass.getMethod("getDisplay", int.class);
        Method getState = displayClass.getMethod("getState");
        Object listener = java.lang.reflect.Proxy.newProxyInstance(listenerClass.getClassLoader(), new Class<?>[]{listenerClass}, (proxy, method, params) -> {
            if (method.getName().equals("hashCode")) return System.identityHashCode(proxy);
            if (method.getName().equals("equals")) return proxy == params[0];
            if (method.getName().equals("toString")) return "ScreenProbeDisplayListener";
            if (params != null && params.length > 0 && params[0] instanceof Integer) {
                int id = (Integer) params[0];
                Object display = getDisplay.invoke(dm, id);
                Object state = display == null ? "removed" : getState.invoke(display);
                log("DISPLAY " + method.getName() + " id=" + id + " state=" + state + " (1=OFF,2=ON,3=DOZE,4=DOZE_SUSPEND)");
            }
            return null;
        });
        dmClass.getMethod("registerDisplayListener", listenerClass, Class.forName("android.os.Handler")).invoke(dm, listener, null);
        log("DISPLAY initial id=0 state=" + getState.invoke(getDisplay.invoke(dm, 0)));
        log("READY display listener registered; broadcast registration NOT assumed; uid=" + android.os.Process.myUid());
        Looper.loop();
    }
}
