declare -a local_path=("external/ImageMagick"
	"external/aac"
	"art"
	"bionic"
	"external/dng_sdk"
	"external/dnsmasq"
	"external/chromium-libpac"
	"external/freetype"
	"external/gptfdisk"
	"external/libavc"
	"external/libcups"
	"external/libcxx"
	"external/libexif"
	"external/libhevc"
	"external/libjpeg-turbo"
	"external/okhttp"
	"external/ppp"
	"external/sonivox"
	"external/sqlite"
	"external/v8"
	"external/wpa_supplicant_8"
	"frameworks/opt/telephony"
	"hardware/interfaces"
	"frameworks/av"
	"frameworks/base"
	"frameworks/hardware/interfaces"
	"frameworks/minikin"
	"frameworks/native"
	"frameworks/opt/net/wifi"
	"hardware/libhardware"
	"libcore"
	"packages/apps/Bluetooth"
	"packages/apps/CellBroadcastReceiver"
	"packages/services/Telecomm"
	"packages/services/Telephony"
	"packages/apps/UnifiedEmail"
	"packages/providers/DownloadProvider"
	"packages/providers/TelephonyProvider"
	"packages/providers/TvProvider"
	"packages/services/BuiltInPrintService"
	"system/bt"
	"system/connectivity/wificond"
	"system/core"
	"system/gatekeeper"
	"packages/apps/CertInstaller"
	"packages/apps/Contacts"
	"packages/apps/Email"
	"packages/apps/ManagedProvisioning"
	"packages/apps/Nfc"
	"packages/apps/PackageInstaller"
	"packages/apps/Settings"
	"system/media"
	"system/nfc"
	"system/security"
	)


GITCOMD="git format-patch imx-p9.0.0_2.3.5-auto.."
#TARNAME=$(pwd | sed 's/\/home\/nxa12947\/android\/imx-p9.0.0_2.3.5-auto\/android_build\///' | sed 's/\//_/' | sed 's/$/.tgz/')
#TARNAME=$(pwd)

#echo "$TARNAME"

for ii in "${local_path[@]}"
do
	cd ${ii}
	TARNAME=$(pwd | sed 's/\/home\/nxa12947\/android\/imx-p9.0.0_2.3.5-auto\/android_build\///' | sed 's/\//_/g' | sed 's/$/.tgz/')
	#echo "$TARNAME"
	git format-patch imx-p9.0.0_2.3.5-auto.. | xargs tar zcvf $TARNAME 
	mv $TARNAME /home/nxa12947/android/tmp
	rm 0*.patch
	cd -
done


exit

git format-patch imx-p9.0.0_2.3.5-auto.. | xargs tar zcvf $TARNAME 
mv $TARNAME /home/nxa12947/android/tmp
rm 0*.patch
