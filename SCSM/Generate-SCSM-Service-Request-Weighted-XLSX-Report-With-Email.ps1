$srClass = Get-SCSMClass -name System.WorkItem.ServiceRequest$
$AffectedUserRelClass = Get-SCSMRelationshipClass System.WorkItemAffectedUser$
$srEnCompleteId = (Get-SCSMEnumeration ServiceRequestStatusEnum.Completed).Id

#dictionary of urgency / priority to weight

$hPriorityUrgencyWeight = @{}
$hPriorityUrgencyWeight.Add("VIP-Immediate",240)
$hPriorityUrgencyWeight.Add("VIP-Urgent",220)
$hPriorityUrgencyWeight.Add("Faculty-Immediate",200)
$hPriorityUrgencyWeight.Add("Faculty-Urgent",180)
$hPriorityUrgencyWeight.Add("Staff-Immediate",160)
$hPriorityUrgencyWeight.Add("Staff-Urgent",140)
$hPriorityUrgencyWeight.Add("Grad-Immediate",120)
$hPriorityUrgencyWeight.Add("Grad-Urgent",100)
$hPriorityUrgencyWeight.Add("VIP-Routine",80)
$hPriorityUrgencyWeight.Add("Faculty-Routine",70)
$hPriorityUrgencyWeight.Add("Staff-Routine",60)
$hPriorityUrgencyWeight.Add("Grad-Routine",50)
$hPriorityUrgencyWeight.Add("VIP-Low",40)
$hPriorityUrgencyWeight.Add("Faculty-Low",30)
$hPriorityUrgencyWeight.Add("Staff-Low",20)
$hPriorityUrgencyWeight.Add("Grad-Low",10)


$hAreaToSLOHours = @{}
$hAreaToSLOHours.Add("Documentation",3)
$hAreaToSLOHours.Add("Access Control",1)
$hAreaToSLOHours.Add("Server Configuration Change",6)
$hAreaToSLOHours.Add("Workstation Configuration Change",1)
$hAreaToSLOHours.Add("Data Recovery",3)
$hAreaToSLOHours.Add("Add Package to SCCM",3)
$hAreaToSLOHours.Add("New Server Install",3)
$hAreaToSLOHours.Add("Purchase and Install Software (eStores)",2)
$hAreaToSLOHours.Add("Software Install (manual)",2)
$hAreaToSLOHours.Add("Printer Consumables",1)
$hAreaToSLOHours.Add("Computer Reinstall",5)
$hAreaToSLOHours.Add("Repurposed Equipment",1)
$hAreaToSLOHours.Add("New Account Request",1)
$hAreaToSLOHours.Add("IT Service Question or Suggestion",2)
$hAreaToSLOHours.Add("Exit Processing or Deprovision User",2)
$hAreaToSLOHours.Add("Software Install (SCCM, Casper, or RHSS)",1)



$activeSrList = Get-SCSMObject �Class $srClass -Filter "Status -ne $srEnCompleteId" | ?{$_.Status.Name -eq "ServiceRequestStatusEnum.InProgress" -or $_.Status.Name -eq "ServiceRequestStatusEnum.Submitted" -or $_.Status.Name -eq "ServiceRequestStatusEnum.New"}


$hSRWeight = @{}
$activeSRList  | % {
$lookup = ($_.Priority.DisplayName + "-" + $_.Urgency.DisplayName)
$initialWeight= $hPriorityUrgencyWeight.Get_Item($lookup)
$daysOldTS = New-TimeSpan -Start $_.CreatedDate -End (Get-Date)
$daysOld = $daysOldTS.Days
$daysOldWeightAdjustment = $daysOld * ($initialWeight * 0.1)
$adjustedWeight = $initialWeight + $daysOldWeightAdjustment
$hSRWeight.Add($_.ID,$adjustedWeight)
}

#new container for sorted objects
$arrSortedSRExtendedClass = $null
$arrSortedSRExtendedClass = @()

#for calculating SLO estimate
$SRWorkHoursPerDay = 10
$runningHours = 0

#sort and add to new class
$hSrWeight.GetEnumerator() | Sort Value -Descending | % {
	#get current sr
	$curHashObj = $null
	$curHashObj = $_
	$curSR = $null
	$curSR = $activeSRList | ?{$_.ID -eq $curHashObj.Name}
	
	#user
	$AffectedUser = $null
	$AffectedUser = Get-SCSMRelatedObject -SMObject $curSR -Relationship $AffectedUserRelClass
	$username = $null
	$username = $AffectedUser.Username
	$userDisplayName = $null
	$userDisplayName = $affectedUser.DisplayName
	
	#daysOld
	$daysOldTS = $null
	$daysOldTS = New-TimeSpan -Start $curSR.CreatedDate -End (Get-Date)
	$daysOld = $null
	$daysOld = $daysOldTS.Days
	
	#daysUntilComplete
	$SLOkeys = $hAreaToSloHours.Keys
	If($SLOKeys -contains ($curSR.Area.DisplayName)) {
	$runningHours += ($hAreaToSloHours.Get_Item(($curSR.Area.DisplayName)))}
	Else {$runningHours += 5}
	
	$workDaysUntilComplete = $null
	$workDaysUntilComplete = $runningHours / $SRWorkHoursPerDay
	$targetDeliveryDate = $null
	$targetDeliveryDate = (Get-Date).AddDays($workDaysUntilComplete)
	$targetDDString = $null
	$targetDDString = Get-Date $targetDeliveryDate -format "MM/dd/yyyy"
	
	$extendedSR = $null
	$extendedSR = new-object -typename PSObject
	$extendedSR | Add-Member -MemberType NoteProperty -Name ID -Value $curSR.ID
	$extendedSR | Add-Member -MemberType NoteProperty -Name RequesterDN -Value $userDisplayName
	$extendedSR | Add-Member -MemberType NoteProperty -Name RequesterUserName -Value $username
	$extendedSR | Add-Member -MemberType NoteProperty -Name DaysOld -Value $DaysOld
	$extendedSR | Add-Member -MemberType NoteProperty -Name Title -Value $curSR.Title
	$extendedSR | Add-Member -MemberType NoteProperty -Name DaysUntilComplete -Value $workDaysUntilComplete
	$extendedSR | Add-Member -MemberType NoteProperty -Name ExpectedDeliveryDate -Value $targetDDString
	$extendedSR | Add-Member -MemberType NoteProperty -Name Area -Value $curSR.Area.DisplayName
	$extendedSR | Add-Member -MemberType NoteProperty -Name Urgency -Value $curSR.Urgency.Displayname
	$extendedSR | Add-Member -MemberType NoteProperty -Name Priority -Value $curSR.Priority.DisplayName
	#$extendedSR | Add-Member -MemberType NoteProperty -Name Status -Value $curSR.Status.DisplayName
	$extendedSR | Add-Member -MemberType NoteProperty -Name Weight -Value $_.Value
	
	$arrSortedSRExtendedClass += $extendedSR
}

