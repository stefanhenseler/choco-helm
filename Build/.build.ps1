# Synopsis: Build the project.
Param(
    
)

# Synopsis: initializes the build environment
task init {
	
	Write-Build -Color Green "Bootstraping Build Environment..."
    # Invoke bootstrap in order to get PSDepend from artifactory.
    $BootstrapHelper = Join-Path $PSScriptRoot .\Invoke-Bootstrap.ps1
	.$BootstrapHelper
    
	# Invoke PSDepend to download and load all dependencies
	Write-Build -Color Green "Loading Dependencies..."
	Invoke-PSDepend -Force -Target $Env:BHDependenciesFolderPath -Import -Install 
	
	if ($Env:Path -notlike '*$ENV:BHDependenciesFolderPath*') {
		$ENV:PATH += ";$ENV:BHDependenciesFolderPath"
	}		
	
    # Load Build Environment using BuildHelper Module function
	Set-BuildEnvironment -Force	

	# The test result NUnit target folder.
	Set-Item -Path ENV:BHTestResultTargetPath -Value (Join-Path $ENV:BHWorkingDirPath $ENV:BHTestResultFolderName) -Force | Out-Null    

	# Find the full path to the source folder
	Set-Item -Path ENV:BHSourceRootPath -Value (Get-ChildItem $ENV:BHProjectRoot -Directory $ENV:BHSourceRootName).FullName -Force | Out-Null     

	# Find the module name
	Set-Item -Path Env:BHPackageRootPath -Value (Join-Path $ENV:BHWorkingDirPath $ENV:BHAppName) -Force | Out-Null    
	Set-Item -Path ENV:BHRepositoryPath -Value (Join-Path $ENV:BHWorkingDirPath $ENV:BHRepositoryName) -Force | Out-Null    

	# Variables for logging and testing
	Set-Item -Path ENV:BHTimeStamp -Value (Get-Date -UFormat "%Y%m%d-%H%M%S")
	Set-Item -Path ENV:BHPSVersion -Value $PSVersionTable.PSVersion.Major
	Set-Item -Path ENV:BHTestFile -Value "TestResults_PS$PSVersion`_$TimeStamp.xml"

	Write-Build -Color Green "Listing build environment:"
	Get-Childitem -Path Env:BH* | Sort-Object -Property Name

	# In Appveyor? Show Appveyor environment
    If($ENV:BHBuildSystem -eq 'AppVeyor')
    {
        Get-ChildItem -Path Env:APPVEYOR_* | Sort-Object -Property Name
    } else {
		Set-BuildSecrets -KeyVaultName 'choco-builds' -ErrorAction Stop
	}

}

# Synopsis: Runs test cases against the environment
task test {
	
		# Create Results folder if required.
		if (-not (Test-Path -Path $ENV:BHTestResultTargetPath -PathType Container)) { 
			New-Item -Path $ENV:BHTestResultTargetPath -ItemType Directory -Force
		}
	
		# Gather test results. Store them in a variable and file
		$TestResults = Invoke-Pester -Path $ENV:BHProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile (Join-Path $ENV:BHTestResultTargetPath $ENV:BHTestFile)

		# In Appveyor?  Upload our tests! #Abstract this into a function?
		If($ENV:BHBuildSystem -eq 'AppVeyor')
		{
			 $Results = Get-ChildItem $ENV:BHTestResultTargetPath -Filter '*.xml'
			 
			 foreach ($Result in $Results) { 
				 Write-Build -Color Green "Uploading test result file [$($Result.FullName)] to appveyor"
				(New-Object 'System.Net.WebClient').UploadFile(
					"https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
					$Result.FullName )
			 }
		}
	
		# Failed tests?
		# Need to tell psake or it will proceed to the deployment. Danger!
		if($TestResults.FailedCount -gt 0)
		{
			Throw "Failed '$($TestResults.FailedCount)' tests, build failed"
		} 
	
	}


