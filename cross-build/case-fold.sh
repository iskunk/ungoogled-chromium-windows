#!/bin/sh
# case-fold.sh

set -e

# Create specific mixed-case symlinks for lowercase-named files in a given
# directory, e.g.
#
#   WinString.h -> winstring.h
#
mixed_case_files()
{
	local dir=$1
	shift
	(cd "$dir" || exit
	 for x in $*
	 do
		lc_x=$(echo "$x" | tr A-Z a-z)
		test -f $lc_x || { echo "error: $dir/$lc_x: not found"; exit 1; }
		test -f $x || ln -sv $lc_x $x
	 done
	)
}

# Create lowercase symlinks for most (all?) mixed-case header and library
# files in the specified directory, e.g.
#
#   winsock2.h   -> WinSock2.h
#   advapi32.lib -> AdvAPI32.Lib
#
case_fold_dir()
{
	local dir=$1
	(cd "$dir" || exit
	 for x in [A-Z]*.h *.[Ll][Ii][Bb]
	 do
		test -f $x || continue
		lc_x=$(echo "$x" | tr A-Z a-z)
		test "_$x" != "_$lc_x" || continue
		test -f $lc_x || ln -sv $x $lc_x
	 done
	)
}

# Optional base directory
#
test -z "$1" || cd "$1"