#$arrSortedSRExtendedClass | Export-CSV out.csv


Function Email-SRUser($SR,$SRNum,$emailPass) {
	
	Sleep -s 1
	
	$username = $SR.RequesterUserName
	If($username -ne $null -and $username -ne "") {
		$ado = $null
		$ado = get-aduser $username -Properties "emailaddress" -erroraction "silentlycontinue"
		$targetEmailAddr = $null
		If($ado -ne $null -and $ado -ne "")
			{$targetEmailAddr = $ado.EmailAddress}
	}
	
	If($targetEmailAddr -ne $null -and $targetEmailAddr -ne "") {
		$msg = $null
		$msg = "Email to: " + $targetEmailAddr
		Write-Host -f green $msg
		
		$msg = $null
		$msg = ""
		$msg += "This an automated status update notification. No action is necessary."
		$msg += "`n`n"
		$msg += "The ESL IT Support team has an outstanding work item that is related to you. "
		$msg += "You are receiving this notification because the work item is marked as �incomplete�,"
		$msg += " meaning that the ESL Support team still has work to be done on the item."
		$msg += "`n`n"
		$msg += " * " + $SR.ID + " - " + $SR.Title + "."
		$msg += "`n`n"
		$msg += "The priority of the work item is currently marked as " + $SR.Priority + "-" + $SR.Urgency + "."
	  $msg += "`n"
	  $msg += "The work item is currently " + $SR.DaysOld + " days old."
	  $msg += "`n"
	  $msg += "The estimated delivery date for this work item is " + $SR.expectedDeliveryDate + "."
	  $msg += "`n"
	  $msg += "The request is currently number " + $SRNum + " in the queue."
	  $msg += "`n`n"
	  $msg += "We have experienced an unusually high number of requests and are working hard "
	  $msg += "to complete them as fast as possible. If you feel that your request is misclassified or should be "
	  $msg += "expedited further, please reply to this message and every effort will be made."
		$msg += "`n`n"
		$msg += "Thank you,"
		$msg += "`n"
		$msg += "John Puskar"
	
		#$msg
		
		
		
		$msgSubject = "ESL IT Support - Request Status - " + $SR.ID + " - " + $SR.Title
		$msgBody = $msg
		
		$msg = new-object Net.Mail.MailMessage
		$msg.Bcc.Add("puskar.4@osu.edu")
		$msg.From = "puskar.4@osu.edu"
		$msg.To.Add($targetEmailAddr)
		#$msg.To.Add("puskar.4@osu.edu")
		$msg.Subject = $msgSubject
		$msg.Body = $msgBody
		$msg.Sender = "puskar.4@osu.edu"
		
		#REF http://nicholasarmstrong.com/2009/12/sending-email-with-powershell-implicit-and-explicit-ssl/
		
		$mailServer = "smtp.service.osu.edu"
		$serverPort = 587
		$timeout = 7000          # timeout in milliseconds
		#$enableSSL = $true
		#$implicitSSL = $true
		#$credentials = [Net.NetworkCredential](Get-Credential)		
		
		$smtpClient = New-Object System.Net.Mail.SmtpClient
		$smtpClient.Host = $mailServer
		#$smtpClient.Port = $serverPort
		$smtpClient.EnableSsl = $true
		$smtpClient.Timeout = $timeout
		
		$Credentials = new-object System.Net.networkCredential
		$Credentials.UserName = "puskar.4"
		
		$BasicString = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($emailPass)
		$pw = $null
		$pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BasicString)
		$Credentials.Password = $pw
		#$credentials.Domain = "osu.edu"
		$pw = $null
		
		$smtpClient.UseDefaultCredentials = $false
		$smtpClient.Credentials = $credentials
		#$smtpClient.Credentials = [system.Net.CredentialCache]::DefaultNetworkCredentials
		
		$spm = [System.Net.ServicePointManager]
		$spm::ServerCertificateValidationCallback = { return $true }
		
		$smtpClient.Send($msg)
		
		
		
		
	}
} 

$i = 0
$pass = read-host "Please Enter Your Password" -asSecureString
$arrSortedSRExtendedClass | % {
	Email-SRUser $_ $i $pass
	$i++
}