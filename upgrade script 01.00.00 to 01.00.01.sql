SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;

DECLARE @version nvarchar(100) = N'01.00.01',
        @ext_version nvarchar(100);

IF NOT EXISTS(SELECT 1 FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = N'audit version')
    BEGIN
        RAISERROR(N'This is an upgrade script.  Run framework install script first',16,1);
    END
ELSE
    BEGIN
        SELECT @ext_version = CONVERT(nvarchar(100),value) FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = N'audit version';
        IF @ext_version <> N'01.00.00'
            BEGIN
                RAISERROR(N'This is the wrong upgrade script.',16,1);
            END
        ELSE
            BEGIN
                EXEC sys.sp_updateextendedproperty @name = N'audit version', @value = @version;
            END
    END
   
PRINT 'Upgrading from version 01.00.00 to 01.00.01'
GO

IF OBJECT_ID('dbo.Look','V') IS NOT NULL
    BEGIN
        DROP VIEW dbo.Look;
    END
GO
PRINT 'creating dbo.v_Look view';
GO

/*************************************************************************************************
	<historylog> 
		<log revision="1.0" date="05/01/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="09/14/2010" modifier="David Sumlin">Changed LookTypeName to LookTypeValue for consistency</log> 
		<log revision="1.2" date="09/14/2010" modifier="David Sumlin">Added WITH (NOLOCK) to tables</log> 
		<log revision="1.3" date="03/07/2011" modifier="David Sumlin">Changed column names to use new naming convention and added updated by fields</log> 
		<log revision="1.4" date="09/13/2013" modifier="David Sumlin">Changed audit fields to only ModifiedBy and ModifiedDate</log> 
        <log revision="1.5" date="08/08/2014" modifier="David Sumlin">Removed audit date fields</log> 
        <log revision="1.6" date="06/12/2015" modifier="David Sumlin">Renamed to remove v_</log> 
        <log revision="1.7" date="06/12/2015" modifier="David Sumlin">Renamed to add v_</log> 
	</historylog>         
	
**************************************************************************************************/
CREATE VIEW [dbo].[v_Look]
WITH SCHEMABINDING
AS
SELECT
	[l].[LookGID],
	[l].[LookValue],
	[l].[LookDescription],
	[l].[LookConstant],
	[l].[LookActive],
	[l].[LookOrder],
	[l].[Timestamp] [LookTimestamp],
	[l].[ModifiedBy] [LookModifiedBy],
	[lt].[LookTypeGID],
	[lt].[LookTypeValue],
	[lt].[LookTypeDescription],
	[lt].[LookTypeConstant],
	[lt].[LookTypeActive],
	[lt].[Timestamp] [LookTypeTimestamp],
	[lt].[ModifiedBy] [LookTypeModifiedBy]
FROM [base].[Look] l WITH (NOLOCK)
	RIGHT OUTER JOIN [base].[LookType] lt WITH (NOLOCK)
		ON [l].[LookTypeFID] = [lt].[LookTypeGID];
GO
