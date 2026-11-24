"""Exercise the public-release download and confirm the Android installer in CI."""
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

PACKAGE = "com.jjongjjongs.vectorrange"

def adb(*args, check=True):
    return subprocess.run(["adb", *args], capture_output=True, text=True, check=check).stdout

adb("install", "probe/previous.apk")
adb("shell", "appops", "set", PACKAGE, "REQUEST_INSTALL_PACKAGES", "allow")
activity = adb("shell", "cmd", "package", "resolve-activity", "--brief", PACKAGE).strip().splitlines()[-1]
adb("logcat", "-c")
adb("shell", "am", "start", "-W", activity)
deadline = time.monotonic() + 240
while time.monotonic() < deadline:
    if "versionName=0.3.0" in adb("shell", "dumpsys", "package", PACKAGE):
        print("In-app download, integrity check and Android-confirmed package replacement passed.")
        sys.exit(0)
    logs = adb("logcat", "-d", "-s", "godot")
    if "UPGRADE_PROBE failed" in logs:
        sys.exit(logs[-3500:])
    if "opening Android installer" in logs:
        # Only confirm the positive action in the system package installer.
        if "dumped" in adb("shell", "uiautomator", "dump", "/data/local/tmp/vr-ui.xml", check=False).lower():
            xml = adb("shell", "cat", "/data/local/tmp/vr-ui.xml")
            for node in ET.fromstring(xml).iter("node"):
                attrs = node.attrib
                if attrs["package"] not in {"com.android.packageinstaller", "com.google.android.packageinstaller", "com.android.permissioncontroller", "com.google.android.permissioncontroller"}:
                    continue
                if attrs["resource-id"].endswith("/button1") and attrs["enabled"]=="true":
                    x1,y1,x2,y2=map(int,re.findall(r"\d+",attrs["bounds"]))
                    adb("shell","input","tap",str((x1+x2)//2),str((y1+y2)//2))
                    break
    time.sleep(2)
print(adb("logcat", "-d", "-s", "godot", "PackageInstaller")[-3500:])
print(adb("shell","dumpsys","activity","activities")[:1800])
sys.exit("Timed out waiting for Android to install the downloaded signed release.")
