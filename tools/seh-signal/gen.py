#!/usr/bin/env python3
"""Generate compile-only stubs for Samsung's HIDL radio classes (which exist at runtime inside the
GSI's telephony-common.jar) plus no-op implementations of ISehRadioIndication/ISehRadioResponse,
from dump.txt (produced on-device by Dump.java via reflection).

stubs/  -> compile classpath only (never dexed)
gen/    -> our code: SehIndicationBase / SehResponseImpl (dexed)
"""
import pathlib, re, collections

HERE = pathlib.Path(__file__).parent
dump = (HERE / "dump.txt").read_text().splitlines()

classes = collections.OrderedDict()  # name -> dict(kind, impl, methods, fields)
cur = None
for line in dump:
    m = re.match(r"== (interface|class) (\S+)(?: implements (\S+))?(?: extends (\S+))?", line)
    if m:
        cur = classes.setdefault(m.group(2), dict(kind=m.group(1), impl=m.group(3), methods=[], fields=[]))
        continue
    if cur is None:
        continue
    m = re.match(r"  M (.+?) (\w+)\((.*)\)$", line)
    if m:
        ret, name, params = m.groups()
        cur["methods"].append((ret, name, [p for p in split_params(params)] if False else params))
        continue
    m = re.match(r"  F (.+) (\w+)$", line)
    if m:
        cur["fields"].append(m.groups())


def split_params(s):
    out, depth, buf = [], 0, ""
    for ch in s:
        if ch == "<": depth += 1
        if ch == ">": depth -= 1
        if ch == "," and depth == 0:
            out.append(buf); buf = ""
        else:
            buf += ch
    if buf: out.append(buf)
    return out


def named(p):
    return ", ".join(f"{jt(t)} p{i}" for i, t in enumerate(split_params(p)))


def jt(t):  # java source type: nested classes use '.' instead of '$'
    return t.replace("$", ".")


BASE_METHODS = {"asBinder", "debug", "getDebugInfo", "getHashChain", "interfaceChain",
                "interfaceDescriptor", "linkToDeath", "notifySyspropsChanged", "ping",
                "setHALInstrumentation", "unlinkToDeath"}

stubs = HERE / "stubs"
gen = HERE / "gen"
for d in (stubs, gen):
    if d.exists():
        for f in sorted(d.rglob("*"), reverse=True):
            f.unlink() if f.is_file() else f.rmdir()


def write(root, fqcn, body):
    pkg, _, simple = fqcn.rpartition(".")
    p = root / pkg.replace(".", "/") / (simple + ".java")
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(f"package {pkg};\n{body}\n")


def default(ret):
    return {"void": "", "int": "return 0;", "boolean": "return false;"}.get(ret, "return null;")


# --- stubs for Samsung types ---
top = {n: c for n, c in classes.items() if "$" not in n}
nested = {n: c for n, c in classes.items() if "$" in n}
for name, c in top.items():
    simple = name.rpartition(".")[2]
    if c["kind"] == "class":
        fields = "".join(f"    public {jt(t)} {n};\n" for t, n in c["fields"])
        write(stubs, name, f"public final class {simple} {{\n{fields}}}")
        continue
    ext = f" extends {c['impl']}" if c["impl"] and c["impl"].startswith("vendor.") else " extends android.internal.hidl.base.V1_0.IBase"
    meths = "".join(f"    {jt(r)} {n}({named(p)}) throws android.os.RemoteException;\n"
                    for r, n, p in c["methods"] if n not in BASE_METHODS)
    extra = ""
    for nn, nc in nested.items():
        if nn.startswith(name + "$"):
            inner = nn.split("$")[1]
            im = "".join(f"        {jt(r)} {n}({named(p)});\n" for r, n, p in nc["methods"])
            extra += f"    public interface {inner} {{\n{im}    }}\n"
    extra += (f"    static {simple} getService(String name, boolean retry) throws android.os.RemoteException {{ return null; }}\n"
              f"    public static abstract class Stub extends android.os.HwBinder implements {simple} {{}}\n")
    write(stubs, name, f"public interface {simple}{ext} {{\n{meths}{extra}}}")

# --- stubs for framework hidden classes we compile against ---
write(stubs, "android.internal.hidl.base.V1_0.IBase", "public interface IBase extends android.os.IHwInterface {}")
write(stubs, "android.os.IHwInterface", "public interface IHwInterface {}")
write(stubs, "android.os.HwBinder", "public abstract class HwBinder {\n"
      "    public static void configureRpcThreadpool(long n, boolean callerWillJoin) {}\n"
      "    public static void joinRpcThreadpool() {}\n}")
write(stubs, "android.hardware.radio.V1_0.RadioResponseInfo", "public final class RadioResponseInfo { public int type, serial, error; }")
for t in ("AppStatus", "CardStatus"):
    write(stubs, f"android.hardware.radio.V1_0.{t}", f"public final class {t} {{}}")

# --- our no-op implementations (methods not in BASE are what the Stub leaves abstract) ---
def impl(iface, cls, special):
    seen, body = set(), ""
    chain = []
    n = iface
    while n in classes:
        chain.append(n)
        n = classes[n]["impl"]
    for name in chain:
        for r, m, p in classes[name]["methods"]:
            if m in BASE_METHODS or (m, p) in seen:
                continue
            seen.add((m, p))
            params = split_params(p)
            args = ", ".join(f"{jt(t)} a{i}" for i, t in enumerate(params))
            code = special.get(m, f"on(\"{m}\"); {default(r)}")
            body += f"    public {jt(r)} {m}({args}) {{ {code} }}\n"
    return (f"public abstract class {cls} extends {iface}.Stub {{\n"
            f"    protected abstract void on(String what);\n{body}}}")


write(gen, "me.jason.fold3.seh.SehIndicationBase", impl(
    "vendor.samsung.hardware.radio.V2_2.ISehRadioIndication", "SehIndicationBase", {
        "signalLevelInfoChanged": "onSignalBar(a1);",
        "needPacketUsage": "a1.onValues(0, new vendor.samsung.hardware.radio.V2_0.SehPacketUsage());",
        "needSettingValueIndication": "on(\"needSettingValueIndication \" + a0 + \" \" + a1); return -1;",
        "execute": "on(\"execute \" + a1);",
        "nrIconTypeChanged": "on(\"nrIconTypeChanged \" + a1);",
    }).replace("protected abstract void on(String what);",
               "protected abstract void on(String what);\n"
               "    protected abstract void onSignalBar(vendor.samsung.hardware.radio.V2_0.SehSignalBar b);"))
write(gen, "me.jason.fold3.seh.SehResponseBase", impl(
    "vendor.samsung.hardware.radio.V2_2.ISehRadioResponse", "SehResponseBase", {}))
print("stubs:", sum(1 for _ in stubs.rglob("*.java")), "gen:", sum(1 for _ in gen.rglob("*.java")))
