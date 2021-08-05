# Published 05.08.2021
# www.techguy.at
# https://www.techguy.at/backup-and-restore-last-modified-date-for-scsm-change-requests/

$SCSM_SQL_Server="PSQL700SCSM\SCSM"
$SCSM_SQL_DB="ServiceManager"
$ExportPath="C:\_SCOWorkingDir\DevOps\SeiMi\SMA - Projekt\Set Last Modified\CRExportafterImport.csv"

#Get all Changes from SQL Database
$AllCR = Invoke-Sqlcmd -ServerInstance $SCSM_SQL_Server -Database $SCSM_SQL_DB -Query "
select CR.Id_9A505725_E2F2_447F_271B_9B9F4F0D190C as ID, 
CR.CreatedDate_6258638D_B885_AB3C_E316_D00782B8F688 as CreatedDate,
b.LastModified, Status.LTValue as Status,
DATEDIFF(day, CreatedDate_6258638D_B885_AB3C_E316_D00782B8F688,b.LastModified) AS DateDiff
from MT_System`$WorkItem`$ChangeRequest as CR
inner join BaseManagedEntity as B on CR.BaseManagedEntityId=b.BaseManagedEntityId
left outer join
                (
                        select *
                        from
                                LocalizedText
                        where
                                (
                                        LanguageCode = 'ENU'
                                )
                                AND
                                (
                                        LTStringType = '1'
                                )
                )
                as Status
                on   Status.LTStringId = CR.Status_72C1BC70_443C_C96F_A624_A94F1C857138

"

#Export the Result in a CSV
$AllCR.count
$AllCR | Export-csv -PAth $ExportPath -NoTypeInformation

##############
##############
# Import CSV and write Last Modified via SQL


$Import = Import-csv -Path $ExportPath
Foreach ($CR in $Import) {
        $DateSQL = Get-Date -UFormat (Get-Date -Date $CR.LastModified)

        $ID = $CR.Id
        $Query = "Update e
                set e.LastModified = '$DateSQL'
                from BaseManagedEntity as E
                inner join MTV_System`$WorkItem`$ChangeRequest as I
                on e.BaseManagedEntityId=i.BaseManagedEntityId where i.Id_9A505725_E2F2_447F_271B_9B9F4F0D190C = '$ID'"
    
                Invoke-Sqlcmd -ServerInstance $SCSM_SQL_Server -Database $SCSM_SQL_DB  -Query $Query

        $ID = ""
}
