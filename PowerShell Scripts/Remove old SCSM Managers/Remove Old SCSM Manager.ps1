#region Parameters
[string]$LogPath = "E:\_SCOWorkingDir\DevOps\SeiMi\Team - SMA" #Path to store the Lofgile
[string]$LogfileName = "Clean Old SCSM Manager" #FileName of the Logfile
[int]$DeleteAfterDays = 10 #Time Period in Days when older Files will be deleted

$smdefaultcomputer = "your SCSM Server"
$WrongManagerCount = 0

#endregion Parameters


#region Function
function Write-TechguyLog {
    [CmdletBinding()]
    param
    (
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Type,
        [string]$Text
    )

    # Set logging path
    if (!(Test-Path -Path $logPath)) {
        try {
            $null = New-Item -Path $logPath -ItemType Directory
            Write-Verbose ("Path: ""{0}"" was created." -f $logPath)
        }
        catch {
            Write-Verbose ("Path: ""{0}"" couldn't be created." -f $logPath)
        }
    }
    else {
        Write-Verbose ("Path: ""{0}"" already exists." -f $logPath)
    }
    [string]$logFile = '{0}\{1}_{2}.log' -f $logPath, $(Get-Date -Format 'yyyyMMdd'), $LogfileName
    $logEntry = '{0}: <{1}> {2}' -f $(Get-Date -Format dd.MM.yyyy-HH:mm:ss), $Type, $Text
    Add-Content -Path $logFile -Value $logEntry
}
#endregion Function

Write-TechguyLog -Type INFO -Text "START Script"

Write-TechguyLog -Type INFO -Text "Import Module SMLETS"
Import-Module SMLets

Write-TechguyLog -Type INFO -Text "Get RelationshipClass UserManagesUser"
$UserManagesUser = Get-SCSMRelationshipClass -Name UserManagesUser

Write-TechguyLog -Type INFO -Text "Query all Users from SCSM"
$Users = Get-SCSMObject -Class (Get-SCSMClass -Name System.Domain.User)  #-filter "Username -eq 'ataipt'"

Write-TechguyLog -Type INFO -Text "Found this amount of users: $($Users.count)"


foreach ($User in $Users) {
    Write-TechguyLog -Type INFO -Text "Work with user $($User.DisplayName)"

    Write-TechguyLog -Type INFO -Text "Get list of Managers for the User"
    $Manager = (Get-SCSMRelationshipObject -ByTarget $User | ? { $_.RelationshipId -eq $UserManagesUser.Id })
    if ($Manager.count -gt 1) {
        Write-TechguyLog -Type INFO -Text "Found more than one manager, found : $($Manager.count)"

        Write-TechguyLog -Type INFO -Text "Get actual Manager from AD"
        $ADManager = Get-ADUser -Identity $User.UserName -Properties manager
        Write-TechguyLog -Type INFO -Text "Received this Manager from AD: $($ADManager.Manager)"

        foreach ($Man in $Manager) {
            Write-TechguyLog -Type INFO -Text "Go through each Manager and check is it is the same like in AD, work with: $($Man.SourceObject.DisplayName)"

            if ($Man.SourceObject.DisplayName -ne (Get-ADUser -identity $ADManager.manager).name) {
                $WrongManagerCount++
                Write-TechguyLog -Type INFO -Text "This Manager is not the same like in AD, so we need to remove"
    
                try 
                {
                    Remove-SCSMRelationshipObject -SMObject $MAN
                    Write-TechguyLog -Type INFO -Text "Removed the Manager"
                }
                catch 
                {
                    Write-TechguyLog -Type WARNING -Text "FAILED to remove the Manager"
                }
            }
            else 
            {
                Write-TechguyLog -Type INFO -Text "Manager is same like in AD"
            }
        }
    }
}
Write-TechguyLog -Type INFO -Text "Found and cleaned thsi amount of wrong Managers: $WrongManagerCount"


#Clean Logs
Write-TechguyLog -Type INFO -Text "Clean Log Files"
$limit = (Get-Date).AddDays(-$DeleteAfterDays)
Get-ChildItem -Path $LogPath -Filter "*$LogfileName.log" | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force


Write-TechguyLog -Type INFO -Text "END Script"