# Synopsis: Provision task for build automation.
task build {

		# We copy the source in to the working directory
		Write-Build -Color Green "Copy package root folder to match module name: from [$ENV:BHSourceRootPath] to [$ENV:BHPackageRootPath]"
		if (Test-Path -Path $ENV:BHPackageRootPath -PathType Container) {
			Remove-Item -Recurse -Force -Path $ENV:BHPackageRootPath
		}
		Copy-Item -Path $ENV:BHSourceRootPath -Destination $ENV:BHPackageRootPath -Force -Recurse

		# Download package binary
		$AppVersion = $env:BHAppVersion		
		$AppUrl = $ExecutionContext.InvokeCommand.ExpandString($Env:BHAppUrl)
		$AppDownloadTarget = $( Join-Path $ENV:BHDependenciesFolderPath $(Split-Path -Path $AppUrl -Leaf))
		
		Write-Build -Color Green "Downloading Package from [$AppUrl] to [$AppDownloadTarget]"
		(New-Object System.Net.WebClient).DownloadFile($AppUrl,$AppDownloadTarget)

# start This should be moved to a PSDepend script
		# We need 7Zip to extract the archive
		Expand-7Zip -ArchiveFileName $AppDownloadTarget -TargetPath $ENV:BHDependenciesFolderPath
		Expand-7Zip -ArchiveFileName $AppDownloadTarget.Trim('.gz') -TargetPath $ENV:BHDependenciesFolderPath

# end This should be moved to a PSDepend script

		#  copy the helm exe to the nuget package dir 
		Copy-Item -Path (Join-Path $ENV:BHDependenciesFolderPath "windows-amd64\helm.exe") -Destination (Join-Path $ENV:BHPackageRootPath '\tools')
		# Update NuSpec
		Write-Build -Color Green "Update NuSpec file"

		$NuSpecPath = ((Get-ChildItem -Path $ENV:BHPackageRootPath -Filter '*.nuspec').FullName)
		  
		Write-Build -Color Green "Package root path is [$ENV:BHPackageRootPath]"      

		Write-Build -Color Green "Getting content of [$NuSpecPath]"
		$NuSpecContent = Get-Content $NuSpecPath

		$ReplaceValues = @{
			'##AppName##'= $ENV:BHAppName
			'##AppVersion##' = $ENV:BHAppVersion
			'##AppUrl##' = $ENV:BHAppUrl
			'##AppWebsite##' = $ENV:BHAppWebsite
			'##AppAuhtors##' = $ENV:BHAppAuhtors
			'##AppDocsUrl##' = $ENV:BHAppDocsUrl
			'##AppTags##' = $ENV:BHAppTags
			'##AppSummary##' = $ENV:BHAppSummary
			'##AppDescription##' = $ENV:BHAppDescription			
		} 

		# Replace Nuget Spec Config
		foreach ($Value in $ReplaceValues.GetEnumerator()) {
			Write-Build -Color Green "Replacing [$($Value.Key)] with [$($Value.Value)]"
			$NuSpecContent = $NuSpecContent -replace $Value.Key,$Value.Value
		}	
		
		$NuSpecContent | Set-Content $NuSpecPath

		# We have to create a local folder for the local repository
		Write-Build -Color Green "Create folder for local staging repository: [$ENV:BHRepositoryPath]"
		if (Test-Path -Path $ENV:BHRepositoryPath) {
			Remove-Item -Recurse -Force -Path $ENV:BHRepositoryPath
		}		
		New-Item -ItemType Directory -Path $ENV:BHRepositoryPath | Out-Null

		# Create the nuget package
		choco pack $NuSpecPath --outputdirectory $ENV:BHRepositoryPath
   
}

task deploy {

		choco push ((Get-ChildItem -Path $ENV:BHRepositoryPath -Filter '*.nupkg').FullName) --api-key $env:ChocoAPIKey --source https://chocolatey.org/ -f
}

# Synopsis: Remove temporary files.
task clean {

	Write-Build -Color Green "Unregister PSRepository [$($ENV:BHRepositoryName)]"
	Get-PSRepository | Where-Object 'Name' -eq $ENV:BHRepositoryName | Unregister-PSRepository 
    
}

# Synopsis: This is the default task which executes all tasks in order
task . init, build, test, deploy


