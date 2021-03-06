﻿$ConfigData = @{
    AllNodes = @(
        @{
            NodeName= "*"
            CertificateFile = "C:\Certificates\dsc-public.cer" 
            Thumbprint = "D6F57B6BE46A7162138687FB74DBAA1D4EB1A59B" 
            SqlInstanceName = "MSSQLSERVER" # Default instance
            PSDscAllowDomainUser = $true
        },

        @{ 
            NodeName = 'SQLNODE01.company.local'
            Role = "PrimaryReplica"
        },

        @{
            NodeName = 'SQLNODE02.company.local' 
            Role = "SecondaryReplica" 
        }
    )
}
 
Configuration SQLAlwaysOnNodeConfig 
{
    param
    (
        [Parameter(Mandatory=$false)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlAdministratorCredential
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xSqlServerAlwaysOn -ModuleVersion 1.0.0.0

    Node $AllNodes.Where{ $_.Role -eq "PrimaryReplica" }.NodeName
    {
        xSQLServerAlwaysOnAvailabilityGroup AvailabilityGroupForSynchronousCommitAndAutomaticFailover
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AG-01"
            AvailabilityMode = 'SynchronousCommit'
            FailoverMode = 'Automatic'

            PsDscRunAsCredential = $SqlAdministratorCredential
        }

        xSQLServerAlwaysOnAvailabilityGroup AvailabilityGroupForAsynchronousCommitAndManualFailover
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AvailabilityGroup-02"
            AvailabilityMode = 'AsynchronousCommit'
            FailoverMode = 'Manual'

            PsDscRunAsCredential = $SqlAdministratorCredential
        }

        # Remove availability groups which was added above

        xSQLServerAlwaysOnAvailabilityGroup RemoveAvailabilityGroup
        {
            Ensure = "Absent"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AG-01"

            PsDscRunAsCredential = $SqlAdministratorCredential
            
            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroup]AvailabilityGroupForSynchronousCommitAndAutomaticFailover"
        }

        xSQLServerAlwaysOnAvailabilityGroup RemoveAvailabilityGroup
        {
            Ensure = "Absent"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AvailabilityGroup-02"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroup]AvailabilityGroupForAsynchronousCommitAndManualFailover"
        }
    }

    Node $AllNodes.Where{ $_.Role -eq "SecondaryReplica" }.NodeName
    {         
    }
}

$SqlAdministratorCredential = Get-Credential -Message "Enter credentials for SQL Server administrator account"

SQLAlwaysOnNodeConfig `
    -SqlAdministratorCredential $SqlAdministratorCredential `
    -ConfigurationData $ConfigData `
    -OutputPath 'C:\Configuration'
