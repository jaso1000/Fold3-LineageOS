import java.lang.reflect.*;
import java.util.*;
public class Dump {
    static Set<String> seen = new TreeSet<>();
    static List<Class<?>> todo = new ArrayList<>();
    static void want(Type t) {
        if (t instanceof ParameterizedType) { for (Type a : ((ParameterizedType) t).getActualTypeArguments()) want(a); want(((ParameterizedType) t).getRawType()); return; }
        if (t instanceof Class) { Class<?> c = (Class<?>) t; while (c.isArray()) c = c.getComponentType();
            if (c.getName().startsWith("vendor.samsung") && seen.add(c.getName())) todo.add(c); }
    }
    public static void main(String[] a) throws Exception {
        for (String n : a) want(Class.forName(n));
        for (int i = 0; i < todo.size(); i++) {
            Class<?> c = todo.get(i);
            StringBuilder sb = new StringBuilder("== " + (c.isInterface() ? "interface " : "class ") + c.getName());
            for (Class<?> x : c.getInterfaces()) { sb.append(" implements ").append(x.getName()); want(x); }
            if (c.getSuperclass() != null) sb.append(" extends ").append(c.getSuperclass().getName());
            System.out.println(sb);
            for (Method m : c.getDeclaredMethods()) {
                if (!Modifier.isAbstract(m.getModifiers())) continue;
                StringBuilder s = new StringBuilder("  M " + m.getGenericReturnType().getTypeName() + " " + m.getName() + "(");
                Type[] p = m.getGenericParameterTypes();
                for (int j = 0; j < p.length; j++) { s.append(j > 0 ? "," : "").append(p[j].getTypeName()); want(p[j]); }
                want(m.getGenericReturnType());
                System.out.println(s + ")");
            }
            if (!c.isInterface()) for (Field f : c.getDeclaredFields()) if (!Modifier.isStatic(f.getModifiers())) { System.out.println("  F " + f.getGenericType().getTypeName() + " " + f.getName()); want(f.getGenericType()); }
            for (Class<?> x : c.getDeclaredClasses()) if (x.getSimpleName().endsWith("Callback")) want(x);
        }
    }
}
