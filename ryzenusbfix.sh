#!/bin/bash
#XLNC
#15/818

if ! [ "$(id -u)" = 0 ]; then
	sudo "$0" "$1"
	exit 0
fi

printf '\e[9;1t' && clear
echo
echo -e "${ITL} /** ${STD}"
echo -e "${ITL}  * - Name: ryzenusbfix ${STD}"
echo -e "${ITL}  * - Info: Script to fix USB ports on ryzen systems. ${STD}"
echo -e "${ITL}  * - Auth: XLNC ${STD}"
echo -e "${ITL}  * - Date: 15/08/2018 ${STD}"
echo -e "${ITL}  */ ${STD}"
echo

sleep 2
echo
echo "-> Mounting EFI."
echo

vol="/"
DRIVE="$(diskutil info $vol | grep 'Part of Whole' | cut -d : -f 2 | sed 's/^ *//g' | sed 's/ *$//g')"
diskutil mount /dev/"$DRIVE"s1 >/dev/null 2>&1

if [ -e /Volumes/EFI/EFI/CLOVER/ACPI/patched/DSDT.aml ]; then
	echo
	echo "-> Existing DSDT.aml detected in EFI. [DELETING]"
	echo
	rm -rf /Volumes/EFI/EFI/CLOVER/ACPI/patched/DSDT.aml
	echo
	echo "-> Now reboot the system and re-run the ryzenusbfix"
	echo
	exit 1
fi

for folders in /Volumes/EFI/EFI/CLOVER/kexts/; do
	if [ -e /Volumes/EFI/EFI/CLOVER/kexts/$folders/DummyUSB* ] || [ -e /Volumes/EFI/EFI/CLOVER/kexts/$folders/GenericUSB* ]; then
		echo
		echo "-> Detected old USB files in EFI. [DELETING]"
		echo
		rm -rf /Volumes/EFI/EFI/CLOVER/kexts/$folders/DummyUSB*
		rm -rf /Volumes/EFI/EFI/CLOVER/kexts/$folders/GenericUSB*
	fi
done

if [ -e /System/Library/Extensions/DummyUSB* ] || [ -e /System/Library/Extensions/GenericUSB* ]; then
	echo
	echo "-> Detected old USB files in S/L/E. [DELETING]"
	echo
	rm -rf /System/Library/Extensions/DummyUSB*
	rm -rf /System/Library/Extensions/GenericUSB*
	rm -rf /System/Library/PrelinkedKernels/pre*
	echo
	echo "-> Rebuilding caches."
	echo
	touch /System/Library/Extensions
	kextcache -Boot -U /
fi

rm -rf "/tmp/XLNC"
mkdir /tmp/XLNC

cat >/tmp/XLNC/ryzenusbpatch.txt <<'EOF'
into scope label _SB.PCI0.GP17.XHC0 remove_entry;

into device label RHUB parent_label PTXH remove_entry;
into device label RHUB parent_label XHC0 remove_entry;
into device label RHUB parent_label AS43 remove_entry;

into device label PTXH insert
begin
Method (_DSM, 4, NotSerialized)\n
{\n
    If (LNot (Arg2)) { Return (Buffer(One) { 0x03 } ) }\n
    Return (Package(0x0a)\n
    {\n
        "kUSBSleepPortCurrentLimit",\n
	0x0834,\n
	"kUSBSleepPowerSupply",\n
	0x13EC,\n
	"kUSBWakePortCurrentLimit",\n
	0x0834,\n
	"kUSBWakePowerSupply",\n
	0x13EC,\n
	"kUSBSHostControllerDisableUSB3LPM",\n
	0x01\n

    })\n
}\n
end;

into device label XHC0 insert
begin
Method (_DSM, 4, NotSerialized)\n
{\n
    If (LNot (Arg2)) { Return (Buffer(One) { 0x03 } ) }\n
    Return (Package(0x0a)\n
    {\n
        "kUSBSleepPortCurrentLimit",\n
	0x0834,\n
	"kUSBSleepPowerSupply",\n
	0x13EC,\n
	"kUSBWakePortCurrentLimit",\n
	0x0834,\n
	"kUSBWakePowerSupply",\n
	0x13EC,\n
	"kUSBSHostControllerDisableUSB3LPM",\n
	0x01\n

    })\n
}\n
end;

