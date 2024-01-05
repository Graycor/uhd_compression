#
# It is assumed you have an application like MakeMKV to rip a physical UHD that you own into a .mkv file
#
# Before you start you must have the follow applications installed.
# For #1 & 2, ensure you map to them to your PATH as environment variables.
#
# - dovi_tool
# - nvenc
# - MKVToolNix
#


#Custom Variables
$moviename="NAMEHERE"


#Hardcoded Variables
$source="C:\Rips\in\"
$dest="C:\Rips\out\"
$bitrate="25000"
$rpu_file="RPU.bin"
$videostream="extracted_video_stream"
$movieout="compressed_video_stream"
$dv_video_stream="injected_output.hevc"

$codecArray = @{
'HEVC/H.265/MPEG-H'='.h265'
'AVC/H.264/MPEG-4p10'='.h264'
'AV1'='.av1'
}

#Messages
$m0_1="Step 0.1 | Verifying codec of $moviename"
$m0_2="Step 0.2 | $moviename video ID is $trackID, codec is $trackCodec, file extension is $fileExtension"

$m1_1="Step 1.1 | Extracting video stream from $moviename"
$m1_2="Step 1.2 | Video stream extracted to $videostream$fileExtension"

$m2_1="Step 2.1 | Extracting DV data from $videostream$fileExtension"
$m2_2="Step 2.2 | DV RPU extracted to $rpu_file."

$m3_1="Step 3.1 | Compressing video stream from $videostream$fileExtension"
$m3_2="Step 3.2 | Compressed video stream saved to $movieout$fileExtension"

$m4_1="Step 4.1 | Injecting DV file $rpu_file to $movieout$fileExtension"
$m4_2="Step 4.2 | DV data injected to $dv_video_stream"

$m5_1="Step 5.1 | Injecting $dv_video_stream to '[FINAL]$moviename.mkv'"
$m5_2="Step 5.2 | Injected compressed, DV video stream to '[FINAL]$moviename.mkv'"

$m6_1="Step 6.1 | Please test the '[FINAL]$moviename.mkv'. Press Okay to delete temporary files"
$m6_2="Step 6.2 | Temporary files removed and '[FINAL]$moviename.mkv' is ready. Make sure to remove the original movie file."

$e1="Exiting script. Only 1 video track is supported. There is "

# Functions
Function custompause ($message)
{
    # Check if running Powershell ISE
    if ($psISE)
    {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("$message")
    }
    else
    {
        Write-Host "$message" -ForegroundColor Yellow
        $x = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}


########
# MAIN #
########

# Set working directory
cd $source

# Evaluate Video Stream JSON
$codecFormatEval = mkvmerge -J "$moviename.mkv" | ConvertFrom-JSON
$countVideoTracks=($codecFormatEval.tracks.type -eq 'video').Count

# Exit if video tracks is not equal to 1
if ($countVideoTracks -ne 1){
    Write-Output $e1 $countVideoTracks
    {exit 1}
}

# Loop through all tracks in MKV and extract the ID and codec where the track is a video type
foreach ($track in $codecFormatEval.tracks) {
    if ($track.type -eq 'video') {
    $trackID = $track.id
    $trackCodec =$track.codec
    $fileExtension=$codecArray[$trackCodec]
    break
    }
}

# Extract Video Stream
Write-Output $m1_1
mkvextract "$moviename.mkv" tracks $trackID':'$videostream$fileExtension
Write-Output $m1_2

# Extract RPU from Video Stream
Write-Output $m2_1
dovi_tool extract-rpu $videostream$fileExtension
Write-Output $m2_2

# Compress Video Stream
Write-Output $m3_1
nvenc --avsw --vbr $bitrate -i "$videostream$fileExtension" -o "$movieout$fileExtension" --codec hevc --interlace progressive --output-depth 10 --multipass 2pass-full --lookahead 32 --mv-precision Q-pel --profile main10 --colorrange auto --colormatrix auto --colorprim auto --transfer auto --chromaloc auto --max-cll copy --master-display copy --dhdr10-info copy --atc-sei auto --audio-copy --chapter-copy --metadata copy --cuda-schedule spin --thread-affinity all=all --thread-priority all=highest --thread-throttling all=off
Write-Output $m3_2

# Inject RPU to Compressed Video Stream
Write-Output $m4_1
dovi_tool inject-rpu --rpu-in $rpu_file "$movieout$fileExtension"
Write-Output $m4_2

# Inject Compressed Video Stream to MKV
Write-Output $m5_1
mkvmerge -o "$dest$moviename.mkv" -A -S -T -M -B --no-chapters ( $dv_video_stream ) -D ( "$moviename.mkv" ) 
Write-Output $m5_2


# Removal of Temporary Files
custompause ($m6_1)
Remove-Item -force "extracted_video_stream*", $rpu_file, "compressed_video_stream*", $dv_video_stream
Write-Output $m6_2