(cd VC/Tools/MSVC/*/bin && (test -d HostX64 || ln -sv Hostx64 HostX64))

case_fold_dir Windows?Kits/10/Include/*/shared
case_fold_dir Windows?Kits/10/Include/*/um
case_fold_dir Windows?Kits/10/Include/*/winrt

mixed_case_files VC/Tools/MSVC/*/include \
	DelayIMP.h

mixed_case_files Windows?Kits/10/Include/*/shared \
	DXGI1_4.h \
	DXGIType.h \
	DriverSpecs.h \
	POPPACK.H \
	PSHPACK1.H \
	Sddl.h \
	SpecStrings.h \
	WinDef.h \
	WlanTypes.h

mixed_case_files Windows?Kits/10/Include/*/um \
	AudioClient.h \
	Combaseapi.h \
	D2DBaseTypes.h \
	D3Dcommon.h \
	DWrite.h \
	DWrite_1.h \
	DWrite_2.h \
	EapTypes.h \
	FontSub.h \
	Functiondiscoverykeys_devpkey.h \
	GdiplusBase.h \
	GdiplusBitmap.h \
	GdiplusBrush.h \
	GdiplusCachedBitmap.h \
	GdiplusColor.h \
	GdiplusColorMatrix.h \
	GdiplusEffects.h \
	GdiplusEnums.h \
	GdiplusFlat.h \
	GdiplusFont.h \
	GdiplusFontCollection.h \
	GdiplusFontFamily.h \
	GdiplusGpStubs.h \
	GdiplusGraphics.h \
	GdiplusHeaders.h \
	GdiplusImageAttributes.h \
	GdiplusImageCodec.h \
	GdiplusImaging.h \
	GdiplusInit.h \
	GdiplusLineCaps.h \
	GdiplusMatrix.h \
	GdiplusMem.h \
	GdiplusMetaHeader.h \
	GdiplusMetafile.h \
	GdiplusPath.h \
	GdiplusPen.h \
	GdiplusPixelFormats.h \
	GdiplusRegion.h \
	GdiplusStringFormat.h \
	GdiplusTypes.h \
	MFTransform.h \
	MMDeviceAPI.h \
	NCrypt.h \
	OAIdl.h \
	OCIdl.h \
	ObjBase.h \
	ObjIdl.h \
	Ole2.h \
	OleCtl.h \
	PowrProf.h \
	SPError.h \
	Sensors.h \
	Shlobj.h \
	T2EmbApi.h \
	VFWMSGS.H \
	VSStyle.h \
	Vssym32.h \
	Winsock2.h \
	Winuser.h \
	Ws2spi.h \
	XInput.h \
	XpsObjectModel.h \
	restrictedErrorInfo.h \
	windows.graphics.directX.direct3d11.interop.h

mixed_case_files Windows?Kits/10/Include/*/winrt \
	AsyncInfo.h \
	IVectorChangedEventArgs.h \
	Inspectable.h \
	WinString.h \
	Windows.ApplicationModel.h \
	Windows.ApplicationModel.Activation.h \
	Windows.ApplicationModel.AppService.h \
	Windows.ApplicationModel.Appointments.h \
	Windows.ApplicationModel.Appointments.AppointmentsProvider.h \
	Windows.ApplicationModel.Background.h \
	Windows.ApplicationModel.Calls.h \
	Windows.ApplicationModel.Calls.Background.h \
	Windows.ApplicationModel.CommunicationBlocking.h \
	Windows.ApplicationModel.Contacts.h \
	Windows.ApplicationModel.Contacts.Provider.h \
	Windows.ApplicationModel.Core.h \
	Windows.ApplicationModel.DataTransfer.h \
	Windows.ApplicationModel.DataTransfer.DragDrop.h \
	Windows.ApplicationModel.DataTransfer.ShareTarget.h \
	Windows.ApplicationModel.Email.h \
	Windows.ApplicationModel.Payments.h \
	Windows.ApplicationModel.Search.h \
	Windows.ApplicationModel.SocialInfo.h \
	Windows.ApplicationModel.UserActivities.h \
	Windows.ApplicationModel.UserDataAccounts.h \
	Windows.ApplicationModel.UserDataAccounts.Provider.h \
	Windows.ApplicationModel.UserDataTasks.h \
	Windows.ApplicationModel.Wallet.h \
	Windows.Data.Json.h \
	Windows.Data.Text.h \
	Windows.Data.Xml.Dom.h \
	Windows.Devices.h \
	Windows.Devices.Adc.Provider.h \
	Windows.Devices.Bluetooth.h \
	Windows.Devices.Bluetooth.Advertisement.h \
	Windows.Devices.Bluetooth.Background.h \
	Windows.Devices.Bluetooth.GenericAttributeProfile.h \
	Windows.Devices.Bluetooth.Rfcomm.h \
	Windows.Devices.Display.h \
	Windows.Devices.Enumeration.h \
	Windows.Devices.Geolocation.h \
	Windows.Devices.Gpio.Provider.h \
	Windows.Devices.Haptics.h \
	Windows.Devices.HumanInterfaceDevice.h \
	Windows.Devices.I2c.Provider.h \
	Windows.Devices.Input.h \
	Windows.Devices.Lights.h \
	Windows.Devices.Perception.h \
	Windows.Devices.PointOfService.h \
	Windows.Devices.Power.h \
	Windows.Devices.Printers.h \
	Windows.Devices.Printers.Extensions.h \
	Windows.Devices.Pwm.Provider.h \
	Windows.Devices.Radios.h \
	Windows.Devices.Sensors.h \
	Windows.Devices.SmartCards.h \
	Windows.Devices.Sms.h \
	Windows.Devices.Spi.Provider.h \
	Windows.Foundation.h \
	Windows.Foundation.Numerics.h \
	Windows.Gaming.Input.h \
	Windows.Gaming.Input.Custom.h \
	Windows.Gaming.Input.ForceFeedback.h \
	Windows.Gaming.Preview.h \
	Windows.Gaming.XboxLive.h \
	Windows.Globalization.h \
	Windows.Graphics.h \
	Windows.Graphics.DirectX.Direct3D11.h \
	Windows.Graphics.DirectX.h \
	Windows.Graphics.Display.h \
	Windows.Graphics.Effects.h \
	Windows.Graphics.Imaging.h \
	Windows.Graphics.Printing.h \
	Windows.Graphics.Printing.PrintTicket.h \
	Windows.Management.Deployment.h \
	Windows.Media.h \
	Windows.Media.Audio.h \
	Windows.Media.Capture.h \
	Windows.Media.Capture.Core.h \
	Windows.Media.Capture.Frames.h \
	Windows.Media.Casting.h \
	Windows.Media.ClosedCaptioning.h \
	Windows.Media.Core.h \
	Windows.Media.Devices.h \
	Windows.Media.Devices.Core.h \
	Windows.Media.Editing.h \
	Windows.Media.Effects.h \
	Windows.Media.FaceAnalysis.h \
	Windows.Media.MediaProperties.h \
	Windows.Media.PlayTo.h \
	Windows.Media.Playback.h \
	Windows.Media.Protection.h \
	Windows.Media.Render.h \
	Windows.Media.SpeechRecognition.h \
	Windows.Media.Streaming.h \
	Windows.Media.Streaming.Adaptive.h \
	Windows.Media.Transcoding.h \
	Windows.Networking.h \
	Windows.Networking.BackgroundTransfer.h \
	Windows.Networking.Connectivity.h \
	Windows.Networking.Sockets.h \
	Windows.Perception.h \
	Windows.Perception.People.h \
	Windows.Perception.Spatial.h \
	Windows.Phone.h \
	Windows.Security.Authentication.Web.h \
	Windows.Security.Authentication.Web.Core.h \
	Windows.Security.Authentication.Web.Provider.h \
	Windows.Security.Authorization.AppCapabilityAccess.h \
	Windows.Security.Credentials.h \
	Windows.Security.Cryptography.Certificates.h \
	Windows.Security.Cryptography.Core.h \
	Windows.Security.EnterpriseData.h \
	Windows.Services.Maps.h \
	Windows.Services.Maps.LocalSearch.h \
	Windows.Storage.h \
	Windows.Storage.FileProperties.h \
	Windows.Storage.Pickers.Provider.h \
	Windows.Storage.Provider.h \
	Windows.Storage.Search.h \
	Windows.Storage.Streams.h \
	Windows.System.h \
	Windows.System.Diagnostics.h \
	Windows.System.Power.h \
	Windows.System.RemoteSystems.h \
	Windows.System.Threading.h \
	Windows.UI.h \
	Windows.UI.Composition.h \
	Windows.UI.Core.h \
	Windows.UI.Core.CoreWindowFactory.h \
	Windows.UI.Input.h \
	Windows.UI.Input.Inking.h \
	Windows.UI.Input.Spatial.h \
	Windows.UI.Notifications.h \
	Windows.UI.Popups.h \
	Windows.UI.Shell.h \
	Windows.UI.StartScreen.h \
	Windows.UI.Text.h \
	Windows.UI.Text.Core.h \
	Windows.UI.UIAutomation.h \
	Windows.UI.ViewManagement.h \
	Windows.UI.WindowManagement.h \
	Windows.UI.Xaml.h \
	Windows.UI.Xaml.Automation.h \
	Windows.UI.Xaml.Automation.Peers.h \
	Windows.UI.Xaml.Automation.Provider.h \
	Windows.UI.Xaml.Automation.Text.h \
	Windows.UI.Xaml.Controls.h \
	Windows.UI.Xaml.Controls.Primitives.h \
	Windows.UI.Xaml.Data.h \
	Windows.UI.Xaml.Documents.h \
	Windows.UI.Xaml.Input.h \
	Windows.UI.Xaml.Interop.h \
	Windows.UI.Xaml.Media.h \
	Windows.UI.Xaml.Media.Animation.h \
	Windows.UI.Xaml.Media.Imaging.h \
	Windows.UI.Xaml.Media.Media3D.h \
	Windows.UI.Xaml.Navigation.h \
	Windows.Web.h \
	Windows.Web.Http.h \
	Windows.Web.Http.Filters.h \
	Windows.Web.Http.Headers.h \
	Windows.Web.Syndication.h \
	Windows.Web.UI.h \
	windows.graphics.directX.direct3d11.h

for arch in arm arm64 x64 x86
do
	dir=$(echo Windows?Kits/10/Lib/*/um/$arch)
	test -d "$dir" || continue

	case_fold_dir "$dir"

	mixed_case_files "$dir" \
		Bthprops.lib \
		Cfgmgr32.lib \
		Crypt32.lib \
		Propsys.lib \
		Setupapi.lib
done

# end case-fold.sh
