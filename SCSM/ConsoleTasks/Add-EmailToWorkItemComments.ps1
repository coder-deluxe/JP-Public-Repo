Import-Module ShowUi

$global:scsmServer = "scsm1.osuesl.net"

$txtboxSettingsEmailMessage = @{
		"Name" = "EmailMessage";
		"VerticalScrollBarVisibility" = "Visible";
		#"HorizontalScrollBarVisibility" = "Visible";
		"Margin"= 4;
		"MinLines"= 6;
		"MaxHeight"= 200;
		"MaxWidth" = 600;
		"TextWrapping" = "Wrap";
		"AcceptsReturn" = $true;
		"MinHeight" = 80
	}

$txtboxSettingsCommentFinalOutput = @{
		"Name" = "CommentFinalOutput";
		"VerticalScrollBarVisibility" = "Visible";
		#"HorizontalScrollBarVisibility" = "Visible";
		"Margin"= 4;
		"MinLines"= 6;
		"MaxHeight"= 200;
		"MaxWidth" = 600;
		"TextWrapping" = "Wrap";
		"AcceptsReturn" = $true;
		"IsReadOnly" = $true;
		"MinHeight" = 80
	}

#$txtboxSettingsEmailMessage | out-host
$SRID = "Not set."
$inputWindow = New-Grid -ControlName "Email Input Window" -columns 1 -Rows Auto,Auto,Auto,Auto,Auto,Auto,Auto,Auto,Auto {
#StackPanel -ControlName "Email Input Window" -MinWidth 300 {
	New-Label "Paste the email message contents below." -Margin 4 -Row 0 -Column 0
	TextBox @txtboxSettingsEmailMessage -Row 1 -Column 0 -On_TextChanged {
		Function Parse-MessageForSubjectLine($emailMessageText) {
			$curLine = $null
			$emailMessageText | % {
				If($_ -like "Subject: *") {
					$curLine = $_
					#Continue
				}
			}
			
			$retval = $null
			$retval = $curLine
			return $retval
		}
		
		Function Parse-SubjectLineForWiId($subjectLine) {
			$WorkitemId = $null
			$aRegexToTry = $null
			$aRegexToTry = @()
			$aRegexToTry += "^*SR[0-9]+\s"
			$aRegexToTry += "^*SR[0-9]+[\]]"
			$aRegexToTry += "^*IR[0-9]+\s"
			$aRegexToTry += "^*IR[0-9]+[\]]"
			$aRegexToTry | % {
				$matches = $null
				$subjectLine -match $_ | out-null
				If($matches -eq "" -or $matches -eq $null) {}
				Else {
					$WorkitemId = $matches[0]
					$WorkitemId = $WorkitemId.Replace("[","")
					$WorkitemId = $WorkitemId.Replace("]","")
					#$matches
					#Continue
				}
			}
			
			$retval = $null
			$retval = $WorkitemId
			Return $retval
		}
		
		Function Find-WorkitemIdFromMessage($emailMessageText) {
			$subjectLine = $null
			$subjectLine = Parse-MessageForSubjectLine $emailMessageText
			$workitemId = $null
			$workitemId = Parse-SubjectLineForWiId $emailMessageText
			$retval = $null
			$retval = $workitemId.Replace(" ","")
			Return $retval
		}
		$WorkItemId.Text = Find-WorkitemIdFromMessage $emailMessage.Text
		
		##Parse final output
		
		Function Process-EmailInput ($emailMessage) {
			$i = $null
			$i = 0
			$beginLine = $null
			$bStop = $null
			$bStop = $false
			$emailMessage = $emailMessage.Split("`n")
			$emailMessage | % {
				$curLine = $_
				#write-host -f green "checking: $curLine"
				If($curLine -like "*From:*" -and $bStop -eq $false) {
					#write-host -f yellow "hit!!!"
					$beginLine = $i
					$bStop = $true
					#Continue
				}
				$i++
			}
			
			$newMsg = $null
			$i = $null
			$i = 0
			$emailMessage | % {
				If($i -ge $beginLine)
					{$newMsg += $_}
				$i++
			}
			
			$retval = $null
			$retval = $newMsg
			return $retval
			
		}
		
		$CommentFinalOutput.Text = Process-EmailInput $emailMessage.Text
		
	}
	New-Label -Row 2 -Column 0 "Work Item ID (gathered from message contents)."
	TextBox -Row 3 -Name WorkItemId -Margin 4 -Column 0 -IsReadOnly -Text "Not found in email message."
	New-Label -Row 4 -Column 0 "Preview of the final comment:"
	TextBox @txtboxSettingsCommentFinalOutput -Row 5 -Column 0
	Button "Submit" -name "submitbutton" -Margin 4 -MinHeight 80 -Row 6 -Column 0 -On_Click {
		function Add-SRComment {
			param (
				[parameter(Mandatory=$true,Position=0)][Alias('Id')][String]$pSRId,
				[parameter(Mandatory=$true,Position=1)][Alias('Comment')][String]$pComment,
				[parameter(Mandatory=$true,Position=2)][Alias('EnteredBy')][String]$pEnteredBy
			)
			$retval = $false
			###taken from http://social.technet.microsoft.com/forums/systemcenter/en-US/9456ff93-d301-401c-976e-e5b2be75024b/adding-comments-to-srs-through-powershell
			$SRClass = Get-SCSMClass System.WorkItem.ServiceRequest$ -computername $global:scsmServer 
			$SRObject = Get-SCSMObject -Class $SRClass -Filter "Id -eq $pSRId" -computername $global:scsmServer |Select -First 1
			if ($SRObject) {
				$NewGUID = ([guid]::NewGuid()).ToString()
				$Projection = @{__CLASS = "System.WorkItem.ServiceRequest";
					__SEED = $SRObject;
					AnalystCommentLog = @{__CLASS = "System.WorkItem.TroubleTicket.AnalystCommentLog";
					__OBJECT = @{Id = $NewGUID;
						DisplayName = $NewGUID;
						Comment = $pComment;
						EnteredBy  = $pEnteredBy;
						EnteredDate = (Get-Date).ToUniversalTime();
						IsPrivate = $false
						}
					}
				}
				New-SCSMObjectProjection -Type "System.WorkItem.ServiceRequestProjection" -Projection $Projection -computername $global:scsmServer
				$retval = $true
			} else {
				#Write-Host $pSRId "could not be found"
				$retval = $false
			}
			Return $retval
		}
		
		function Add-IRComment {
			param (
				[parameter(Mandatory=$true,Position=0)][Alias('Id')][String]$pSRId,
				[parameter(Mandatory=$true,Position=1)][Alias('Comment')][String]$pComment,
				[parameter(Mandatory=$true,Position=2)][Alias('EnteredBy')][String]$pEnteredBy
			)
			#ref: http://social.technet.microsoft.com/forums/systemcenter/en-US/9456ff93-d301-401c-976e-e5b2be75024b/adding-comments-to-srs-through-powershell
			#ref2: http://blogs.technet.com/b/servicemanager/archive/2013/01/16/creating-membership-and-hosting-objects-relationships-using-new-scsmobjectprojection-in-smlets.aspx
			$retval = $false
			$SRClass = Get-SCSMClass System.WorkItem.Incident$ -computername $global:scsmServer
			$SRObject = Get-SCSMObject -Class $SRClass -Filter "Id -eq $pSRId" -computername $global:scsmServer |Select -First 1
			if ($SRObject) {
				$NewGUID = ([guid]::NewGuid()).ToString()
				$Projection = @{__CLASS = "System.WorkItem.Incident";
					__SEED = $SRObject;
					AnalystComments = @{__CLASS = "System.WorkItem.TroubleTicket.AnalystCommentLog";
						__OBJECT = @{Id = $NewGUID;
							DisplayName = $NewGUID;
							Comment = $pComment;
							EnteredBy  = $pEnteredBy;
							EnteredDate = (Get-Date).ToUniversalTime();
							IsPrivate = $false
						}
					}
				}
				write-host -f yellow "attempting IR comment write"
				New-SCSMObjectProjection -Type "System.WorkItem.IncidentPortalProjection" -Projection $Projection -computername $global:scsmServer
				$retval = $true
			} else {
				Write-Host $pSRId "could not be found"
				$retval = $false
			}
			Return $retval
		}
		
		$bContinue = $null
		$bContinue = $true
		$submitbutton.IsEnabled = $false
		$wiID = $null
		$wiID = $WorkItemId.Text
		$wiClassStr = $null
		If($wiID -match "^SR[0-9]+$") {$wiClassStr = "System.WorkItem.ServiceRequest$"}
		ElseIf($wiID -match "^IR[0-9]+$") {$wiClassStr = "System.WorkItem.Incident$"}
		Else
			{
				$RunbookProgress.Value = 50
				$ProgressLabel.Content = "Submission Failed; could not open work item."
				$cancelbutton.content = "Close"
				$bContinue = $false
			}
			
		If($bContinue -eq $true) {
			$wiClass = $null
			$wiClass = Get-SCSMClass $wiClassStr -computername $global:scsmServer
			$sFilter = $null
			$sFilter = "ID -eq " + $wiID
			#write-host -f yellow "sFilter: $sFilter"
			$oWI = $null
			$oWI = Get-SCSMObject -class $wiClass -filter $sFilter -computername $global:scsmServer
			If($oWI -eq $null -or $oWI -eq "") {
				$RunbookProgress.Value = 50
				$ProgressLabel.Content = "Submission Failed; could not open work item."
				$cancelbutton.content = "Close"
				$bContinue = $false
			}
			Else
				{
					#$newCommentGUID = $null
					#$newCommentGUID = [guid]::NewGuid()
					$newCommentText = $null
					$newCommentText = $CommentFinalOutput.Text
					$enteredBy = $null
					$enteredBy = $env:username
					$action = $null
					If($wiID -like "SR*") {
						$action = Add-SRComment -Id $wiID -Comment $newCommentText -EnteredBy $enteredBy
					}
					ElseIf($wiID -like "IR*") {
						$action = Add-IRComment -Id $wiID -Comment $newCommentText -EnteredBy $enteredBy
					}
					Else {$action = $false}
					
					If($action -eq $true) {
						$RunbookProgress.Value = 100
						$ProgressLabel.Content = "Submission Attempted..."
					}
					Else {
						$RunbookProgress.Value = 50
						$ProgressLabel.Content = "Submission Attempted but failed."
					}
				}
		}
		
		$cancelbutton.content = "Close"
	}
	
	Button "Cancel" -Row 7 -Column 0 -Margin 4 -name "cancelbutton" -On_Click {$Parent | Close-Control}
	ProgressBar -Row 8 -Column 0 -Name RunbookProgress -Maximum 100 -Height 40 -Margin 4
	New-Label -Name "ProgressLabel" -HorizontalContentAlignment "center" -VerticalContentAlignment "center" -Row 8 -Column 0 -Background "Transparent" -Margin 4
} -Show