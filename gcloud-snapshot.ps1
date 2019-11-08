<#
.SYNOPSIS
  Take snapshots of Google Compute Engine disks
.DESCRIPTION
  Automated creation of google compute disk snapshots and deletion of old ones
  Powershell port of google-compute-snapshot by jacksegal
.PARAMETER retention
  Number of days to keep snapshots. Snapshots older than this number deleted.
  Default if not set: 7 [OPTIONAL]
.PARAMETER copylabels
  Copy disk labels to snapshot labels [OPTIONAL]
.PARAMETER prefix
  Prefix to be used for naming snapshots.
  Max character length: 20
  Default if not set: 'gcs' [OPTIONAL]
.PARAMETER account
  Service Account to use.
  Blank if not set [OPTIONAL]
.PARAMETER project
  Project ID to use.
  Blank if not set [OPTIONAL]
.PARAMETER storage
  Snapshot storage location.
  Uses default storage location if not set [OPTIONAL]
.PARAMETER labels
  Additional labels to add to the created snapshots
  labels should be formatted as "label1=value1,label2=value2"
.PARAMETER dryrun
  Dry run: causes script to print debug variables and doesn't execute any
  create / delete commands [OPTIONAL]
.NOTES
  You should setup a Scheduled task in order to schedule a backup at regular
  intervals
#>

[CmdletBinding()]
param (
[parameter(mandatory=$false)][int]$retention = 7,
[parameter(mandatory=$false)][switch]$copylabels = $false,
[parameter(mandatory=$false)][string]$prefix = 'gcs',
[parameter(mandatory=$false)][string]$account = '',
[parameter(mandatory=$false)][string]$project = '',
[parameter(mandatory=$false)][string]$storage = '',
[parameter(mandatory=$false)][string]$labels,
[parameter(mandatory=$false)][switch]$dryrun = $false
)

Function Log-Time {
  param (
    [Parameter(Mandatory=$True)][array]$LogOutput
	)
	$currentDate = (Get-Date -UFormat "%d-%m-%Y")
	$currentTime = (Get-Date -UFormat "%T")
	$logOutput = $logOutput -join (" ")
	"[$currentDate $currentTime] $logOutput"
}

Function Print-Debug {
  param (
    [Parameter(Mandatory=$True)][string]$Output
  )
  Write-Host "[DEBUG]:" -f Cyan -nonewline ; Write-Host $Output
}

Function Print-Cmd {
  param (
    [Parameter(Mandatory=$True)][string]$Output
  )
  Write-Host "[CMD]:" -f Yellow -nonewline ; Write-Host $Output
}

Function Get-UnixTimeStamp {
  $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
  [int]([DateTime]::UtcNow - $unixEpochStart).TotalSeconds
}

Function Get-UriLeaf {
  param (
    [Parameter(Mandatory=$True)][string]$Uri
  )
  $Uri.split('/')[-1]
}

Function Get-InstanceName {
  $instanceName = Invoke-RestMethod -Uri http://metadata.google.internal/computeMetadata/v1/instance/hostname -Headers @{'Metadata-Flavor'='Google'}
  $instanceName.split('.')[0]
}

Function Get-DeviceList {
  param (
    [Parameter(Mandatory=$True)][string]$InstanceName
  )
  $deviceList = gcloud $optAccount compute disks list --filter "users~instances/$InstanceName" --format='value(name,zone,id)' $optProject
  $deviceList
}

Function Create-SnapshotName {
  param (
    [Parameter(Mandatory=$true)][string]$Prefix,
	[Parameter(Mandatory=$true)][string]$DeviceName,
	[Parameter(Mandatory=$true)][string]$DateTime
  )
  # create snapshot name
  $name = "$Prefix-$DeviceName-$DateTime"
  
  # google compute snapshot name cannot be longer than 62 character
  $nameMaxLen = 62
  
  # check if snapshot name is longer than max length
  if ($name.Length -ge $nameMaxLen) {
    
	# work out how many characters we require - prefix + timestamp
	$reqChars = "$Prefix--$DateTime"
	
	# work out how many characters that leaves us for the device name
	$deviceNameLen=$nameMaxLen - $reqChars.Length
	
	# shorten the device name
	$DeviceName = $DeviceName.SubString(0,$deviceNameLen)
	
	# create new (acceptable) snapshot name
	$name = "$Prefix-$DeviceName-$DateTime"
  }
  
  $name
}

Function Create-Snapshot {
  param (
    [Parameter(Mandatory=$true)][string]$DeviceName,
	[Parameter(Mandatory=$true)][string]$SnapshotName,
	[Parameter(Mandatory=$true)][string]$DeviceZone
  )
  if ($dryrun){
    Print-Cmd "gcloud $optAccount compute disks snapshot $DeviceName --snapshot-names $SnapshotName --zone $DeviceZone $optProject $optSnapshotLocation $additionalLabels"
  } else {
    gcloud $optAccount compute disks snapshot $DeviceName --snapshot-names $SnapshotName --zone $DeviceZone $optProject $optSnapshotLocation $additionalLabels
  }
}

Function Copy-DiskLabels {
  param (
    [Parameter(Mandatory=$true)][string]$DeviceName,
	[Parameter(Mandatory=$true)][string]$SnapshotName,
	[Parameter(Mandatory=$true)][string]$DeviceZone
  )
  $labels=gcloud $optAccount compute disks describe $DeviceName --zone $DeviceZone --format="value[delimiter=','](labels)" $optProject
  if ($dryrun){
    Print-Cmd "gcloud $optAccount compute snapshots add-labels $SnapshotName --labels=$labels $optProject"
  } else {
    gcloud $optAccount compute snapshots add-labels $SnapshotName --labels=$labels $optProject
  }
}

