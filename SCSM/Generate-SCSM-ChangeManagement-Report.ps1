Function Get-CRItems() {
	$WIClass = Get-SCSMClass -name System.WorkItem.ChangeRequest$
	$wiEnCompleteId = (Get-SCSMEnumeration ChangeRequestEnum.Completed).Id
	$activeWiList = Get-SCSMObject �Class $WIClass
	
	Return $activeWiList
}

$aCRList = Get-CRItems

$customCRList = $null
$customCRList = @()
$aCRList | % {
	$newCRObj = $null
	$newCRObj = New-Object -Typename PSObject
	$newCRObj | Add-Member -MemberType NoteProperty -Name "Title" -Value $_.Title
	$newCRObj | Add-Member -MemberType NoteProperty -Name "ID" -Value $_.ID
	$newCRObj | Add-Member -MemberType NoteProperty -Name "ImplementationPlan" -Value $_.ImplementationPlan
	$newCRObj | Add-Member -MemberType NoteProperty -Name "Description" -Value $_.Description
	$newCRObj | Add-Member -MemberType NoteProperty -Name "Reason" -Value $_.Reason
	$newCRObj | Add-Member -MemberType NoteProperty -Name "TestPlan" -Value $_.TestPlan
	$newCRObj | Add-Member -MemberType NoteProperty -Name "BackoutPlan" -Value $_.BackoutPlan
	$newCRObj | Add-Member -MemberType NoteProperty -Name "RiskAssessmentPlan" -Value $_.RiskAssessmentPlan
	$newCRObj | Add-Member -MemberType NoteProperty -Name "ImplementationResults" -Value $_.ImplementationResults.DisplayName
	$newCRObj | Add-Member -MemberType NoteProperty -Name "Area" -Value $_.Area.DisplayName
	$newCRObj | Add-Member -MemberType NoteProperty -Name "Status" -Value $_.Status.DisplayName
	$customCRList += $newCRObj
}

$customCRList | Export-CSV Change-Management-Report.csv