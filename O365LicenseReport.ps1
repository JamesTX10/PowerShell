Function UserHasLicenseAssignedDirectly{
#Returns TRUE if the user has the license assigned directly
   Param([Microsoft.Online.Administration.User]$user, [string]$skuId)
   foreach($license in $user.Licenses){
       #we look for the specific license SKU in all licenses assigned to the user
       if ($license.AccountSkuId -ieq $skuId){
           #GroupsAssigningLicense contains a collection of IDs of objects assigning the license
           #This could be a group object or a user object (contrary to what the name suggests)
           #If the collection is empty, this means the license is assigned directly. This is the case for users who have never been licensed via groups in the past
           if ($license.GroupsAssigningLicense.Count -eq 0){return $true}
           #If the collection contains the ID of the user object, this means the license is assigned directly
           #Note: the license may also be assigned through one or more groups in addition to being assigned directly
           foreach ($assignmentSource in $license.GroupsAssigningLicense){
               if ($assignmentSource -ieq $user.ObjectId){return $true}
           }
           return $false
       }
   }
   return $false
}
Function UserHasLicenseAssignedFromGroup{
#Returns TRUE if the user is inheriting the license from a group
Param([Microsoft.Online.Administration.User]$user, [string]$skuId)
  foreach($license in $user.Licenses){
     #we look for the specific license SKU in all licenses assigned to the user
     if ($license.AccountSkuId -ieq $skuId){
       #GroupsAssigningLicense contains a collection of IDs of objects assigning the license
       #This could be a group object or a user object (contrary to what the name suggests)
         foreach ($assignmentSource in $license.GroupsAssigningLicense){
               #If the collection contains at least one ID not matching the user ID this means that the license is inherited from a group.
               #Note: the license may also be assigned directly in addition to being inherited
               if ($assignmentSource -ine $user.ObjectId){return $true}
       }
           return $false
     }
   }
   return $false
}
### Load VARables Start ###
$Script:AllMembers++
$Script:AllMembers = @()

$SKUIDs = Get-MsolAccountSku

#$Users = Get-MsolUser -MaxResults 100 | where {$_.isLicensed -eq $true} |Sort DisplayName
$Users = Get-MsolUser -All | where {$_.isLicensed -eq $true} |Sort DisplayName
ForEach ($User in $Users){
    $DisplayName = $User.DisplayName
    $UserPrincipalName = $User.UserPrincipalName
    Write-Host "Name:" $DisplayName -ForegroundColor DarkGreen
    #Write-host "UPN: " $UserPrincipalName

    ForEach ($SKUID in $SKUIDs){
    $Status = ""
    $SKUID = $SKUID.AccountSkuId
    $AssignedDirectly = UserHasLicenseAssignedDirectly $user $SKUID
    $AssignedFromGroup = UserHasLicenseAssignedFromGroup $user $SKUID
    #Write-host "SKU:" $SKUID
    #Write-Host "Assigned Directly: "$AssignedDirectly
    #Write-Host "Assigned from group: " $AssignedFromGroup
    If ($AssignedDirectly -eq $True -and $AssignedFromGroup -eq $True){$Status = "Remove Direct Assignment"}
    If ($AssignedDirectly -eq $True -and $AssignedFromGroup -eq $False){$Status = "Check Group Assignment"}
    If ($AssignedDirectly -eq $False -and $AssignedFromGroup -eq $True){$Status = "Group Assignment Only"}
    If ($AssignedDirectly -eq $False -and $AssignedFromGroup -eq $False){$Status = "Not Licensed for this SKU"}
   
###Populate data
        $obj = new-object psObject
        $obj | Add-Member -membertype noteproperty -Name DisplayName -Value $DisplayName
        $obj | Add-Member -membertype noteproperty -Name UserPrincipleName -Value $UserPrincipalName
        $obj | Add-Member -MemberType noteproperty -Name SKUID -Value $SKUID
        $obj | Add-Member -MemberType noteproperty -Name AssignedDirectly -Value $AssignedDirectly
        $obj | Add-Member -MemberType noteproperty -Name AssignedFromGroup -Value $AssignedFromGroup
        $obj | Add-Member -MemberType noteproperty -Name EA10 -Value $EA10
        $obj | Add-Member -MemberType noteproperty -Name Status -Value $Status

        $Script:AllMembers += $obj
}}

$Script:AllMembers |Export-csv  "D:\Powershell\O365\O365LicenseReport.csv" -notype
$Script:AllMembers = @() 