Function Get-SnapshotDeletionDate {
  param (
    [Parameter(Mandatory=$true)][int]$Retention
  )
  (Get-Date (Get-Date).addDays(-$Retention) -UFormat "%Y%m%d")
}

Function Delete-Snapshots {
  param (
    [Parameter(Mandatory=$true)][string]$SnapshotPrefix,
	[Parameter(Mandatory=$true)][string]$DeletionDate,
	[Parameter(Mandatory=$true)][string]$DeviceId
  )
  # filter with creationTimestamp<"YYYYmmdd" doesn't work with Powershell :(
  $snapshotList = gcloud $optAccount compute snapshots list --filter="name~'^$SnapshotPrefix-.*' AND sourceDiskId=$DeviceId" --format="value(name)"
  
  Foreach ($snapshot in $snapshotList) {
	# get created date for snapshot
	$snapshotCreatedDate = Get-SnapshotCreatedDate $snapshot
	if ($deletionDate -ge $snapshotCreatedDate) {
	  Delete-Snapshot $snapshot
	}
  }
}

Function Get-SnapshotCreatedDate {
  param (
  [Parameter(Mandatory=$true)][string]$SnapshotName
  )
  $snapshotDatetime = gcloud $optAccount compute snapshots describe $SnapshotName --format="value(creationTimestamp)"
  $snapshotDatetime.split('T')[0] -replace '-'
}

Function Delete-Snapshot {
  param (
    [Parameter(Mandatory=$true)][string]$SnapshotName
  )
  if ($dryrun){
    Print-Cmd "gcloud $optAccount compute snapshots delete $SnapshotName -q $optProject"
  } else {
    gcloud $optAccount compute snapshots delete $SnapshotName -q $optProject
  }
}

# Debug - print parameters
if ($dryrun){
  Print-Debug "==parameters=="
  Print-Debug "retention=$retention"
  Print-Debug "copylabels=$copylabels"
  Print-Debug "prefix=$prefix"
  Print-Debug "account=$account"
  Print-Debug "project=$project"
  Print-Debug "storage=$storage"
  Print-Debug "labels=$labels"
  Print-Debug "dryrun=$dryrun"
}

# Processing arguments and renaming some variables for consistency with the 
# original script from which this is ported
#
# Number of days to keep snapshots
$olderThan = $retention
# Snapshot Prefix
# check if prefix is more than 20 chars
$prefixMaxLen = 20
if ($prefix.Length -gt $prefixMaxLen){
  $prefix = $prefix.SubString(0,$prefixMaxLen)
}
# gcloud Service Account
$optAccount = ''
if ($account -ne ''){
  $optAccount = "--account=$account"
}
# gcloud Project
$optProject = ''
if ($project -ne ''){
  $optProject = "--project=$project"
}
# Snapshot storage location
$optSnapshotLocation = ''
if ($storage -ne ''){
  $optSnapshotLocation = "--storage-location=$storage"
}
# Additional labels
$additionalLabels = ''
if ($labels -ne ''){
  $additionalLabels = "--labels=$labels"
}

# Debug - print variables
if ($dryrun){
  Print-Debug "==variables=="
  Print-Debug "olderThan=$olderThan"
  Print-Debug "prefix=$prefix"
  Print-Debug "optAccount=$optAccount"
  Print-Debug "optProject=$optProject"
  Print-Debug "dryrun=$dryrun"
  Print-Debug "copylabels=$copylabels"
  Print-Debug "optSnapshotLocation=$optSnapshotLocation"
  Print-Debug "additionalLabels=$additionalLabels"
}

# log time
Log-Time "Start of google-compute-snapshot-win"

# get current datetime
$dateTime = Get-UnixTimeStamp

# get deletion date for existing snapshots
$deletionDate = Get-SnapshotDeletionDate $olderThan

# get local instance name
$instanceName = Get-InstanceName

# dry run: debug output
if ($dryrun){
  Print-Debug "dateTime=$dateTime"
  Print-Debug "deletionDate=$deletionDate"
  Print-Debug "instanceName=$instanceName"
}

# get list of all the disks that match filter
$deviceList = Get-DeviceList $instanceName

# check if any disks were found
if (!$deviceList) {
  Throw "No disks were found - please check your script options / account permissions."
}

# dry run: debug disk output
if ($dryrun) { 
  Print-Debug "==disks=="
  $deviceList 
}

# loop through the devices
Foreach ($device in $deviceList) {
  $deviceName,$deviceZone,$deviceId = $device.split("`t")
  Print-Debug "Handling Snapshots for $deviceName"
  
  $deviceZone = Get-UriLeaf $deviceZone 
  
  # build snapshot name
  $snapshotName = Create-SnapshotName $prefix $deviceName $dateTime
  
  # delete snapshots for this disk that were created older than deletionDate
  Delete-Snapshots $prefix $deletionDate $deviceId
  
  # create the snapshot
  Create-Snapshot $deviceName $snapshotName $deviceZone
  
  if ($copylabels){
    # Copy labels
	Copy-DiskLabels $deviceName $snapshotName $deviceZone
  }
}

Log-Time "End of google-compute-snapshot"
