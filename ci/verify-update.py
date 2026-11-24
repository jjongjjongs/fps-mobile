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
        activities = adb("shell", "dumpsys", "activity", "activities")
        resumed = next((line for line in activities.splitlines() if "topResumedActivity" in line), "")
        if "packageinstaller" in resumed.lower():
            adb("shell", "uiautomator", "dump", "--compressed", "/sdcard/vr-install.xml", check=False)
            xml = adb("shell", "cat", "/sdcard/vr-install.xml", check=False)
            nodes = ET.fromstring(xml).iter("node") if xml.startswith("<?xml") else []
            actions = []
            for node in nodes:
                attrs = node.attrib
                if "packageinstaller" not in attrs.get("package", "").lower(): continue
                text = attrs.get("text", "").strip().lower()
                resource = attrs.get("resource-id", "").split("/")[-1]
                if text: actions.append((resource, text))
                positive = text in {"update", "install", "업데이트", "설치"}
                if (positive or resource in {"button1", "ok_button", "install_button"}) and attrs.get("enabled")=="true":
                    x1,y1,x2,y2=map(int,re.findall(r"\d+",attrs["bounds"]))
                    adb("shell","input","tap",str((x1+x2)//2),str((y1+y2)//2))
                    break
            else:
                # Some Android package installer versions expose only keyboard focus.
                adb("shell","input","keyevent","KEYCODE_TAB")
                adb("shell","input","keyevent","KEYCODE_DPAD_RIGHT")
                adb("shell","input","keyevent","KEYCODE_ENTER")
            print("Installer controls:", actions, flush=True)
    time.sleep(2)
print(adb("logcat", "-d", "-s", "godot", "PackageInstaller")[-3500:])
print(adb("shell","dumpsys","activity","activities")[:1800])
sys.exit("Timed out waiting for Android to install the downloaded signed release.")
