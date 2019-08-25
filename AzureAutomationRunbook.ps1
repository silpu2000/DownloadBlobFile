<#
.SYNOPSIS
  This runbook copies a file from Azure BLob Storage to a local file server when a new file is added
.DESCRIPTION
  When a file is added to a blob container, Event Grid fires a webhook event.
  The webhook triggers this Azure Automaiton runbook.  The Runbook runs on a Hybrid Worker with access to the destination file location.
  The Runbook copies data from the source to the destination.
.INPUTS
  JSON data passed by the webhook from Event Grid
.OUTPUTS
  Errors write to the Error output stream
.NOTES
  Version:        1.0
  Author:         Travis Roberts
  Creation Date:  8/21/2019
  Purpose/Change: Initial script development
  ****This script provided as-is with no warranty. Test it before you trust it.****
.EXAMPLE
  See my YouTube channel at http://www.youtube.com/c/TravisRoberts or https://www.Ciraltos.com for details.
#>

# Get json input from webhook
param (
    [Parameter (Mandatory = $false)]
    [object] $WebHookData
)

## declarations ##

# Set the default error action
$errorActionDefault = $ErrorActionPreference

# Local file path.  This is where the file will be copied to.
$localFilePath = 'c:\Blob\'

# Name of the storage account
$storageAccountName = 'StorageAccountName'

# Storage Access Key for the storage account.
# Add this as an encrypted variable in Azure Automation to avoid secure strings in code.
# Update the name with the name of your variable
$StorageAccountKey = Get-AutomationVariable -Name EncryptedVariable

# Set the Storage Account Context
# If not using the Az module, change to New-AzureStorageContext
try {
    $ctx = New-AzStorageContext -ErrorAction stop -storageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error converting file path ' + $ErrorMessage)
    Break
}

# Convert Webhook Body to json
try {
    $requestBody = $WebHookData.requestBody | ConvertFrom-json -ErrorAction 'stop'
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error converting Webhook body to json ' + $ErrorMessage)
    Break
}

# Get the container name
try {
    $ErrorActionPreference = 'stop'
    $subject = $requestBody.subject -split '/'
    $container = $subject[4]
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error getting the container name ' + $ErrorMessage)
    Break
}
Finally {
    $ErrorActionPreference = $errorActionDefault
}

# Convert requestbody to file path
try {
    $ErrorActionPreference = 'stop'
    $fileName = $requestBody.data.url -replace "https://$storageAccountName.blob.core.windows.net/$container/", ""
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error converting file path ' + $ErrorMessage)
    Break
}
Finally {
    $ErrorActionPreference = $errorActionDefault
}

# Check for target directory
# Create if it doesn't exist
try {
    if (!(Test-Path -Path $localFilePath)) {
        new-item -ErrorAction Stop -ItemType 'directory' -Path $localFilePath
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error checking and creating local file path ' + $ErrorMessage)
    Break
}

<#
# Output for testing
write-output 'Request Body'
Write-Output $requestBody
Write-Output 'Container' 
Write-Output $container
Write-Output 'File Name'
Write-Output $fileName
Write-Output 'Local File Path'
write-output $localFilePath
#>

# Copy the file
# This command copies the file local
# If not using the Az module, change command to Get-AzureStorageBlobContent
# If "Illegal characters in path" error, add a Orchestrator.sandbox.exe.config file to ALL hybrid workers as outlined
# here https://github.com/Azure/azure-powershell/issues/8531
# Ref https://stackoverflow.com/questions/54522744/set-azstorageblobcontent-throws-exception-illegal-characters-in-path
try {
    Get-AzStorageBlobContent -ErrorAction stop -Blob $fileName -Container $Container -Destination $localFilePath -Context $ctx 
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error downloading file ' + $ErrorMessage)
    Break
}