into device label AS43 insert
begin
Method (_DSM, 4, NotSerialized)\n
{\n
    If (LNot (Arg2)) { Return (Buffer(One) { 0x03 } ) }\n
    Return (Package(0x0a)\n
    {\n
        "kUSBSleepPortCurrentLimit",\n
	0x0834,\n
	"kUSBSleepPowerSupply",\n
	0x13EC,\n
	"kUSBWakePortCurrentLimit",\n
	0x0834,\n
	"kUSBWakePowerSupply",\n
	0x13EC,\n
	"kUSBSHostControllerDisableUSB3LPM",\n
	0x01\n

    })\n
}\n
end;
EOF

curl -s -o /tmp/XLNC/patchmatic https://raw.githubusercontent.com/XLNCs/ryzenusbfix/master/utils/patchmatic
curl -s -o /tmp/XLNC/iasl https://raw.githubusercontent.com/XLNCs/ryzenusbfix/master/utils/iasl
curl -s -o /tmp/XLNC/k2p https://raw.githubusercontent.com/XLNCs/ryzenusbfix/master/utils/k2p

chmod +x "/tmp/XLNC/patchmatic"
chmod +x "/tmp/XLNC/iasl"
chmod +x "/tmp/XLNC/k2p"

PATCH="/tmp/XLNC/patchmatic"
CONV="/tmp/XLNC/iasl"
KEXTTOPATCH="/tmp/XLNC/k2p"

echo
echo "-> Extracting DSDT Table."
echo
$PATCH -extract /tmp/XLNC/
$CONV -e /tmp/XLNC/SSDT*.aml -d /tmp/XLNC/DSDT.aml
echo
echo "-> Patching DSDT Table."
echo
$PATCH /tmp/XLNC/DSDT.dsl /tmp/XLNC/ryzenusbpatch.txt /tmp/XLNC/PATCHED.dsl
$CONV -ve /tmp/XLNC/PATCHED.dsl
cp -Rf /tmp/XLNC/PATCHED.aml /Volumes/EFI/EFI/CLOVER/ACPI/patched/DSDT.aml

if ! [ -e /Volumes/EFI/EFI/CLOVER/backup_config.plist ]; then
	cp -Rf /Volumes/EFI/EFI/CLOVER/config.plist /Volumes/EFI/EFI/CLOVER/backup_config.plist
fi

config="/Volumes/EFI/EFI/CLOVER/config.plist"
echo
echo "-> Patching config.plist"
echo
$KEXTTOPATCH $config Has -find "21F281FA 000002" -replace "21F281FA 000011" -name AppleUSBXHCI || $KEXTTOPATCH $config add -find "21F281FA 000002" -replace "21F281FA 000011" -name AppleUSBXHCI
$KEXTTOPATCH $config Has -find "D1000000 83F901" -replace "D1000000 83F910" -name AppleUSBXHCI || $KEXTTOPATCH $config add -find "D1000000 83F901" -replace "D1000000 83F910" -name AppleUSBXHCI
$KEXTTOPATCH $config Has -find "83BD7CFF FFFF0F" -replace "83BD7CFF FFFF1F" -name AppleUSBXHCI || $KEXTTOPATCH $config add -find "83BD7CFF FFFF0F" -replace "83BD7CFF FFFF1F" -name AppleUSBXHCI
$KEXTTOPATCH $config Has -find "837D940F 0F839704 0000" -replace "837D940F 90909090 9090" -name AppleUSBXHCI || $KEXTTOPATCH $config add -find "837D940F 0F839704 0000" -replace "837D940F 90909090 9090" -name AppleUSBXHCI
rm -rf "/tmp/XLNC"
echo
echo "-> Done."
echo
sleep 3
exit 0
