 ##--------------------------------------------------------------------------
    ##  FUNCTION.......:  Get-PwdAge
    ##  PURPOSE........:  Queries Active Directory for Password Age.
    ##  REQUIREMENTS...:  PowerShell v2.0
    ##  NOTES..........:  Needs to be run from administrative PowerShell session. Use "Import-Module ActiveDirectory", then load the function using ". .\Get-PwdAge.ps1"
    ##--------------------------------------------------------------------------
    function Get-PwdAge {
        #Requires -Version 2.0 
        
        <#
        .SYNOPSIS
         Queries Active Directory for Password Age
         For examples type:
             Get-Help Get-PwdAge -examples
        .DESCRIPTION
         This Function will query AD for password age. It can display 
         information for a specified user, and can also display information for 
         all accounts (the default for this is the first 1000 user accounts).
        .PARAMETER <Usr>
         Optional parameter that will display information for a specific user 
         account.
        .PARAMETER <All>
         Optional parameter that will display information for all AD user 
         accounts (by default it displays only the first 1000 entries).
        .EXAMPLE
         Get-PwdAge user1
         Will return password age information for the user "user1"
         ##-------------------------------------------------------------
         Sample output:
         ##-------------------------------------------------------------
         Get-PwdAge user1
             Name                 Login           AgeInDays LastSet                 
             ----                 -----           --------- -------                 
             Display Name         user1                   6 2/7/2007 12:36:53 PM
        .EXAMPLE
         Get-PwdAge dis*
         Will return password age information for any user with "dis" as the 
         first part of their display name. If more than one match is found, all 
         will be displayed.
         ##-------------------------------------------------------------
         Sample output:
         ##-------------------------------------------------------------
         Get-PwdAge dis*
             Name                 Login           AgeInDays LastSet                 
             ----                 -----           --------- -------                 
             Display Name         user1                   6 3/8/2011 12:36:53 PM
             Dissident User       user2                   2 3/12/2011 12:20:00 PM
        .EXAMPLE
         Get-PwdAge -All
         Will return password age information for all users in the Domain (the 
         default setting is to display the first 1000 User objects).
         ##-------------------------------------------------------------
         Sample output:
         ##-------------------------------------------------------------
         Get-PwdAge dis*
             Name                 Login           AgeInDays LastSet                 
             ----                 -----           --------- -------                 
             Display Name         user1                   6 3/8/2011 12:36:53 PM
             Dissident User       user2                   2 3/12/2011 12:20:00 PM
             Jane Doe             jane.doe              734 3/9/2009 3:05:30 PM     
             John Doe             john.doe              657 5/26/2009 2:37:08 PM    
             svcact               svcact                450 12/18/2009 7:38:31 PM   
             Joe Sixpack          joe.sixpack           159 10/5/2010 5:38:33 PM    
             Jim User             juser                 131 11/3/2010 11:20:44 AM 
             MORE...
        .NOTES
         NAME......:  Get-PwdAge
         AUTHOR....:  Joe Glessner
         LAST EDIT.:  14MAR11
         CREATED...:  18AUG10
        .LINK
         http://joeit.wordpress.com/
        #> 
        [CmdletBinding()]             
        Param              
           (                        
               [Parameter(Mandatory=$false, 
                    Position=1,                           
                    ValueFromPipeline=$false,             
                    ValueFromPipelineByPropertyName=$false)]             
                [String]$Usr, 
                [Switch]$All
            )#End Param
        $filter = "(&(objectCategory=person)(objectClass=user)(name=$Usr))"
        If ($All) {
            $filter = '(&(objectCategory=person)(objectClass=user))'
            }
        $root = New-Object System.DirectoryServices.DirectoryEntry("LDAP://RootDSE")
        $searcher = New-Object System.DirectoryServices.DirectorySearcher $filter
        $SearchRoot = $root.defaultNamingContext
        #$searcher.SearchRoot = "LDAP://OU=Domain Users,$SearchRoot"
        $searcher.SearchRoot = "LDAP://$SearchRoot"
        $searcher.SearchScope = 'SubTree'
        $searcher.SizeLimit = 0
        $searcher.PageSize = 1000
        $searcher.FindAll() | Foreach-Object {
            $account = $_.GetDirectoryEntry()
            $pwdset = [datetime]::fromfiletime($_.properties.item("pwdLastSet")[0])
            $age = (New-TimeSpan $pwdset).Days
            $lastlogon = [datetime]::fromfiletime($_.properties.item("lastlogontimestamp")[0]) #added 11-28-18
            $mbxGuid = $_.properties.item("msexchmailboxguid") #added 11-28-18 if populated has an Exchange mailbox
			<#
			modified SM 8/25/2014 to add logic to check for "password never expires" attribute. 66048 is all I care about right now, Other possible values, per http://www.netvision.com/ad_useraccountcontrol.php :
			Value	Description
			512	Enabled Account
			514	Disabled Account
			544	Enabled, Password Not Required
			546	Disabled, Password Not Required
			66048	Enabled, Password Doesn't Expire
			66050	Disabled, Password Doesn't Expire
			66080	Enabled, Password Doesn't Expire & Not Required
			66082	Disabled, Password Doesn't Expire & Not Required
			262656	Enabled, Smartcard Required
			262658	Disabled, Smartcard Required
			262688	Enabled, Smartcard Required, Password Not Required
			262690	Disabled, Smartcard Required, Password Not Required
			328192	Enabled, Smartcard Required, Password Doesn't Expire
			328194	Disabled, Smartcard Required, Password Doesn't Expire
			328224	Enabled, Smartcard Required, Password Doesn't Expire & Not Required
			328226	Disabled, Smartcard Required, Password Doesn't Expire & Not Required
			#>
            $neverexpires = $account.useraccountcontrol.item(0)
            if ($neverexpires -eq "66048") {
            	$neverexpires = $true
            } else {
            	$neverexpires = $false
            } #end added section 8/25/2014

            $acctenabled = (Get-AdUser $account.SamAccountName[0]).Enabled

            $info = 1 | Select-Object Name, Login, distinguishedName, AgeInDays, LastSet, PasswordNeverExpires,Enabled, LastLogon, mailbox
            $info.Name = $account.DisplayName[0]
            $info.Login = $account.SamAccountName[0]
            $info.distinguishedName = $account.distinguishedName
            $info.AgeInDays = $age
            $info.LastSet = $pwdset
            $info.PasswordNeverExpires = $neverexpires
            $info.Enabled = $acctenabled
            $info.LastLogon = $lastlogon
            if ($mbxGuid -ne $null) {
                $info.mailbox = $true
            } else {
                $info.mailbox = $false
            }
            $info
        }
    }