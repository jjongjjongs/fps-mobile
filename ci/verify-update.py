"""Exercise the public-release download and confirm the Android installer in CI."""
import functools
import hashlib
import http.server
import json
from pathlib import Path
import shutil
import tempfile
import threading
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

PACKAGE = "com.jjongjjongs.vectorrange"

def adb(*args, check=True):
    return subprocess.run(["adb", *args], capture_output=True, text=True, check=check).stdout

version = sys.argv[1]
expected = Path("apk/install.apk")
mirror = tempfile.TemporaryDirectory()
root = Path(mirror.name)
name = f"VectorRange-{version}-release-arm64.apk"
dest = root / f"v{version}" / name
dest.parent.mkdir()
shutil.copyfile(expected, dest)
(root/"metadata").write_text(json.dumps({"draft":False,"prerelease":False,"tag_name":f"v{version}",
    "assets":[{"name":name,"size":dest.stat().st_size,"digest":"sha256:"+hashlib.sha256(dest.read_bytes()).hexdigest(),
    "browser_download_url":f"http://127.0.0.1:8174/v{version}/{name}"}]}))
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root))
server = http.server.ThreadingHTTPServer(("127.0.0.1",8174),handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
adb("reverse","tcp:8174","tcp:8174")
adb("shell","wm","size","720x1280")
adb("shell","wm","dismiss-keyguard")
adb("shell","settings","put","secure","immersive_mode_confirmations","confirmed")
adb("shell","svc","power","stayon","true")
adb("install", "-r", "probe/previous.apk")
adb("shell", "appops", "set", PACKAGE, "REQUEST_INSTALL_PACKAGES", "allow")
activity = adb("shell", "cmd", "package", "resolve-activity", "--brief", PACKAGE).strip().splitlines()[-1]
adb("logcat", "-c")
adb("shell", "am", "start", "-W", activity)
deadline = time.monotonic() + 280
while time.monotonic() < deadline:
    if f"versionName={version}" in adb("shell", "dumpsys", "package", PACKAGE):
        print("In-app download, integrity check and Android-confirmed package replacement passed.")
        # PackageManager reports the new version before the old Godot task has
        # finished tearing down. Return to the launcher and test a cold launch.
        time.sleep(5)
        adb("shell","input","keyevent","KEYCODE_HOME")
        for attempt in range(3):
            adb("shell","am","force-stop",PACKAGE)
            time.sleep(2)
            print(adb("shell","am","start","-W","-f","0x10008000",activity),flush=True)
            time.sleep(7)
            if adb("shell","pidof",PACKAGE,check=False).strip():
                print("Updated game cold launch passed.",flush=True)
                sys.exit(0)
        print(adb("logcat","-d","-b","crash")[-3500:])
        sys.exit("The updated game did not stay running after a cold launch.")
    logs = adb("logcat", "-d", "-s", "godot")
    if "UPGRADE_PROBE failed" in logs:
        sys.exit(logs[-3500:])
    if "opening Android installer" in logs:
        activities = adb("shell", "dumpsys", "activity", "activities")
        resumed = next((line for line in activities.splitlines() if "topResumedActivity" in line), "")
        if "packageinstaller" in resumed.lower():
            adb("shell", "uiautomator", "dump", "--compressed", "/sdcard/vr-install.xml", check=False)
            xml = adb("shell", "cat", "/sdcard/vr-install.xml", check=False)
            nodes = ET.fromstring(xml).iter("node") if xml.lstrip().startswith("<") else []
            actions = []
            for node in nodes:
                attrs = node.attrib
                if attrs.get("package","") not in {"android","com.android.packageinstaller","com.google.android.packageinstaller","com.android.permissioncontroller","com.google.android.permissioncontroller"}: continue
                text = attrs.get("text", "").strip().lower()
                resource = attrs.get("resource-id", "").split("/")[-1]
                if text: actions.append((resource, text))
                tutorial = attrs.get("package")=="android" and resource=="ok" and text=="got it"
                launcher_dialog = "pixel launcher isn't responding" in xml.lower() and resource=="aerr_close"
                positive = launcher_dialog or tutorial or text in {"update", "install", "업데이트", "설치"}
                if (positive or resource in {"button1", "ok_button", "install_button"}) and attrs.get("enabled")=="true":
                    x1,y1,x2,y2=map(int,re.findall(r"\d+",attrs["bounds"]))
                    adb("shell","input","tap",str((x1+x2)//2),str((y1+y2)//2))
                    break
            else:
                # Some Android package installer versions expose only keyboard focus.
                print("Awaiting actionable installer dialog", xml[:1200], flush=True)
            print("Installer controls:", actions, flush=True)
    time.sleep(2)
print(adb("logcat", "-d", "-s", "godot", "PackageInstaller")[-3500:])
print(adb("shell","dumpsys","activity","activities")[:1800])
sys.exit("Timed out waiting for Android to install the downloaded signed release.")
